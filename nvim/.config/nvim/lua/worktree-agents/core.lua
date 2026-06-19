-- Background worktree agents: headless `llm-run` agents in throwaway git
-- worktrees. Spawn N in parallel, observe output, steer, then merge or discard.
-- Sibling to custom/agents.lua (interactive terminal slots) — this is the
-- background/headless subsystem. Orchestration is pure lua over `vim.system`;
-- transport + session continuity live in the `llm-run` shared bin.
--
-- Agent = { id, provider, model, agent_type, branch, worktree, session,
--           status, prompt, cost, owner, proc, partial }.
-- Statuses: running | awaiting | idle | done | error | stopped.

local M = {}
local uv = vim.uv or vim.loop

-- ── config ────────────────────────────────────────────────────────────────

M.config = {
  branch_prefix  = "agent/",
  max_concurrent = 4,                 -- soft cap on running agents (warn past it)
  default_provider = "claude",
  llm_run = "llm-run",                -- dispatcher binary (override in tests)
  root = nil,                         -- worktree root override (default: stdpath cache)
  providers = {
    -- claude has no programmatic model list (`claude models` is the model talking);
    -- these are the stable --model aliases.
    claude   = { models = { "opus", "sonnet", "haiku", "fable" }, default_model = "opus", agents = {} },
    -- opencode models are queried live via `opencode models` (see list_models).
    -- default_model is the silent default for `wa`; pin a valid one.
    opencode = { models = nil, default_model = "github-copilot/claude-sonnet-4.5", agents = {} },
  },
}

local state = { agents = {} }   -- id -> agent

-- ── pure helpers (tested) ───────────────────────────────────────────────────

-- Branch-safe slug from a free-text prompt: lowercase, non-alnum → '-',
-- collapse/trim dashes, cap length.
function M.slugify(prompt)
  local s = (prompt or ""):lower():gsub("[^%w]+", "-"):gsub("^-+", ""):gsub("-+$", "")
  if #s > 32 then s = s:sub(1, 32):gsub("-+$", "") end
  if s == "" then s = "agent" end
  return s
end

-- Short, collision-resistant suffix derived from a uuid (or any seed string).
function M.short_id(seed)
  return tostring(seed):lower():gsub("[^%w]", ""):sub(1, 6)
end

function M.branch_name(slug)
  return M.config.branch_prefix .. slug
end

-- Filesystem-safe worktree path under the cache root. Branch '/' → '-'.
function M.worktree_path(root, repo, branch)
  return table.concat({ root, repo, (branch:gsub("/", "-")) }, "/")
end

-- Build the `llm-run` argv. Pure — given opts, returns the command list.
-- opts: provider, model, agent (persona), session, resume (bool), prompt.
function M.build_llm_cmd(opts)
  local cmd = { M.config.llm_run, opts.provider }
  if opts.model and opts.model ~= "" then
    vim.list_extend(cmd, { "-m", opts.model })
  end
  if opts.agent and opts.agent ~= "" then
    vim.list_extend(cmd, { "--agent", opts.agent })
  end
  if opts.session and opts.session ~= "" then
    vim.list_extend(cmd, { "--session", opts.session })
  end
  if opts.resume then
    table.insert(cmd, "--resume")
  end
  vim.list_extend(cmd, { "--", opts.prompt or "" })
  return cmd
end

-- Decode one normalized JSONL line → event table, or nil on blank/garbage.
function M.parse_event(line)
  if not line or line == "" then return nil end
  local ok, ev = pcall(vim.json.decode, line)
  if ok and type(ev) == "table" and ev.type then return ev end
  return nil
end

-- Map a normalized event onto the next status. Returns nil to leave unchanged.
function M.status_from_event(event)
  if not event then return nil end
  local t = event.type
  if t == "text" or t == "thinking" or t == "tool" then
    return "running"
  elseif t == "done" then
    return "done"
  elseif t == "error" then
    return "error"
  end
  return nil
end

-- git argv builders (pure). Caller sets cwd (worktree vs main checkout).
function M.git_worktree_add_args(path, branch, base)
  return { "worktree", "add", "-b", branch, path, base }
end

function M.git_worktree_remove_args(path, force)
  local a = { "worktree", "remove" }
  if force then table.insert(a, "--force") end
  table.insert(a, path)
  return a
end

function M.git_branch_delete_args(branch)
  return { "branch", "-D", branch }
end

function M.git_rebase_args(base)         -- run in the agent worktree
  return { "rebase", base }
end

-- Manifest is the durable, reconstructable record (runtime-only fields dropped).
function M.encode_manifest(agents)
  local out = {}
  for id, a in pairs(agents) do
    out[id] = {
      id = a.id, provider = a.provider, model = a.model, agent_type = a.agent_type,
      branch = a.branch, worktree = a.worktree, base = a.base, session = a.session,
      status = a.status, prompt = a.prompt, cost = a.cost, owner = a.owner,
    }
  end
  return vim.json.encode(out)
end

function M.decode_manifest(str)
  if not str or str == "" then return {} end
  local ok, t = pcall(vim.json.decode, str)
  if ok and type(t) == "table" then return t end
  return {}
end

-- Selectable models for a provider. opencode is queried live (cached) via
-- `opencode models`; others use the static config list.
function M.list_models(provider)
  local pcfg = M.config.providers[provider] or {}
  if provider == "opencode" then
    if not M._opencode_models then
      M._opencode_models = {}
      local res = vim.system({ "opencode", "models" }, { text = true }):wait()
      if res.code == 0 then
        for line in (res.stdout or ""):gmatch("[^\n]+") do
          local m = vim.trim(line)
          if m ~= "" then table.insert(M._opencode_models, m) end
        end
      end
    end
    if #M._opencode_models > 0 then return M._opencode_models end
  end
  return pcfg.models or {}
end

-- Cross-platform UUID: uuidgen → linux random uuid → lua v4 fallback.
function M.uuid()
  if vim.fn.executable("uuidgen") == 1 then
    local out = vim.fn.systemlist("uuidgen")[1]
    if out and out ~= "" then return vim.trim(out):lower() end
  end
  local f = io.open("/proc/sys/kernel/random/uuid", "r")
  if f then local u = f:read("*l"); f:close(); if u then return u end end
  local t = {}
  for i = 1, 32 do t[i] = string.format("%x", math.random(0, 15)) end
  return table.concat(t):gsub("(%x%x%x%x%x%x%x%x)(%x%x%x%x)(%x%x%x%x)(%x%x%x%x)", "%1-%2-%3-%4-")
end

-- ── repo / path resolution ──────────────────────────────────────────────────

function M.root()
  return M.config.root or (vim.fn.stdpath("cache") .. "/worktree-agents")
end

local function git(args, cwd)
  local res = vim.system(vim.list_extend({ "git" }, args), { cwd = cwd, text = true }):wait()
  return res.code == 0, vim.trim(res.stdout or ""), vim.trim(res.stderr or "")
end

-- Like git(), but returns RAW (untrimmed) stdout — trailing newlines matter for patches.
local function git_out(args, cwd)
  local res = vim.system(vim.list_extend({ "git" }, args), { cwd = cwd, text = true }):wait()
  return res.code == 0, res.stdout or ""
end

function M.repo_toplevel()
  local ok, out = git({ "rev-parse", "--show-toplevel" })
  return ok and out or nil
end

function M.repo_key()
  local top = M.repo_toplevel()
  return top and vim.fn.fnamemodify(top, ":t") or nil
end

-- main > master > current HEAD (mirrors the `gw` bin).
function M.base_branch()
  local ok, out = git({ "symbolic-ref", "refs/remotes/origin/HEAD" })
  if ok and out ~= "" then return out:gsub(".*/", "") end
  if git({ "show-ref", "--verify", "--quiet", "refs/heads/main" }) then return "main" end
  if git({ "show-ref", "--verify", "--quiet", "refs/heads/master" }) then return "master" end
  local _, head = git({ "rev-parse", "--abbrev-ref", "HEAD" })
  return head
end

local function repo_dir()
  return M.root() .. "/" .. (M.repo_key() or "unknown")
end

function M.manifest_path()
  return repo_dir() .. "/agents.json"
end

-- Stable per-agent dir keyed on the immutable id (NOT the session, which the
-- provider may replace — opencode mints its own ses_… id).
local function agent_dir(a)
  return repo_dir() .. "/" .. a.id
end

-- ── logging ──────────────────────────────────────────────────────────────────

local function append_file(path, text)
  vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
  local f = io.open(path, "a")
  if f then f:write(text); f:close() end
end

-- Fast-event-context safe: plain io only (no vim.fn / vim.system), dir must
-- already exist. Used from libuv stdout/stderr callbacks.
local function append_raw(path, text)
  local f = io.open(path, "a")
  if f then f:write(text); f:close() end
end

local function read_file(path)
  local f = io.open(path, "r")
  if not f then return "" end
  local c = f:read("*a"); f:close(); return c or ""
end

local function write_file(path, text)
  vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
  local f = io.open(path, "w")
  if f then f:write(text); f:close() end
end

local function tmp_with(text)
  local p = vim.fn.tempname(); write_file(p, text); return p
end

function M.log(level, msg)
  append_file(repo_dir() .. "/clank.log", string.format("%s [%s] %s\n", os.date("%F %T"), level, msg))
end

-- ── manifest persistence ─────────────────────────────────────────────────────

local function save_manifest()
  append_file(M.manifest_path(), "")               -- ensure dir
  local p = M.manifest_path()
  local f = io.open(p, "w")
  if f then f:write(M.encode_manifest(state.agents)); f:close() end
end

-- ── status / notifications ───────────────────────────────────────────────────

-- States that warrant pulling the user in.
local ATTENTION = { awaiting = "WARN", error = "WARN", done = "INFO" }

local function set_status(a, status)
  if not status or a.status == status then return end
  a.status = status
  local level = ATTENTION[status]
  if level and a.id ~= M.focused then
    vim.schedule(function()
      vim.notify(string.format("agent %s: %s", a.id, status), vim.log.levels[level])
    end)
  end
  save_manifest()
end

function M.counts()
  local c = { running = 0, awaiting = 0, idle = 0, done = 0, error = 0, stopped = 0 }
  for _, a in pairs(state.agents) do c[a.status] = (c[a.status] or 0) + 1 end
  return c
end

-- Compact statusline summary, hidden when there are no agents.
function M.statusline()
  if next(state.agents) == nil then return "" end
  local c = M.counts()
  local parts, glyph = {}, { running = "▶", awaiting = "⏸", done = "✓", error = "✗" }
  for _, k in ipairs({ "running", "awaiting", "done", "error" }) do
    if c[k] > 0 then table.insert(parts, glyph[k] .. c[k]) end
  end
  return table.concat(parts, " ")
end

-- ── stream handling ──────────────────────────────────────────────────────────

-- The salient argument of a tool call (the Bash command, the file path, …).
local function tool_summary(input)
  local v
  if type(input) == "table" then
    v = input.command or input.file_path or input.path or input.pattern
      or input.query or input.url or input.description
    if not v then local ok, j = pcall(vim.json.encode, input); v = ok and j or nil end
  elseif type(input) == "string" then
    v = input
  end
  if not v or v == "" then return "" end
  v = tostring(v):gsub("%s+", " ")
  if #v > 140 then v = v:sub(1, 137) .. "…" end
  return ": " .. v
end

-- Render an event to a human-readable line for output.log (nil = nothing shown).
local function render(ev)
  if ev.type == "text" then return ev.text
  elseif ev.type == "tool" then return "  ⚙ " .. (ev.tool or "?") .. tool_summary(ev.input)
  elseif ev.type == "error" then return "✗ " .. tostring(ev.error)
  end
  -- thinking/session/done are not shown inline (thinking is noisy; done summarized elsewhere)
end

local function ingest_line(a, line)
  local ev = M.parse_event(line)
  if not ev then return end
  if ev.type == "session" and ev.session then a.session = ev.session end
  if ev.type == "done" then
    a.cost = (a.cost or 0) + (ev.cost or 0)
    if ev.denials and #ev.denials > 0 then a.denials = ev.denials end
  end
  local piece = render(ev)
  if piece and piece ~= "" then
    table.insert(a.output, piece)
    append_file(a.dir .. "/output.log", piece .. "\n")   -- readable conversation log
  end
  -- Terminal status (done/error) is owned by on_exit; the stream drives "running".
  if M.status_from_event(ev) == "running" then set_status(a, "running") end
end

-- vim.system stdout chunks split arbitrarily; buffer until newline.
local function on_stdout(a, data)
  if not data then return end
  a.partial = (a.partial or "") .. data
  while true do
    local nl = a.partial:find("\n")
    if not nl then break end
    local line = a.partial:sub(1, nl - 1)
    a.partial = a.partial:sub(nl + 1)
    vim.schedule(function() ingest_line(a, line) end)
  end
end

-- ── public: spawn / send / stop / lifecycle ──────────────────────────────────

local function ensure_servername()
  if not vim.v.servername or vim.v.servername == "" then
    pcall(vim.fn.serverstart)
  end
  return vim.v.servername
end

local function launch(a, resume)
  a.dir = a.dir or agent_dir(a)          -- normal context here — git/fs ok
  vim.fn.mkdir(a.dir, "p")
  append_file(a.dir .. "/output.log", "\n▶ you:\n" .. (a.prompt or "") .. "\n\n◀ agent:\n")
  local cmd = M.build_llm_cmd({
    provider = a.provider, model = a.model, agent = a.agent_type,
    session = a.session, resume = resume, prompt = a.prompt,
  })
  set_status(a, "running")
  a.proc = vim.system(cmd, {
    cwd = a.worktree,
    text = true,
    env = { CLANK_NVIM_ADDR = ensure_servername() },
    stdout = function(_, data) on_stdout(a, data) end,
    stderr = function(_, data) if data then append_raw(a.dir .. "/stderr.log", data) end end,
  }, function(obj)
    vim.schedule(function()
      a.proc = nil
      -- No commits: the agent's work stays as changes in its worktree. We never
      -- write commits into your history — `diff`/`apply` read the worktree state.
      if obj.code ~= 0 then
        -- Surface the failure in the output log so it's visible (stderr is captured
        -- separately and wouldn't otherwise show in the output view / preview).
        local err = read_file(a.dir .. "/stderr.log")
        local tail = err ~= "" and ("\n✗ exited " .. obj.code .. ":\n" .. err:sub(-2000)) or
          ("\n✗ exited " .. obj.code)
        append_file(a.dir .. "/output.log", tail .. "\n")
      end
      if a.status == "running" then set_status(a, obj.code == 0 and "done" or "error") end
    end)
  end)
end

-- The agent's complete change set vs base, as a unified patch (committed +
-- uncommitted + untracked). Staging into the throwaway worktree index makes the
-- index == current worktree state, so `diff --cached base` captures everything.
function M.changes_patch(a)
  git({ "add", "-A" }, a.worktree)
  local _, out = git_out({ "diff", "--cached", "--binary", a.base or M.base_branch() }, a.worktree)
  return out
end

-- Spawn a background agent in a fresh worktree. opts: provider, model, agent.
function M.spawn(prompt, opts)
  opts = opts or {}
  assert(prompt and prompt ~= "", "prompt required")
  local top = M.repo_toplevel()
  assert(top, "not in a git repository")

  local provider = opts.provider or M.config.default_provider
  local pcfg = M.config.providers[provider] or {}
  local model = opts.model or pcfg.default_model

  local running = M.counts().running
  if running >= M.config.max_concurrent then
    vim.notify(string.format("%d agents already running (soft cap %d)", running, M.config.max_concurrent),
      vim.log.levels.WARN)
  end

  local id = M.uuid()
  local slug = M.slugify(prompt) .. "-" .. M.short_id(id)
  local branch = M.branch_name(slug)
  local worktree = M.worktree_path(M.root(), M.repo_key(), branch)
  local base = M.base_branch()

  vim.fn.mkdir(vim.fn.fnamemodify(worktree, ":h"), "p")
  local ok, _, err = git(M.git_worktree_add_args(worktree, branch, base), top)
  if not ok then
    M.log("ERROR", "worktree add failed: " .. err)
    return vim.notify("worktree add failed: " .. err, vim.log.levels.ERROR)
  end

  local a = {
    id = slug, provider = provider, model = model, agent_type = opts.agent,
    branch = branch, worktree = worktree, base = base, session = id,
    status = "idle", prompt = prompt, cost = 0, output = {}, partial = "",
    owner = ensure_servername(),
  }
  state.agents[slug] = a
  M.log("INFO", "spawn " .. slug .. " (" .. provider .. (model and "/" .. model or "") .. ")")
  launch(a, false)
  save_manifest()
  return a
end

-- Continue a session with a new turn. Resumes a stopped/done agent first.
function M.send(id, text)
  local a = state.agents[id]
  if not a then return vim.notify("no such agent: " .. tostring(id), vim.log.levels.WARN) end
  if a.proc then return vim.notify("agent " .. id .. " is busy", vim.log.levels.WARN) end
  a.prompt = text
  M.log("INFO", "send " .. id)
  launch(a, true)   -- resume the cwd-anchored session
end

-- Kill the current turn/process; keep worktree + session (resumable).
function M.stop(id)
  local a = state.agents[id]
  if not a then return end
  if not a.proc then
    return vim.notify("agent " .. id .. " is not running", vim.log.levels.INFO)
  end
  pcall(function() a.proc:kill("sigterm") end)
  set_status(a, "stopped")
  M.log("INFO", "stop " .. id)
  vim.notify("stopped " .. id, vim.log.levels.INFO)
end

function M.list()
  local out = {}
  for _, a in pairs(state.agents) do table.insert(out, a) end
  table.sort(out, function(x, y) return x.id < y.id end)
  return out
end

function M.get(id) return state.agents[id] end

function M.output_log(id)
  local a = state.agents[id]
  return a and ((a.dir or agent_dir(a)) .. "/output.log") or nil
end

-- ── apply / discard / sync ───────────────────────────────────────────────────

-- 3-way merge ONE file into the main checkout, writing git-style conflict
-- markers on overlap. ours = your working tree, base = base:path, theirs = agent.
-- Returns true if the file ended up conflicted.
function M._merge_one(a, base, path, main_path)
  local agent_c = read_file(a.worktree .. "/" .. path)
  local _, base_c = git_out({ "show", base .. ":" .. path }, a.worktree)  -- "" if new at base
  local cur_c = read_file(main_path)                                       -- "" if absent here
  if agent_c:find("\0", 1, true) or cur_c:find("\0", 1, true) then         -- binary: take agent's
    write_file(main_path, agent_c)
    return false
  end
  local tb, ta, tc = tmp_with(base_c), tmp_with(agent_c), tmp_with(cur_c)
  local res = vim.system({ "git", "merge-file", "-p",
    "-L", "ours (working tree)", "-L", "base", "-L", "agent " .. a.id,
    tc, tb, ta }, { text = true }):wait()
  write_file(main_path, res.stdout or "")
  for _, t in ipairs({ tb, ta, tc }) do pcall(vim.fn.delete, t) end
  return res.code ~= 0   -- merge-file exit code = number of conflicts
end

-- Pull the agent's changes into YOUR working tree — per-file 3-way merge, so
-- overlaps land as standard <<<<<<< / ======= / >>>>>>> markers you resolve
-- inline. No commits, no index changes; works on a dirty tree. Resolve, then
-- commit as part of your own work with your own message.
function M.apply(id)
  local a = state.agents[id]
  if not a then return end
  local base = a.base or M.base_branch()
  git({ "add", "-A" }, a.worktree)
  local _, names = git({ "diff", "--cached", "--name-status", "--no-renames", base }, a.worktree)
  if names == "" then return vim.notify("nothing to apply from " .. id, vim.log.levels.INFO) end

  local top = M.repo_toplevel()
  local applied, conflicts, deleted = 0, {}, {}
  for line in names:gmatch("[^\n]+") do
    local status, path = line:match("^(%a)%s+(.+)$")
    if status == "D" then
      deleted[#deleted + 1] = path                 -- conservative: report, don't auto-remove
    elseif status and path then
      applied = applied + 1
      if M._merge_one(a, base, path, top .. "/" .. path) then conflicts[#conflicts + 1] = path end
    end
  end

  if #conflicts > 0 then
    M.log("WARN", "applied " .. id .. " with conflicts: " .. table.concat(conflicts, ", "))
    vim.notify(string.format("applied %s: %d file(s), %d with conflicts — resolve <<<<<<< markers:\n%s",
      id, applied, #conflicts, table.concat(conflicts, "\n")), vim.log.levels.WARN)
  else
    M.log("INFO", "applied " .. id .. " (" .. applied .. " file(s), clean)")
    vim.notify(string.format("applied %s into working tree — %d file(s), no conflicts", id, applied),
      vim.log.levels.INFO)
  end
  if #deleted > 0 then
    vim.notify("agent deleted (not auto-removed): " .. table.concat(deleted, ", "), vim.log.levels.WARN)
  end
end

function M.discard(id)
  local a = state.agents[id]
  if not a then return end
  if a.proc then M.stop(id) end
  local top = M.repo_toplevel()
  git(M.git_worktree_remove_args(a.worktree, true), top)
  git(M.git_branch_delete_args(a.branch), top)
  state.agents[id] = nil
  M.log("INFO", "discarded " .. id)
  save_manifest()
end

function M.sync(id)
  local a = state.agents[id]
  if not a then return end
  if a.proc then return vim.notify("stop agent " .. id .. " before sync", vim.log.levels.WARN) end
  local base = a.base or M.base_branch()
  local ok, _, err = git(M.git_rebase_args(base), a.worktree)
  if not ok then
    set_status(a, "awaiting")
    M.log("WARN", "sync " .. id .. " conflict: " .. err)
    return vim.notify("sync conflict in " .. id .. " — resolve in worktree", vim.log.levels.WARN)
  end
  M.log("INFO", "synced " .. id)
  vim.notify("synced " .. id .. " onto " .. base, vim.log.levels.INFO)
end

-- ── reattach ─────────────────────────────────────────────────────────────────

-- Rebuild the pool from the manifest, reconciled against live worktrees.
-- Agents whose process is gone (always, after a restart) become `stopped`.
function M.reattach()
  local f = io.open(M.manifest_path(), "r")
  if not f then return end
  local saved = M.decode_manifest(f:read("*a")); f:close()
  local top = M.repo_toplevel()
  local _, wt_out = git({ "worktree", "list", "--porcelain" }, top)
  for id, a in pairs(saved) do
    if a.worktree and wt_out:find(a.worktree, 1, true) then
      a.output, a.partial, a.proc = {}, "", nil
      if a.status == "running" then a.status = "stopped" end
      state.agents[id] = a
    end
  end
  M.log("INFO", "reattached " .. tostring(vim.tbl_count(state.agents)) .. " agent(s)")
end

-- ── test seam ────────────────────────────────────────────────────────────────

function M._reset()
  for id, a in pairs(state.agents) do
    if a.proc then pcall(function() a.proc:kill("sigterm") end) end
    state.agents[id] = nil
  end
  state.agents = {}
  M.focused = nil
  M._opencode_models = nil
end

return M
