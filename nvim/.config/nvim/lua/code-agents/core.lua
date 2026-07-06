-- code-agents: editor-anchored parallel LLM agents. Agents propose (pending
-- overlay), never write directly — you stay the only writer. See
-- .dk-notes/plans/code-agents.md.

local transport = require("llm-agent.transport")

local M = {}

-- ── config ──────────────────────────────────────────────────────────────────

-- Provider resolves per-machine: claude here, opencode elsewhere (opencode is
-- the cross-machine default). Override on opencode machines via local-config.
M.default_provider = "claude"
M.config = {
  providers = {
    claude = { default_model = "opus" },
    opencode = { default_model = "opencode/kimi-k2.7-code" },
  },
}

local state = { agents = {}, seq = 0 }

-- Lightweight debug log → stdpath('cache')/code-agents.log. `:CodeAgentsLog` opens it.
function M.log(msg)
  local f = io.open(vim.fn.stdpath("cache") .. "/code-agents.log", "a")
  if f then f:write(os.date("%H:%M:%S ") .. tostring(msg) .. "\n"); f:close() end
end

-- ── pure helpers (tested) ───────────────────────────────────────────────────

-- Parse a search agent's raw text into quickfix items. Tolerant: keeps only
-- lines shaped `path:line[:col]: reason`, drops prose / blanks / code fences.
-- col defaults to 1 when omitted.
function M.parse_search_results(text)
  local items = {}
  for line in (text or ""):gmatch("[^\n]+") do
    local f, l, c, msg = line:match("^(.-):(%d+):(%d+):%s*(.+)$")
    if not f then
      f, l, msg = line:match("^(.-):(%d+):%s*(.+)$")
      c = 1
    end
    if f and f ~= "" then
      items[#items + 1] = {
        filename = f, lnum = tonumber(l), col = tonumber(c) or 1, text = vim.trim(msg),
      }
    end
  end
  return items
end

-- Decide what to do when a search agent finishes. Pure. Returns an action
-- (qflist | empty | error), the parsed items, and whether the live view should
-- close (only when results open in the quickfix list).
function M.on_search_complete(text, code)
  if code ~= 0 then return { action = "error", items = {}, close = false } end
  local items = M.parse_search_results(text)
  if #items == 0 then return { action = "empty", items = items, close = false } end
  return { action = "qflist", items = items, close = true }
end

-- Populate the quickfix list from qf-shaped items (search hits OR pending-review
-- spans — same shape). `title` labels the list. Opens the window if non-empty.
function M.to_qflist(items, title)
  vim.fn.setqflist({}, " ", { title = title or "code-agents", items = items })
  if #items > 0 then vim.cmd("botright copen") end
end

-- Per-provider, per-verb default model. Provider is resolved per-machine
-- (claude here, opencode elsewhere). haiku/sonnet/opus are claude-only aliases.
-- Returns nil when unknown → caller falls back to the provider's default_model.
-- opencode ids left unset until confirmed on an opencode machine.
M.verb_model_default = {
  claude = { search = "haiku", explain = "sonnet", command = "opus" },
  opencode = {},
}

function M.model_for(provider, verb)
  local m = (M.verb_model_default[provider] or {})[verb]
  if m == nil or m == "" then return nil end
  return m
end

-- The salient argument of a tool call (command / path / pattern / query …).
local function tool_summary(input)
  if type(input) ~= "table" then return "" end
  local v = input.command or input.file_path or input.filePath or input.path or input.pattern
    or input.query or input.url or input.description
  if not v then return "" end
  v = tostring(v):gsub("%s+", " ")
  if #v > 100 then v = v:sub(1, 97) .. "…" end
  return ": " .. v
end

-- Full transcript (you / thinking / tool / text) → display lines. Flattened so
-- NO returned line contains a newline (nvim_buf_set_lines rejects those).
function M.render_transcript(a)
  local out = {}
  for _, e in ipairs(a.transcript or {}) do
    if e.kind == "you" then
      out[#out + 1] = "──▶ you:"; out[#out + 1] = e.text or ""; out[#out + 1] = ""
    elseif e.kind == "thinking" then
      out[#out + 1] = "  💭 " .. (e.text or "")
    elseif e.kind == "tool" then
      out[#out + 1] = "  ⚙ " .. (e.tool or "?") .. tool_summary(e.input)
    elseif e.kind == "error" then
      out[#out + 1] = "✗ " .. (e.text or "")
    elseif e.kind == "text" then
      out[#out + 1] = e.text or ""
    end
  end
  if #out == 0 then out = { "(no output — status: " .. a.status .. ")" } end
  if a.pending then
    out[#out + 1] = ""
    out[#out + 1] = "⏸ permission needed: " .. a.pending.tool .. "  "
      .. tostring((a.pending.input or {}).command or (a.pending.input or {}).file_path or "")
    out[#out + 1] = "   A: allow   S: allow-session   I: improve   D: deny   (q defers)"
  end
  if a.status and a.status ~= "running" and not a.pending then
    out[#out + 1] = ""
    out[#out + 1] = "── " .. a.status .. "  ·  a: reply   q: close ──"
  end
  return vim.split(table.concat(out, "\n"), "\n", { plain = true })
end

-- Resolve the model to use: explicit override → per-verb default → provider default.
function M.resolve_model(provider, verb, override)
  if override and override ~= "" then return override end
  return M.model_for(provider, verb) or (M.config.providers[provider] or {}).default_model
end

-- ── dispatch (shell — validated live) ────────────────────────────────────────

-- Reload buffers whose files an agent changed on disk, so approved edits show
-- up without a manual :e. autoread makes checktime re-read silently.
function M.reload_changed()
  vim.o.autoread = true
  pcall(vim.cmd, "checktime")
end

function M.repo_top()
  local res = vim.system({ "git", "rev-parse", "--show-toplevel" }, { text = true }):wait()
  return res.code == 0 and vim.trim(res.stdout) or vim.fn.getcwd()
end

local function next_id(verb)
  state.seq = state.seq + 1
  return verb .. "-" .. state.seq
end

-- Dispatch a read verb (explain/search) — no worktree, cwd = repo top, read-only.
-- opts: verb, prompt, provider, model (override), agent, on_text(chunk),
-- on_done(full_text, code). Returns the agent record. Parallel-safe.
function M.dispatch(opts)
  local provider = opts.provider or M.default_provider
  local model = M.resolve_model(provider, opts.verb, opts.model)
  local a = {
    id = next_id(opts.verb), verb = opts.verb, provider = provider, model = model,
    agent_type = opts.agent, status = "running", chunks = {}, transcript = {},
    permit = opts.permit, -- route this agent's tool permissions back to nvim
    cwd = opts.cwd,       -- run here (an isolated worktree) instead of the repo root
    worktree = opts.worktree, seed = opts.seed, -- set for review/merge later
    session = opts.session, -- our uuid → claude --session-id → resumable across restarts
  }
  a.on_done = opts.on_done -- persisted so steered turns reuse the completion handler
  state.agents[a.id] = a
  M.log("dispatch registered " .. a.id .. " (" .. provider .. "/" .. tostring(model) .. ")")
  M._launch(a, opts.prompt, opts)
  return a
end

-- ── transcript persistence (survives restart; keyed by session id) ───────────

function M.transcript_log(session)
  local dir = M.logs_dir or (vim.fn.stdpath("cache") .. "/code-agents/logs")
  return dir .. "/" .. session .. ".jsonl"
end

function M.persist_entry(session, entry)
  local p = M.transcript_log(session)
  vim.fn.mkdir(vim.fn.fnamemodify(p, ":h"), "p")
  local f = io.open(p, "a")
  if f then f:write(vim.json.encode(entry) .. "\n"); f:close() end
end

function M.load_transcript(session)
  local out = {}
  local f = io.open(M.transcript_log(session), "r")
  if not f then return out end
  for line in f:lines() do
    local ok, e = pcall(vim.json.decode, line)
    if ok and type(e) == "table" then out[#out + 1] = e end
  end
  f:close()
  return out
end

-- Overwrite the persisted transcript (coalesced) — cheaper than per-token appends
-- for opencode's token-streaming, and what reattach reloads.
function M.save_transcript(session, transcript)
  local p = M.transcript_log(session)
  vim.fn.mkdir(vim.fn.fnamemodify(p, ":h"), "p")
  local f = io.open(p, "w")
  if f then
    for _, e in ipairs(transcript) do f:write(vim.json.encode(e) .. "\n") end
    f:close()
  end
end

-- Persist a worktree agent's transcript, keyed by its worktree name (stable —
-- unlike a.session, which opencode replaces with its ACP id mid-run). Non-worktree
-- agents (ask/explain/search) aren't reattached, so they don't persist.
function M._persist(a)
  if a.worktree then M.save_transcript(vim.fn.fnamemodify(a.worktree, ":t"), a.transcript) end
end

-- Append a transcript entry, COALESCING consecutive same-kind streaming chunks
-- (text/thinking) into one block — opencode ACP streams one token per event.
local function push_entry(a, entry)
  local last = a.transcript[#a.transcript]
  if last and (entry.kind == "text" or entry.kind == "thinking") and last.kind == entry.kind then
    last.text = (last.text or "") .. (entry.text or "")
  elseif last and entry.kind == "tool" and last.kind == "tool" and entry.id and last.id == entry.id then
    last.input = entry.input or last.input -- same tool call progressing: keep name, take latest input
  else
    a.transcript[#a.transcript + 1] = entry
  end
end

-- Ingest one normalized event (text/thinking/tool/session/error) into the agent.
-- Shared by both transports (llm-run + ACP).
local function ingest_event(a, ev, opts)
  if ev.type == "session" and ev.session then a.session = ev.session end
  if ev.type == "thinking" and ev.text and ev.text ~= "" then
    push_entry(a, { kind = "thinking", text = ev.text })
  elseif ev.type == "tool" then
    push_entry(a, { kind = "tool", tool = ev.tool, input = ev.input, id = ev.id })
    if a.permit then M.reload_changed() end
  elseif ev.type == "text" and ev.text and ev.text ~= "" then
    a.chunks[#a.chunks + 1] = ev.text
    push_entry(a, { kind = "text", text = ev.text })
    if opts.on_text then opts.on_text(ev.text) end
  elseif ev.type == "error" and ev.error then
    push_entry(a, { kind = "error", text = tostring(ev.error) })
  end
  if a.on_update then a.on_update() end
end

-- Finalize a turn (status, attention notify, completion handler). Shared.
local function finish_turn(a, code, stderr, opts)
  a.proc = nil
  a.status = code == 0 and "done" or "error"
  if a.permit then M.reload_changed() end
  M.log("exit " .. a.id .. " code=" .. tostring(code) .. (stderr and stderr ~= "" and (" stderr=" .. stderr:sub(1, 200)) or ""))
  if code ~= 0 and stderr and stderr ~= "" then
    push_entry(a, { kind = "error", text = "exit " .. code .. ": " .. stderr })
  end
  M._persist(a) -- persist coalesced transcript for reattach
  if a.on_update then a.on_update() end
  if a.verb ~= "search" then
    local hint = a.worktree and "<leader>ar to review its changes" or "<leader>al to view"
    vim.notify(string.format("code-agents %s %s — %s", a.id, a.status, hint),
      a.status == "error" and vim.log.levels.ERROR or vim.log.levels.INFO)
  end
  if a.on_done then a.on_done(table.concat(a.chunks), code) end
end

-- Route an opencode ACP permission request through the shared async bridge.
local function on_acp_permission(entry)
  local perm = require("code-agents.permission")
  if perm.resolve_auto(entry.tool, entry.input) then entry.respond("once") else perm.add_pending(entry) end
end

-- Run/resume one turn for agent `a`. claude → llm-run (+PreToolUse hook bridge);
-- opencode → ACP (permission via session/request_permission). Transcript is
-- captured for display; chunks stay text-only so search parsing sees no noise.
function M._launch(a, prompt, opts)
  opts = opts or {}
  a.status = "running"
  push_entry(a, { kind = "you", text = prompt })
  M._persist(a) -- capture the task early (keyed by worktree name — stable across providers)
  M.log("launch " .. a.id .. " (" .. a.provider .. ") cwd=" .. (a.cwd or M.repo_top()))

  if a.provider == "opencode" then
    a.proc = require("llm-agent.acp").run({
      prompt = prompt, cwd = a.cwd or M.repo_top(),
      on_event = function(ev) ingest_event(a, ev, opts) end,
      on_permission = on_acp_permission,
      on_done = function() finish_turn(a, 0, nil, opts) end,
      on_exit = function(code) if a.status == "running" then finish_turn(a, code or 0, nil, opts) end end,
    })
    return
  end

  local ok, proc = pcall(transport.run, {
    provider = a.provider, model = a.model, agent = a.agent_type, prompt = prompt,
    session = a.session, resume = opts.resume, permit = a.permit, cwd = a.cwd or M.repo_top(),
    on_event = function(ev) ingest_event(a, ev, opts) end,
    on_exit = function(code, stderr) finish_turn(a, code, stderr, opts) end,
  })
  if not ok then M._fail(a, "launch failed: " .. tostring(proc)); return end
  a.proc = proc
end

-- Mark an agent errored with a visible reason (transcript entry + notify).
function M._fail(a, reason)
  a.status = "error"
  a.transcript[#a.transcript + 1] = { kind = "error", text = reason }
  if a.on_update then a.on_update() end
  vim.schedule(function()
    vim.notify("code-agents " .. a.id .. ": " .. reason, vim.log.levels.ERROR)
  end)
end

-- Send a follow-up turn to an existing agent, resuming its session. Fresh output
-- (chunks reset) so the steered response renders on its own. opts: on_text, on_done.
function M.steer(id, text, opts)
  local a = state.agents[id]
  if not a then return nil end
  if a.proc then return vim.notify("agent " .. id .. " is busy", vim.log.levels.WARN) end
  a.chunks = {}
  M._launch(a, text, vim.tbl_extend("force", { resume = true }, opts or {}))
  return a
end

-- Kill an agent's current turn; keep its record (resumable via steer).
function M.stop(id)
  local a = state.agents[id]
  if not a then return end
  if a.proc then pcall(function() a.proc:kill("sigterm") end) end
  a.proc, a.status = nil, "stopped"
end

function M.stop_all()
  for id, a in pairs(state.agents) do if a.proc then M.stop(id) end end
end

-- Forget an agent entirely: stop it, discard its worktree (no orphan), drop it.
function M.remove(id)
  local a = state.agents[id]
  M.stop(id)
  if a and a.worktree then
    pcall(function() require("code-agents.worktree").discard(a.repo or M.repo_top(), a.worktree) end)
  end
  state.agents[id] = nil
end

function M.remove_all()
  for _, id in ipairs(vim.tbl_keys(state.agents)) do M.remove(id) end
end

-- ── registry / statusline ────────────────────────────────────────────────────

function M.counts()
  local c = { running = 0, done = 0, error = 0, stopped = 0 }
  for _, a in pairs(state.agents) do c[a.status] = (c[a.status] or 0) + 1 end
  return c
end

function M.statusline()
  if next(state.agents) == nil then return "" end
  local c, parts = M.counts(), {}
  local glyph = { running = "▶", done = "✓", error = "✗", stopped = "■" }
  for _, k in ipairs({ "running", "done", "error", "stopped" }) do
    if c[k] > 0 then parts[#parts + 1] = glyph[k] .. c[k] end
  end
  return table.concat(parts, " ")
end

function M.list()
  local out = {}
  for _, a in pairs(state.agents) do out[#out + 1] = a end
  table.sort(out, function(x, y) return x.id < y.id end)
  return out
end

function M.get(id) return state.agents[id] end

-- Parse a worktree dir name → provider, session. Names are `<provider>-<uuid>`;
-- a bare/legacy name (no known provider prefix) → default provider + whole name.
function M.parse_worktree_name(name)
  for prov in pairs(M.config.providers) do
    local rest = name:match("^" .. prov .. "%-(.+)$")
    if rest then return prov, rest end
  end
  return M.default_provider, name
end

-- Find an agent by its provider session id (for the permission bridge to attach
-- a pending request to the agent that raised it).
function M.find_by_session(session)
  for _, a in pairs(state.agents) do if a.session == session then return a end end
  return nil
end

-- Selectable models for the shift-variant picker. claude = static aliases;
-- opencode queried live (cached).
function M.models(provider)
  if provider == "opencode" then
    if not M._opencode_models then
      M._opencode_models = {}
      local res = vim.system({ "opencode", "models" }, { text = true }):wait()
      if res.code == 0 then
        for line in (res.stdout or ""):gmatch("[^\n]+") do
          local m = vim.trim(line)
          if m ~= "" then M._opencode_models[#M._opencode_models + 1] = m end
        end
      end
    end
    return M._opencode_models
  end
  return { "opus", "sonnet", "haiku", "fable" }
end

-- Rebuild agents from existing worktrees after an nvim restart. Each worktree
-- dir is named by its session id → reconstruct enough to review (diff vs HEAD)
-- or resume (steer → claude --resume <session>). Returns count reattached.
function M.reattach(repo, root)
  root = root or (vim.fn.stdpath("cache") .. "/code-agents")
  repo = repo or M.repo_top()
  if not repo then return 0 end
  pcall(function() require("code-agents.worktree").prune(repo) end) -- GC stale worktree registrations
  local dir = root .. "/" .. vim.fn.fnamemodify(repo, ":t")
  if vim.fn.isdirectory(dir) == 0 then return 0 end
  local n = 0
  for name, typ in vim.fs.dir(dir) do
    if typ == "directory" and not state.agents[name] then
      local provider, session = M.parse_worktree_name(name) -- recover the RIGHT provider
      state.agents[name] = {
        id = name, session = session, worktree = dir .. "/" .. name, repo = repo,
        verb = "command", provider = provider, status = "stopped", permit = true,
        chunks = {}, transcript = M.load_transcript(name), -- keyed by worktree name (stable)
      }
      n = n + 1
    end
  end
  M.log("reattached " .. n .. " agent(s)")
  return n
end

function M._reset()
  for id, a in pairs(state.agents) do
    if a.proc then pcall(function() a.proc:kill("sigterm") end) end
    state.agents[id] = nil
  end
  state.agents, state.seq = {}, 0
end

return M
