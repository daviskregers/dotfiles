-- Shared LLM transport over the `llm-run` dispatcher. Owns argv building,
-- JSONL event normalization, and line-buffered streaming spawn. Used by both
-- worktree-agents (background) and code-agents (editor-anchored) so the two
-- don't diverge. Pure helpers are tested; run() is the thin process shell.

local M = {}

M.config = { llm_run = "llm-run" } -- override in tests

-- Build the `llm-run` argv. Pure. opts: provider, model, effort, agent, session,
-- resume (bool), prompt, permit (bool → route tool permissions back to nvim).
-- Empty-string optionals are omitted. llm-run translates --permit and --effort
-- per provider (claude → --effort, opencode → --variant).
function M.build_cmd(opts)
  local cmd = { M.config.llm_run, opts.provider }
  if opts.model and opts.model ~= "" then vim.list_extend(cmd, { "-m", opts.model }) end
  if opts.effort and opts.effort ~= "" then vim.list_extend(cmd, { "--effort", opts.effort }) end
  if opts.agent and opts.agent ~= "" then vim.list_extend(cmd, { "--agent", opts.agent }) end
  if opts.session and opts.session ~= "" then vim.list_extend(cmd, { "--session", opts.session }) end
  if opts.resume then table.insert(cmd, "--resume") end
  if opts.permit then table.insert(cmd, "--permit") end
  vim.list_extend(cmd, { "--", opts.prompt or "" })
  return cmd
end

-- Decode one normalized JSONL line → event table, or nil on blank/garbage/typeless.
function M.parse_event(line)
  if not line or line == "" then return nil end
  local ok, ev = pcall(vim.json.decode, line)
  if ok and type(ev) == "table" and ev.type then return ev end
  return nil
end

-- Map a normalized event onto the next status. nil = leave unchanged.
function M.status_from_event(event)
  if not event then return nil end
  local t = event.type
  if t == "text" or t == "thinking" or t == "tool" then return "running"
  elseif t == "done" then return "done"
  elseif t == "error" then return "error" end
  return nil
end

local function ensure_servername()
  if not vim.v.servername or vim.v.servername == "" then pcall(vim.fn.serverstart) end
  return vim.v.servername
end

-- Dispatch one turn. opts: provider, model, effort, agent, session, resume, prompt,
-- cwd, on_event(ev), on_exit(code, stderr). Callbacks run scheduled (main loop).
-- Returns the vim.system handle.
function M.run(opts)
  local partial, stderr = "", {}
  local cmd = M.build_cmd(opts)
  return vim.system(cmd, {
    cwd = opts.cwd,
    text = true,
    -- Merges with nvim's env (clear_env defaults false). Pin the privacy knob so
    -- headless agents send essential traffic only, independent of which settings
    -- sources claude loads.
    env = { CLANK_NVIM_ADDR = ensure_servername(), CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = "1" },
    stdout = function(_, data)
      if not data then return end
      partial = partial .. data
      while true do
        local nl = partial:find("\n")
        if not nl then break end
        local line = partial:sub(1, nl - 1)
        partial = partial:sub(nl + 1)
        local ev = M.parse_event(line)
        if ev and opts.on_event then vim.schedule(function() opts.on_event(ev) end) end
      end
    end,
    stderr = function(_, d) if d then stderr[#stderr + 1] = d end end,
  }, function(obj)
    vim.schedule(function()
      if opts.on_exit then opts.on_exit(obj.code, table.concat(stderr)) end
    end)
  end)
end

return M
