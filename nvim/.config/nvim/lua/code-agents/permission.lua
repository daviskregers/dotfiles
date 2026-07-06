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

function M.classify(tool)
  if M.auto_allow[tool] then return "allow" end
  return "ask"
end

-- Does a tool call match any of claude's pre-approval rules? Reuses the user's
-- existing allowlist so pre-approved commands run silently. Pragmatic matcher:
-- bare tool-name rules ("Read"); Bash rules ("Bash(git status*)", "Bash(rg:*)")
-- → prefix-match the command up to the first glob/`:` wildcard.
function M.matches_allow(tool, input, rules)
  input = type(input) == "table" and input or {}
  for _, rule in ipairs(rules or {}) do
    if rule == tool then return true end
    local pat = rule:match("^Bash%((.+)%)$")
    if pat and tool == "Bash" then
      local prefix = vim.trim((pat:gsub("[:%*].*$", "")))
      if prefix ~= "" and (input.command or ""):sub(1, #prefix) == prefix then return true end
    end
  end
  return false
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

-- Load + merge claude's pre-approval rules from settings files into allow_rules.
-- Missing files are skipped. Defaults to the user's claude settings.
function M.load_allow_rules(paths)
  paths = paths or { vim.fn.expand("~/.claude/settings.json"), vim.fn.expand("~/.claude/settings.local.json") }
  local rules = {}
  for _, p in ipairs(paths) do
    local f = io.open(p, "r")
    if f then vim.list_extend(rules, M.parse_allow_rules(f:read("*a"))); f:close() end
  end
  M.allow_rules = rules
  return rules
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
  if M.resolve_auto(req.tool, req.input) then return M.hook_output("allow") end
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
  M._notify_pending(entry)
end

-- Resolve a pending request: deliver the decision via the transport-specific
-- responder, drop the entry, resume the agent. choice: once | session | deny | improve.
function M.resolve_pending(entry, choice, reason)
  if choice == "session" then M.session_allow[M.request_key(entry.tool, entry.input)] = true end
  if entry.respond then entry.respond(choice, reason) end
  for i, e in ipairs(M.pending) do if e == entry then table.remove(M.pending, i); break end end
  M._update_agent(entry.session, function(a) a.pending = nil; a.status = "running" end)
end

-- Mark the request's agent `awaiting` + attach the request so it shows IN the
-- agent's conversation (decide there, in context; q defers). Overridable in tests.
function M._notify_pending(entry)
  M._update_agent(entry.session, function(a) a.status = "awaiting"; a.pending = entry end)
  vim.notify(string.format("code-agents: %s needs permission — open the agent to decide (<leader>ap)", entry.tool),
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
function M.resolve_auto(tool, input)
  if M.classify(tool) == "allow" then return true end
  if M.session_allow[M.request_key(tool, input)] then return true end
  return M.matches_allow(tool, input, M.allow_rules)
end

-- Stable key for a tool call — what "allow for session" remembers. Bash keys on
-- the exact command; others on the target path (else the tool name).
function M.request_key(tool, input)
  input = type(input) == "table" and input or {}
  local sig = input.command or input.file_path or input.path or ""
  return tool .. "\0" .. tostring(sig)
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
