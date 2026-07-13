-- Permission bridge (nvim side). A headless agent's tool call is routed here
-- (via a PreToolUse hook or --permission-prompt-tool MCP tool → nvim RPC); we
-- classify it, prompt the user for anything mutating, and return allow/deny.
-- Decision logic is pure + tested; the RPC entry + prompt UI are the thin shell.
local M = {}

-- Auto-allowed tools (no prompt): read-only tools + file edits. File edits are
-- safe because the agent works in its own isolated worktree — the review gate is
-- at MERGE time, not per-edit. Bash stays gated (it can escape the worktree).
M.auto_allow = {
  -- claude (PascalCase)
  Read = true, Grep = true, Glob = true, LS = true, TodoWrite = true, NotebookRead = true,
  Edit = true, Write = true, MultiEdit = true, NotebookEdit = true,
  -- opencode (lowercase) — bash stays gated (can escape the worktree)
  read = true, grep = true, glob = true, list = true, edit = true, write = true, patch = true, webfetch = true,
}

local function is_bash(tool)
  return tool == "Bash" or tool == "bash"
end

function M.classify(tool)
  if M.auto_allow[tool] then return "allow" end
  return "ask"
end

-- Split a shell command line into its component commands on && || | ; and
-- newlines, so each is checked against the allowlist independently (like claude).
-- Approximate — doesn't parse quotes/subshells — but errs toward MORE segments,
-- which only ever asks for approval, never grants extra. Pure.
function M.split_commands(command)
  local flat = tostring(command or "")
    :gsub("&&", "\0"):gsub("||", "\0"):gsub("|", "\0"):gsub(";", "\0"):gsub("\n", "\0")
    -- Also break at command/process-substitution openers so a nested command must
    -- ALSO be allowlisted (`cat $(rm -rf ~)` → "cat" + "rm -rf ~)"). Only ever adds
    -- segments → never grants extra.
    :gsub("%$%(", "\0"):gsub("`", "\0"):gsub("<%(", "\0"):gsub(">%(", "\0")
    -- Collapse harmless redirect idioms BEFORE the >/& split so they don't force a
    -- prompt: fd-dups (`2>&1`, `>&2`, `2>&-`) and writes to /dev/null.
    :gsub("%d*>>?&[%d%-]", " "):gsub("&?%d*>>?%s*/dev/null", " ")
    -- ...and on a lone `&` (background = command separator: `echo x & payload`) and
    -- file redirects `>`/`>>` (write target must itself be allowlisted, so it never
    -- is → `echo x > ~/.zshrc` prompts). `&&` and `>(` were already consumed above.
    :gsub(">>", "\0"):gsub("&", "\0"):gsub(">", "\0")
  local parts = {}
  for seg in flat:gmatch("[^%z]+") do
    local s = vim.trim(seg)
    if s ~= "" then parts[#parts + 1] = s end
  end
  return parts
end

-- Options that turn an otherwise read-only "reader" binary into a writer/executor,
-- which the command prefix can't see: rg runs a program (`--pre`/`--pre-glob`/
-- `--hostname-bin`), git writes/execs a helper (`--output`/`--ext-diff`), and find's
-- action predicates (`-exec`/`-execdir`/`-ok`/`-okdir`/`-delete`/`-fprint*`/`-fls`).
-- A segment carrying any of these is never auto-allowed, whatever prefix it matches.
-- Anchored so safe look-alikes (`--pretty`, `--output-indicator-*`, `--no-ext-diff`)
-- don't false-trip. This is a denylist (fail-open for an unknown dangerous flag) —
-- defense-in-depth over the deny-by-default prefix match, not a proof.
local DANGEROUS_ARG = {
  "%-%-pre[%s=%-]", "%-%-hostname%-bin",        -- rg → exec a program
  "%-%-output[%s=]", "%-%-ext%-diff",           -- git → write file / run diff helper
  " %-exec", " %-ok", " %-delete", " %-fprint", " %-fls", -- find → exec / delete / write
}
local function has_dangerous_arg(cmd)
  -- Normalize ALL whitespace (tab/CR/…) to single spaces and pad with a leading
  -- space first: bash word-splits on tab too, so a literal-space anchor like
  -- ` -exec` would otherwise miss `find x<TAB>-exec<TAB>sh` (a real -exec). The pad
  -- also catches a segment that begins with a dangerous flag.
  local s = " " .. tostring(cmd or ""):gsub("%s+", " ")
  for _, pat in ipairs(DANGEROUS_ARG) do
    if s:find(pat) then return true end
  end
  return false
end

-- Does ONE shell command match any Bash allow rule? Rules ("Bash(git status*)",
-- "Bash(rg:*)") → prefix-match up to the first glob/`:` wildcard. A segment carrying
-- a write/exec flag (above) is rejected up front regardless of prefix.
local function bash_command_allowed(cmd, rules)
  if has_dangerous_arg(cmd) then return false end
  for _, rule in ipairs(rules or {}) do
    local pat = rule:match("^Bash%((.+)%)$")
    if pat then
      local prefix = vim.trim((pat:gsub("[:%*].*$", "")))
      if prefix ~= "" and cmd:sub(1, #prefix) == prefix then return true end
    end
  end
  return false
end

-- Path-scoping (deny-by-default): bounds auto-run bash to the agent's worktree.
-- A segment auto-allows only if every path-looking token resolves UNDER `cwd`.
-- Absolute paths outside cwd, `~`, escaping `..`, and unresolved `$var` paths →
-- false (prompt) — so `cat /etc/shadow`, `cd /other`, `git -C /elsewhere …` ask.
-- `cwd` nil/"" disables scoping (callers without a known cwd keep the old
-- behavior). Heuristic + fail-closed: anything it can't prove is inside cwd, it
-- rejects. Variable paths aren't resolved (parked) → they prompt. /dev/* exempt.
local function paths_within_cwd(cmd, cwd)
  if not cwd or cwd == "" then return true end
  local root = cwd:gsub("/+$", "")
  for raw in tostring(cmd):gmatch("%S+") do
    -- Unescape shell backslash-escapes (`\/`→`/`, `\.`→`.`) so obfuscated absolute
    -- and traversal paths can't dodge the `^/` / `..` anchors below.
    local t = raw:gsub("^[\"']+", ""):gsub("[\"']+$", ""):gsub("\\(.)", "%1")
    -- Any shell-variable / ANSI-C-quote reference (`$WT`, `${DIR}`, `$'…'`, `$"…"`)
    -- is unresolvable pre-expansion → could point anywhere → prompt. Anchored to `$`
    -- + word/brace/quote so a regex end-anchor (`grep "foo$"`) is NOT flagged.
    if t:find("%$['\"{%w_]") then return false end
    local looks_path = t:match("^~") or t:match("^/") or t:match("^%.%.?/")
      or t == ".." or t:find("/", 1, true)
    if looks_path and not t:match("^/dev/") then
      if t:match("^~") then return false end                                 -- home
      if t == ".." or t:find("../", 1, true) or t:find("/..", 1, true) then return false end -- .. escape
      if t:match("^/") and t ~= root and t:sub(1, #root + 1) ~= root .. "/" then return false end -- outside cwd
    end
  end
  return true
end

-- The first sub-command (split like matches_allow does) that ISN'T allow-listed —
-- so `why()` can name the exact piece that's outside the allow-list, not just
-- gesture at the whole (possibly compound/chained) command line. Pure.
local function offending_segment(command, rules)
  for _, cmd in ipairs(M.split_commands(command)) do
    if not bash_command_allowed(cmd, rules) then return cmd end
  end
  return nil
end

-- Does a tool call match any of claude's pre-approval rules? Reuses the user's
-- existing allowlist so pre-approved commands run silently. Bare tool-name rules
-- ("Read") match directly. A Bash command is allowed only when EVERY sub-command
-- (split on && || | ; \n …) is allowlisted AND stays within `cwd` — so a chained/
-- piped command never rides in on an allowed prefix (`git status && rm -rf /`),
-- and no allowed reader reaches outside the worktree (`cat /etc/shadow`).
function M.matches_allow(tool, input, rules, cwd)
  input = type(input) == "table" and input or {}
  for _, rule in ipairs(rules or {}) do
    if rule == tool then return true end
  end
  if not is_bash(tool) then return false end
  local cmds = M.split_commands(input.command)
  if #cmds == 0 then return false end
  for _, cmd in ipairs(cmds) do
    if not bash_command_allowed(cmd, rules) then return false end
    if not paths_within_cwd(cmd, cwd) then return false end
  end
  return true
end

-- Session memory of "allow for session" decisions, keyed by request_key.
M.session_allow = {}
function M._reset() M.session_allow = {}; M.pending = {} end

-- Claude pre-approval rules (permissions.allow), loaded from settings. Empty
-- until load_allow_rules runs.
M.allow_rules = {}

-- Extract permissions.allow from a settings JSON string. Pure.
function M.parse_allow_rules(json)
  local ok, t = pcall(vim.json.decode, json)
  if ok and type(t) == "table" and type(t.permissions) == "table" and type(t.permissions.allow) == "table" then
    return t.permissions.allow
  end
  return {}
end

-- Where "always allow" rules persist. A dedicated store (not the user's
-- hand-maintained settings.json) so we never reformat their file — read on
-- startup alongside claude's own allowlist. Overridable in tests.
function M.allow_store_path() return M._allow_store or vim.fn.expand("~/.claude/code-agents-allow.json") end

-- Load + merge claude's pre-approval rules from settings files into allow_rules.
-- Missing files are skipped. Defaults to claude settings + our own allow store.
function M.load_allow_rules(paths)
  paths = paths or {
    vim.fn.expand("~/.claude/settings.json"), vim.fn.expand("~/.claude/settings.local.json"),
    M.allow_store_path(),
  }
  local rules = {}
  for _, p in ipairs(paths) do
    local f = io.open(p, "r")
    if f then vim.list_extend(rules, M.parse_allow_rules(f:read("*a"))); f:close() end
  end
  M.allow_rules = rules
  return rules
end

-- ── whitelist growth (log → inspect → permanently allow) ─────────────────────
-- The whitelist is deny-by-default and stays that way; the fix for "too many
-- prompts" is making it EASY to grow: every request is logged, the prompt shows
-- WHY + the exact command, and "always allow" persists an editable rule.

-- The salient signature of a tool call (command / path). Shared by keys + audit.
function M._sig(tool, input)
  input = type(input) == "table" and input or {}
  return input.command or input.file_path or input.path or ""
end

-- A sensible starting rule to prefill the "always allow" editor. Bash → scope to
-- the executable (`Bash(npm:*)`), which the user then edits (tighten, move the
-- `*`). Other tools → the bare tool name. Pure.
function M.suggest_rule(tool, input)
  if is_bash(tool) then
    local exe = vim.trim(M._sig(tool, input)):match("^%S+")
    return exe and string.format("Bash(%s:*)", exe) or "Bash"
  end
  return tool
end

-- Human explanation of why this call needs approval (mirrors claude showing the
-- triggering rule). Everything auto-allowable is resolved before we prompt, so
-- reaching here always means "not in the allow-list". For a chained/piped
-- command, names the specific sub-command that's outside the allow-list rather
-- than just the whole (already-shown) command line. Pure.
function M.why(tool, input)
  if is_bash(tool) then
    local reason = "shell command not in the allow-list (can run outside the worktree)"
    local cmd = M._sig(tool, input)
    local offending = offending_segment(cmd, M.allow_rules)
    if offending and offending ~= vim.trim(cmd) then
      reason = reason .. " — the unlisted part: " .. offending
    end
    return reason
  end
  return tool .. " not in the allow-list"
end

-- Append `rule` to a settings JSON string's permissions.allow (dedup, creating
-- the structure if absent). Returns the new JSON string. Pure.
function M.add_rule_to_json(json, rule)
  local ok, t = pcall(vim.json.decode, json or "")
  if not ok or type(t) ~= "table" then t = {} end
  if type(t.permissions) ~= "table" then t.permissions = {} end
  if type(t.permissions.allow) ~= "table" then t.permissions.allow = {} end
  if not vim.tbl_contains(t.permissions.allow, rule) then
    t.permissions.allow[#t.permissions.allow + 1] = rule
  end
  return vim.json.encode(t)
end

-- Persist an "always allow" rule to the store file AND add it live so the next
-- matching call is auto-allowed this session too.
function M.persist_allow_rule(rule, path)
  path = path or M.allow_store_path()
  local cur = ""
  local f = io.open(path, "r"); if f then cur = f:read("*a"); f:close() end
  vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
  local w = io.open(path, "w"); if w then w:write(M.add_rule_to_json(cur, rule)); w:close() end
  if not vim.tbl_contains(M.allow_rules, rule) then M.allow_rules[#M.allow_rules + 1] = rule end
  return M.allow_rules
end

-- Append one JSONL record to the permission log (`:CodeAgentsPermissions`). This
-- is the audit trail: what agents asked for and what you decided → inspect later
-- to grow the whitelist. Overridable path in tests.
function M.perm_log_path()
  return M._perm_log or (vim.fn.stdpath("cache") .. "/code-agents/permissions.jsonl")
end

function M.audit(record, path)
  path = path or M.perm_log_path()
  record = record or {}
  record.time = record.time or os.date("%Y-%m-%d %H:%M:%S")
  vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
  local f = io.open(path, "a")
  if f then f:write(vim.json.encode(record) .. "\n"); f:close() end
end

-- ── async pending requests ───────────────────────────────────────────────────
-- Background agents don't block nvim: request() registers a pending decision +
-- notifies, and returns fast; the agent's hook subprocess polls the decision
-- file until the user resolves it via the review UI.

M.pending = {} -- list of { tool, input, session, decisionfile }

-- Called by the hook (via --remote-expr) with the request file. Returns either a
-- hook-output JSON string (auto-decided) or "PENDING:<decisionfile>".
function M.request(reqfile)
  local f = io.open(reqfile, "r")
  if not f then return M.hook_output("deny", "no request file") end
  local req = M.parse_hook_input(f:read("*a")); f:close()
  if not req then return M.hook_output("deny", "unparseable permission request") end
  if M.resolve_auto(req.tool, req.input, req.cwd) then return M.hook_output("allow") end
  local decisionfile = reqfile .. ".decision"
  local entry = { tool = req.tool, input = req.input, session = req.session, decisionfile = decisionfile }
  -- claude/llm-run transport: the hook polls the decision file, so we respond by writing it.
  entry.respond = function(choice, reason)
    local dec = (choice == "once" or choice == "session")
      and M.hook_output("allow") or M.hook_output("deny", reason or "denied in editor")
    local fh = io.open(decisionfile, "w"); if fh then fh:write(dec); fh:close() end
  end
  M.add_pending(entry)
  return "PENDING:" .. decisionfile
end

-- Register a pending request from any transport (claude file-poll OR opencode ACP
-- RPC). `entry.respond(choice, reason)` delivers the decision the right way.
function M.add_pending(entry)
  M.pending[#M.pending + 1] = entry
  M.audit({ event = "ask", tool = entry.tool, cmd = M._sig(entry.tool, entry.input),
    session = entry.session, why = M.why(entry.tool, entry.input),
    suggest = M.suggest_rule(entry.tool, entry.input) })
  M._notify_pending(entry)
end

-- Resolve a pending request: deliver the decision via the transport-specific
-- responder, drop the entry, resume the agent. choice: once | session | always |
-- deny. `reason` carries the (edited) allow rule for `always`, else a deny note.
function M.resolve_pending(entry, choice, reason)
  if choice == "session" then M.session_allow[M.request_key(entry.tool, entry.input)] = true end
  if choice == "always" and reason and reason ~= "" then M.persist_allow_rule(reason) end
  local allow = choice == "once" or choice == "session" or choice == "always"
  if entry.respond then entry.respond(allow and "once" or "deny", (not allow) and reason or nil) end
  M.audit({ event = choice, tool = entry.tool, cmd = M._sig(entry.tool, entry.input),
    session = entry.session, rule = choice == "always" and reason or nil,
    reason = (not allow) and reason or nil })
  for i, e in ipairs(M.pending) do if e == entry then table.remove(M.pending, i); break end end
  M._update_agent(entry.session, function(a) a.pending = nil; a.status = "running" end)
end

-- Mark the request's agent `awaiting` + attach the request so it shows IN the
-- agent's conversation (decide there, in context; q defers). Overridable in tests.
function M._notify_pending(entry)
  M._update_agent(entry.session, function(a) a.status = "awaiting"; a.pending = entry end)
  vim.notify(string.format("code-agents: %s needs permission — open the agent to decide (<leader>aw)", entry.tool),
    vim.log.levels.WARN)
end

-- Best-effort mutate the agent for a session, then refresh its view.
function M._update_agent(session, fn)
  local ok, core = pcall(require, "code-agents.core")
  if not ok or not session then return end
  local a = core.find_by_session(session)
  if a then fn(a); if a.on_update then a.on_update() end end
end

-- Should this tool call be allowed silently (no notify)? True if read-only, or
-- remembered this session, or matching claude's pre-approval allowlist.
function M.resolve_auto(tool, input, cwd)
  if M.classify(tool) == "allow" then return true end
  if M.session_allow[M.request_key(tool, input)] then return true end
  return M.matches_allow(tool, input, M.allow_rules, cwd)
end

-- Stable key for a tool call — what "allow for session" remembers. Bash keys on
-- the exact command; others on the target path (else the tool name).
function M.request_key(tool, input)
  return tool .. "\0" .. tostring(M._sig(tool, input))
end

-- Parse a PreToolUse hook stdin payload → { tool, input, session, cwd }, or nil.
function M.parse_hook_input(json)
  local ok, t = pcall(vim.json.decode, json)
  if not ok or type(t) ~= "table" then return nil end
  return { tool = t.tool_name, input = t.tool_input, session = t.session_id, cwd = t.cwd }
end

-- Build the PreToolUse hook stdout envelope claude expects.
function M.hook_output(decision, reason)
  return vim.json.encode({
    hookSpecificOutput = {
      hookEventName = "PreToolUse",
      permissionDecision = decision,
      permissionDecisionReason = reason,
    },
  })
end

return M
