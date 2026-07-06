-- Keymaps for code-agents.
--   <leader>ae / aE  explain selection      → live conversation  (default / pick model)
--   <leader>as       ask a question (x: about selection) → cited answer in conversation
--   <leader>ac       command (write)        → background worktree agent; review on done
--   <leader>pq / pQ  search question        → quickfix           (default / pick model)
--   <leader>ar       review a finished agent's diff (accept / reject / improve)
--   <leader>ap       jump to an agent awaiting permission
--   <leader>al       open an agent's conversation (the hub) · <leader>aK  remove ALL
-- Conversation view: a add · r review · s stop · x kill · q close;
--   when awaiting permission: A allow · S session · I improve · D deny (q defers).

local core = require("code-agents.core")
local prompts = require("code-agents.prompts")
local ui = require("code-agents.ui")

-- ── selection ────────────────────────────────────────────────────────────────

-- Read the current visual selection → sel, fname, start_line, end_line, ft.
-- Must be called from a visual-mode keymap; leaves visual mode.
local function read_visual()
  local mode = vim.fn.mode()
  local sl, sc = vim.fn.line("v"), vim.fn.col("v")
  local el, ec = vim.fn.line("."), vim.fn.col(".")
  if sl > el or (sl == el and sc > ec) then sl, sc, el, ec = el, ec, sl, sc end
  local ft = vim.bo.filetype
  local fname = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":.")
  vim.cmd("normal! \27")
  local lines
  if mode == "v" then
    local last = vim.api.nvim_buf_get_lines(0, el - 1, el, false)[1] or ""
    lines = vim.api.nvim_buf_get_text(0, sl - 1, sc - 1, el - 1, math.min(ec, #last), {})
  else
    lines = vim.api.nvim_buf_get_lines(0, sl - 1, el, false)
  end
  return table.concat(lines, "\n"), fname, sl, el, ft
end

local function confirm(msg)
  return vim.fn.confirm(msg, "&Yes\n&No", 2) == 1
end

-- ── conversation view ────────────────────────────────────────────────────────

local review_agent -- forward-declared; defined below, used by the conversation's `r` key

-- Open a focused, live-updating conversation for agent `a` — the hub for all
-- per-agent ops. Renders the full transcript, refreshes as events stream (via
-- a.on_update). In-window: a add context · s stop · x kill · q close.
local function open_conversation(a)
  -- Deferred: opening/entering a float from within a ui.input/ui.select callback
  -- (snacks) races the picker teardown and silently no-ops. schedule → clean context.
  vim.schedule(function()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].filetype = "markdown"
  local w = math.floor(vim.o.columns * 0.6)
  local h = math.floor(vim.o.lines * 0.7)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor", width = w, height = h,
    row = math.floor((vim.o.lines - h) / 2), col = vim.o.columns - w - 2,
    style = "minimal", border = "rounded",
  })
  vim.wo[win].wrap = true
  vim.cmd("stopinsert") -- read-only view: ensure normal mode so q/a keymaps work

  local function refresh()
    if not vim.api.nvim_buf_is_valid(buf) then a.on_update = nil; return end
    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, core.render_transcript(a))
    vim.bo[buf].modifiable = false
    if vim.api.nvim_win_is_valid(win) then
      pcall(vim.api.nvim_win_set_config, win, { title = string.format(
        " %s [%s]  ·  a add · r review · s stop · x kill · q close ", a.id, a.status), title_pos = "center" })
      pcall(vim.api.nvim_win_set_cursor, win, { vim.api.nvim_buf_line_count(buf), 0 })
    end
  end

  local function close() if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end end
  local function ask()
    ui.prompt("Ask " .. a.id, function(text) core.steer(a.id, text) end) -- a.on_update refreshes live
  end
  local function stop() core.stop(a.id); refresh() end
  local function kill()
    if confirm("Remove " .. a.id .. "?") then core.remove(a.id); close() end
  end

  a._view_buf = buf -- exposed for integration tests to drive the in-window keymaps
  a.on_update = refresh
  a.close_view = function() a.on_update = nil; close() end
  refresh()
  vim.keymap.set("n", "q", close, { buffer = buf, nowait = true, desc = "close" })
  vim.keymap.set("n", "a", ask, { buffer = buf, nowait = true, desc = "add context" })
  vim.keymap.set("n", "<CR>", ask, { buffer = buf, nowait = true, desc = "add context" })
  vim.keymap.set("n", "s", stop, { buffer = buf, nowait = true, desc = "stop turn" })
  vim.keymap.set("n", "x", kill, { buffer = buf, nowait = true, desc = "kill agent" })
  vim.keymap.set("n", "r", function()
    if not a.worktree then return vim.notify("no changes to review for " .. a.id, vim.log.levels.INFO) end
    close(); review_agent(a)
  end, { buffer = buf, nowait = true, desc = "review changes" })

  -- Resolve a pending permission request in context (non-blocking; q just defers).
  local function decide(choice)
    return function()
      if not a.pending then return vim.notify("nothing pending for " .. a.id, vim.log.levels.INFO) end
      local entry, perm = a.pending, require("code-agents.permission")
      if choice == "improve" then
        ui.prompt("Improve " .. a.id, function(txt) perm.resolve_pending(entry, "improve", txt) end)
      else
        perm.resolve_pending(entry, choice)
      end
    end
  end
  vim.keymap.set("n", "A", decide("once"), { buffer = buf, nowait = true, desc = "allow" })
  vim.keymap.set("n", "S", decide("session"), { buffer = buf, nowait = true, desc = "allow session" })
  vim.keymap.set("n", "I", decide("improve"), { buffer = buf, nowait = true, desc = "improve" })
  vim.keymap.set("n", "D", decide("deny"), { buffer = buf, nowait = true, desc = "deny" })
  end)
end

-- ── provider/model picker (shift variants) ──────────────────────────────────

-- Fuzzy-searchable pick via telescope (opencode's model list is long); falls
-- back to vim.ui.select when telescope isn't available.
local function fuzzy_pick(items, prompt, on_choice)
  local ok, pickers = pcall(require, "telescope.pickers")
  if not ok then
    return vim.ui.select(items, { prompt = prompt }, function(c) if c then on_choice(c) end end)
  end
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  pickers.new(require("telescope.themes").get_dropdown({ layout_config = { height = 0.6 } }), {
    prompt_title = prompt,
    finder = finders.new_table({ results = items }),
    sorter = conf.generic_sorter({}),
    attach_mappings = function(bufnr)
      actions.select_default:replace(function()
        local e = action_state.get_selected_entry()
        actions.close(bufnr)
        if e then on_choice(e[1] or e.value) end
      end)
      return true
    end,
  }):find()
end

local function pick_provider_model(cb)
  local providers = vim.tbl_keys(core.config.providers)
  table.sort(providers)
  fuzzy_pick(providers, "Provider", function(provider)
    local models = core.models(provider)
    if not models or #models == 0 then return cb(provider, nil) end
    fuzzy_pick(models, "Model (" .. provider .. ")", function(model) cb(provider, model) end)
  end)
end

-- ── verbs ────────────────────────────────────────────────────────────────────

local function explain(provider, model)
  local sel, fname, sl, el = read_visual()
  if sel == "" then return vim.notify("empty selection", vim.log.levels.INFO) end
  local a = core.dispatch({ verb = "explain", provider = provider, model = model,
    prompt = prompts.explain(sel, fname, sl, el) })
  open_conversation(a)
end

-- Command / write verb: hand a task to a BACKGROUND agent working in its own
-- isolated worktree (seeded from your live state). Edits are auto-allowed there
-- (safe — isolated); Bash still prompts (<leader>ap). Review its diff on done
-- via <leader>ar — nothing merges to your tree until you accept.
local function command(context, provider, model)
  ui.prompt("Command", function(task)
    local wtm = require("code-agents.worktree")
    local repo = core.repo_top()
    local prov = provider or core.default_provider
    local sid = wtm.uuid()          -- the claude session id (resumable)
    local id = prov .. "-" .. sid   -- worktree name encodes the provider (recovered on reattach)
    local path = wtm.path(vim.fn.stdpath("cache") .. "/code-agents", vim.fn.fnamemodify(repo, ":t"), id)
    local ok, seed = wtm.create(repo, path, wtm.branch_prefix .. id)
    if not ok then return vim.notify("code-agents: worktree create failed", vim.log.levels.ERROR) end
    local a = core.dispatch({ verb = "command", provider = prov, model = model, permit = true,
      session = sid, prompt = prompts.command(task, context), cwd = path, worktree = path, seed = seed })
    a.repo = repo
    vim.notify("code-agents: " .. a.id .. " running in background — <leader>ar to review when done")
  end)
end

-- Ask: a free-form question about the repo → cited prose answer in the
-- conversation (read-only). Visual mode passes the selection as context.
local function ask(context, provider, model)
  ui.prompt("Ask", function(q)
    local a = core.dispatch({ verb = "ask", provider = provider, model = model, prompt = prompts.ask(q, context) })
    open_conversation(a)
  end)
end

local function search(provider, model)
  ui.prompt("Search", function(q)
    local a -- declared first so on_done's closure captures the local, not a nil global
    a = core.dispatch({
      verb = "search", provider = provider, model = model, prompt = prompts.search(q),
      on_done = function(text, code)
        local r = core.on_search_complete(text, code)
        if r.action == "error" then
          vim.notify("search agent error", vim.log.levels.ERROR)
        elseif r.action == "empty" then
          vim.notify("no locations found for: " .. q, vim.log.levels.INFO)
        else
          core.to_qflist(r.items, "search: " .. q)
        end
        if r.close and a.close_view then a.close_view() end -- results in qflist → drop the output window
      end,
    })
    open_conversation(a) -- live indication (thinking/grep); results land in quickfix on done
  end)
end

-- ── agent picker + panel ─────────────────────────────────────────────────────

local function pick_agent(prompt, fn)
  local agents = core.list()
  if #agents == 0 then return vim.notify("no code-agents", vim.log.levels.INFO) end
  vim.ui.select(agents, {
    prompt = prompt,
    format_item = function(a)
      return string.format("%s  [%s]  (%s/%s)", a.id, a.status, a.provider, a.model or "?")
    end,
  }, function(a) if a then fn(a) end end)
end

-- Review a finished agent's worktree diff: accept (merge to live) / reject
-- (discard) / improve (steer). On a merge conflict, the worktree is re-seeded to
-- your current state and the agent is sent back to redo — live tree untouched.
function review_agent(a)
  if not a.worktree then return vim.notify("no changes to review for " .. a.id, vim.log.levels.INFO) end
  local wtm = require("code-agents.worktree")
  local repo = a.repo or core.repo_top()
  local patch = wtm.diff(a.worktree, a.seed)
  if vim.trim(patch) == "" then
    core.remove(a.id) -- nothing to lose; cleans up the worktree
    return vim.notify("code-agents: no changes from " .. a.id)
  end
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(patch, "\n"))
  vim.bo[buf].filetype = "diff"
  vim.bo[buf].modifiable = false
  local w, h = math.floor(vim.o.columns * 0.8), math.floor(vim.o.lines * 0.8)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor", width = w, height = h,
    row = math.floor((vim.o.lines - h) / 2), col = math.floor((vim.o.columns - w) / 2),
    style = "minimal", border = "rounded",
    title = " review " .. a.id .. "   a: accept   r: reject   i: improve   q: close ", title_pos = "center",
  })
  local function close() if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end end
  vim.keymap.set("n", "q", close, { buffer = buf, nowait = true })
  vim.keymap.set("n", "a", function()
    local status = wtm.apply(repo, a.worktree, a.seed)
    close()
    if status == "applied" then
      core.remove(a.id); core.reload_changed() -- merged; remove discards the worktree
      vim.notify("code-agents: merged " .. a.id)
    else
      a.seed = wtm.reseed(repo, a.worktree) -- redo against current state
      core.steer(a.id, "Your changes no longer apply cleanly — the working tree changed since you "
        .. "started. Your worktree now holds the current versions; redo the task against them.")
      vim.notify("code-agents: " .. a.id .. " conflicted — sent back to redo; review again when done",
        vim.log.levels.WARN)
    end
  end, { buffer = buf, nowait = true })
  vim.keymap.set("n", "r", function()
    if not confirm("Reject " .. a.id .. "? This discards its worktree and changes.") then return end
    core.remove(a.id); close()
    vim.notify("code-agents: rejected " .. a.id)
  end, { buffer = buf, nowait = true })
  vim.keymap.set("n", "i", function()
    close(); ui.prompt("Improve " .. a.id, function(t) core.steer(a.id, t) end)
  end, { buffer = buf, nowait = true })
end

-- ── bindings ─────────────────────────────────────────────────────────────────

vim.keymap.set("x", "<leader>ae", function() explain() end, { desc = "code-agents: explain selection" })
vim.keymap.set("x", "<leader>aE", function()
  local sel, fname, sl, el = read_visual()
  if sel == "" then return vim.notify("empty selection", vim.log.levels.INFO) end
  pick_provider_model(function(provider, model)
    local a = core.dispatch({ verb = "explain", provider = provider, model = model,
      prompt = prompts.explain(sel, fname, sl, el) })
    open_conversation(a)
  end)
end, { desc = "code-agents: explain (pick model)" })

vim.api.nvim_create_user_command("CodeAgentsLog", function()
  vim.cmd("botright split " .. vim.fn.fnameescape(vim.fn.stdpath("cache") .. "/code-agents.log"))
  vim.bo.autoread = true
end, { desc = "Open the code-agents debug log" })

vim.keymap.set("n", "<leader>ac", function() command() end,
  { desc = "code-agents: command (write, permission-gated)" })
vim.keymap.set("x", "<leader>ac", function()
  local sel, fname, sl, el, ft = read_visual()
  local ctx = sel ~= "" and
    string.format("Context — `%s` lines %d-%d:\n```%s\n%s\n```", fname, sl, el, ft, sel) or nil
  command(ctx)
end, { desc = "code-agents: command with selection" })

-- Capital variant: pick provider (claude / opencode) + model for this command.
vim.keymap.set("n", "<leader>aC", function()
  pick_provider_model(function(provider, model) command(nil, provider, model) end)
end, { desc = "code-agents: command (pick provider/model)" })
vim.keymap.set("x", "<leader>aC", function()
  local sel, fname, sl, el, ft = read_visual()
  local ctx = sel ~= "" and
    string.format("Context — `%s` lines %d-%d:\n```%s\n%s\n```", fname, sl, el, ft, sel) or nil
  pick_provider_model(function(provider, model) command(ctx, provider, model) end)
end, { desc = "code-agents: command with selection (pick provider/model)" })

vim.keymap.set("n", "<leader>as", function() ask() end, { desc = "code-agents: ask a question" })
vim.keymap.set("x", "<leader>as", function()
  local sel, fname, sl, el, ft = read_visual()
  local ctx = sel ~= "" and
    string.format("Context — `%s` lines %d-%d:\n```%s\n%s\n```", fname, sl, el, ft, sel) or nil
  ask(ctx)
end, { desc = "code-agents: ask about selection" })

vim.keymap.set("n", "<leader>pq", function() search() end, { desc = "code-agents: search → quickfix" })
vim.keymap.set("n", "<leader>pQ", function()
  pick_provider_model(function(provider, model) search(provider, model) end)
end, { desc = "code-agents: search (pick model)" })

-- Review finished background agents' changes (accept/reject/improve their diff).
vim.keymap.set("n", "<leader>ar", function()
  local all = core.list()
  local done = vim.tbl_filter(function(a)
    return a.worktree and (a.status == "done" or a.status == "error" or a.status == "stopped")
  end, all)
  if #done == 0 then
    local running = #vim.tbl_filter(function(a) return a.status == "running" end, all)
    local awaiting = #vim.tbl_filter(function(a) return a.status == "awaiting" end, all)
    local msg = "no agents ready to review"
    if running > 0 then msg = msg .. (" — %d still running"):format(running) end
    if awaiting > 0 then msg = msg .. (" — %d awaiting permission (<leader>ap)"):format(awaiting) end
    return vim.notify(msg, vim.log.levels.INFO)
  end
  if #done == 1 then return review_agent(done[1]) end
  vim.ui.select(done, { prompt = "Review", format_item = function(a) return a.id .. " [" .. a.status .. "]" end },
    function(a) if a then review_agent(a) end end)
end, { desc = "code-agents: review agent changes" })

-- Jump to an agent awaiting permission — opens its conversation so you decide
-- in context (A/S/I/D there), or q to defer. No separate blocking prompt.
vim.keymap.set("n", "<leader>ap", function()
  local awaiting = vim.tbl_filter(function(a) return a.pending end, core.list())
  if #awaiting == 0 then return vim.notify("no pending approvals", vim.log.levels.INFO) end
  if #awaiting == 1 then return open_conversation(awaiting[1]) end
  vim.ui.select(awaiting, {
    prompt = "Awaiting permission",
    format_item = function(a) return a.id .. " — " .. a.pending.tool end,
  }, function(a) if a then open_conversation(a) end end)
end, { desc = "code-agents: open agent awaiting permission" })

-- Pick an agent → open its conversation (the hub: add/stop/kill/close inside).
vim.keymap.set("n", "<leader>al", function()
  pick_agent("code-agents", open_conversation)
end, { desc = "code-agents: open agent conversation" })

vim.keymap.set("n", "<leader>aK", function()
  local n = #core.list()
  if n == 0 then return vim.notify("no code-agents", vim.log.levels.INFO) end
  if confirm("Remove ALL " .. n .. " agent(s)?") then
    core.remove_all()
    vim.notify("removed " .. n .. " agent(s)")
  end
end, { desc = "code-agents: remove ALL" })
