-- Keymaps for code-agents.
--   <leader>ae / aE  explain selection      → live conversation  (default / pick model)
--   <leader>af       set session focus (prepended to every new agent's opening prompt)
--   <leader>as       ask a question (x: about selection) → cited answer in conversation
--   <leader>ac       command (write)        → background worktree agent; review on done
--   <leader>pq / pQ  search question        → quickfix           (default / pick model)
--   <leader>ar       review a finished agent's diff (accept / reject / improve)
--   <leader>ap / aP  run a prompt — pick a verb (x: with selection)  (default / pick provider/model)
--   <leader>aw       jump to an agent awaiting permission
--   <leader>al       open an agent's conversation (the hub) · <leader>aK  remove ALL
-- Conversation view: a add · r review · s stop · x kill · q close;
--   when awaiting permission: A allow once · S allow session · W always (edit
--   rule, persisted) · D deny (q defers). Requests are logged → :CodeAgentsPermissions.

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

-- Shared conversation view: one window, one buffer. All agents render here.
local shared = { buf = nil, win = nil, agent = nil, keymaps_set = false }

local function refresh_shared()
  if not shared.agent then return end
  if not shared.buf or not vim.api.nvim_buf_is_valid(shared.buf) then return end
  vim.bo[shared.buf].modifiable = true
  local lines, highlights = core.render_transcript(shared.agent)
  vim.api.nvim_buf_set_lines(shared.buf, 0, -1, false, lines)
  core.apply_transcript_highlights(shared.buf, highlights)
  vim.bo[shared.buf].modifiable = false
  if shared.win and vim.api.nvim_win_is_valid(shared.win) then
    pcall(vim.api.nvim_win_set_config, shared.win, { title = string.format(
      " %s [%s]  ·  a add · r review · s stop · x kill · q close ", shared.agent.id, shared.agent.status), title_pos = "center" })
    pcall(vim.api.nvim_win_set_cursor, shared.win, { vim.api.nvim_buf_line_count(shared.buf), 0 })
  end
end

local function close_shared()
  if shared.win and vim.api.nvim_win_is_valid(shared.win) then
    vim.api.nvim_win_close(shared.win, true)
  end
  shared.win, shared.agent = nil, nil
end

local function ensure_shared_window()
  core.setup_highlights()
  if not shared.buf or not vim.api.nvim_buf_is_valid(shared.buf) then
    shared.buf = vim.api.nvim_create_buf(false, true)
    vim.bo[shared.buf].filetype = "markdown"
  end
  if not shared.win or not vim.api.nvim_win_is_valid(shared.win) then
    local w = math.floor(vim.o.columns * 0.6)
    local h = math.floor(vim.o.lines * 0.7)
    shared.win = vim.api.nvim_open_win(shared.buf, true, {
      relative = "editor", width = w, height = h,
      row = math.floor((vim.o.lines - h) / 2), col = vim.o.columns - w - 2,
      style = "minimal", border = "rounded",
    })
    vim.wo[shared.win].wrap = true
    vim.cmd("stopinsert")
  else
    vim.api.nvim_set_current_win(shared.win)
  end
  return shared.buf, shared.win
end

local function setup_shared_keymaps()
  if shared.keymaps_set then return end
  if not shared.buf then return end
  local buf = shared.buf

  local function current()
    if not shared.agent then return nil end
    -- agent may have been removed; verify it still exists
    if not core.get(shared.agent.id) then shared.agent = nil; return nil end
    return shared.agent
  end

  local function ask()
    local a = current()
    if not a then return end
    ui.prompt("Ask " .. a.id, function(text) core.steer(a.id, text) end)
  end

  local function stop()
    local a = current()
    if not a then return end
    core.stop(a.id)
    refresh_shared()
  end

  local function kill()
    local a = current()
    if not a then return end
    if not confirm("Remove " .. a.id .. "?") then return end
    core.remove(a.id)
    shared.agent = nil
    local agents = core.list()
    if #agents > 0 then
      shared.agent = agents[1]
      shared.agent.on_update = refresh_shared
      refresh_shared()
    else
      close_shared()
    end
  end

  local function review()
    local a = current()
    if not a then return end
    if not a.worktree then return vim.notify("no changes to review for " .. a.id, vim.log.levels.INFO) end
    close_shared()
    review_agent(a)
  end

  local function decide(choice)
    return function()
      local a = current()
      if not a or not a.pending then return vim.notify("nothing pending", vim.log.levels.INFO) end
      local entry, perm = a.pending, require("code-agents.permission")
      if choice == "always" then
        ui.prompt("Whitelist rule for " .. a.id, function(rule) perm.resolve_pending(entry, "always", rule) end,
          { prefill = perm.suggest_rule(entry.tool, entry.input) })
      else
        perm.resolve_pending(entry, choice)
      end
    end
  end

  vim.keymap.set("n", "q", close_shared, { buffer = buf, nowait = true, desc = "close" })
  vim.keymap.set("n", "a", ask, { buffer = buf, nowait = true, desc = "add context" })
  vim.keymap.set("n", "<CR>", ask, { buffer = buf, nowait = true, desc = "add context" })
  vim.keymap.set("n", "s", stop, { buffer = buf, nowait = true, desc = "stop turn" })
  vim.keymap.set("n", "x", kill, { buffer = buf, nowait = true, desc = "kill agent" })
  vim.keymap.set("n", "r", review, { buffer = buf, nowait = true, desc = "review changes" })
  vim.keymap.set("n", "A", decide("once"), { buffer = buf, nowait = true, desc = "allow once" })
  vim.keymap.set("n", "S", decide("session"), { buffer = buf, nowait = true, desc = "allow session" })
  vim.keymap.set("n", "W", decide("always"), { buffer = buf, nowait = true, desc = "always allow (edit rule)" })
  vim.keymap.set("n", "D", decide("deny"), { buffer = buf, nowait = true, desc = "deny" })
  shared.keymaps_set = true
end

-- Open a focused, live-updating conversation for agent `a` in the shared window.
local function open_conversation(a)
  vim.schedule(function()
    ensure_shared_window()
    setup_shared_keymaps()
    shared.agent = a
    a._view_buf = shared.buf
    a.on_update = refresh_shared
    a.close_view = close_shared
    refresh_shared()
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
-- (safe — isolated); Bash still prompts (<leader>aw). Review its diff on done
-- via <leader>ar — nothing merges to your tree until you accept.
local function command(context, provider, model)
  ui.prompt("Command", function(task)
    local wtm = require("code-agents.worktree")
    local repo = core.repo_top()
    local prov = provider or core.current_default_provider()
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

-- Pick an agent → fn(agent). Telescope shows each agent's live transcript in the
-- preview pane (via core.render_transcript); falls back to vim.ui.select without.
local function pick_agent(prompt, fn)
  local agents = core.list()
  if #agents == 0 then return vim.notify("no code-agents", vim.log.levels.INFO) end
  local ok, pickers = pcall(require, "telescope.pickers")
  if not ok then
    return vim.ui.select(agents, { prompt = prompt, format_item = core.agent_label },
      function(a) if a then fn(a) end end)
  end
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  local previewers = require("telescope.previewers")
  pickers.new({}, {
    prompt_title = prompt,
    finder = finders.new_table({
      results = agents,
      entry_maker = function(a)
        local title = (a.raw_prompt or ""):gsub("%s+", " ")
        return { value = a, display = core.agent_label(a), ordinal = (a.id .. " " .. title):lower() }
      end,
    }),
    sorter = conf.generic_sorter({}),
    previewer = previewers.new_buffer_previewer({
      title = "transcript",
      define_preview = function(self, entry)
        local lines = core.render_transcript(entry.value)
        vim.bo[self.state.bufnr].filetype = "markdown"
        vim.wo[self.state.winid].wrap = true
        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
      end,
    }),
    attach_mappings = function(bufnr)
      actions.select_default:replace(function()
        local e = action_state.get_selected_entry()
        actions.close(bufnr)
        if e then fn(e.value) end
      end)
      return true
    end,
  }):find()
end

-- Review a finished agent's worktree diff: accept (merge to live) / reject
-- (discard) / improve (steer). On a merge conflict, the worktree is re-seeded to
-- your current state and the agent is sent back to redo — live tree untouched.
function review_agent(a)
  if not a.worktree then return vim.notify("no changes to review for " .. a.id, vim.log.levels.INFO) end
  local wtm = require("code-agents.worktree")
  local repo = a.repo or core.repo_top()
  local patch, ok = wtm.diff(a.worktree, a.seed)
  if not ok then
    -- Diff FAILED (e.g. seed unresolvable) — the changes are still in the worktree.
    -- Never discard: that's how progress got lost. Keep it and point the user at it.
    return vim.notify("code-agents: couldn't diff " .. a.id .. " (seed unresolvable) — worktree kept at "
      .. a.worktree .. "; inspect it manually before discarding", vim.log.levels.ERROR)
  end
  if vim.trim(patch) == "" then
    -- Genuinely empty — but still confirm before discarding, so a surprise "nothing
    -- here" never nukes work the user believes they made.
    if confirm("No changes detected from " .. a.id .. ". Discard its worktree and branch?") then
      core.remove(a.id)
      return vim.notify("code-agents: discarded " .. a.id .. " (no changes)")
    end
    return vim.notify("code-agents: kept " .. a.id .. " — worktree at " .. a.worktree)
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
    elseif status == "error" then
      -- Diff FAILED (e.g. seed unresolvable) — work is still in the worktree. Never
      -- discard or reseed (reseed would clobber it): keep it and point the user at it.
      vim.notify("code-agents: couldn't diff " .. a.id .. " (seed unresolvable) — worktree kept at "
        .. a.worktree .. "; inspect it manually before discarding", vim.log.levels.ERROR)
    else -- "conflict"
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

-- ── session focus ─────────────────────────────────────────────────────────────

-- Session-focus editor: the same shared float as every other input, prefilled
-- with the current focus. allow_empty makes an empty commit meaningful here — it
-- clears the focus (core.set_focus treats empty/whitespace as clear).
local function edit_focus()
  ui.prompt("Session focus", function(text)
    core.set_focus(text)
    vim.notify(core.get_focus() and "code-agents: focus set" or "code-agents: focus cleared")
  end, { prefill = core.get_focus() or "", allow_empty = true })
end

-- ── prompt picker ─────────────────────────────────────────────────────────────

-- Launcher: pick one of the plugin's verbs to run. Lists the current verbs for
-- now; grows to custom saved prompts later. Visual mode captures the selection
-- up-front (the picker leaves visual mode) and passes it as context.
-- provider/model (optional) are threaded into the chosen verb — the capital
-- <leader>aP variant picks them up-front, mirroring <leader>ac / <leader>aC.
local function pick_prompt(sel, fname, sl, el, ft, provider, model)
  local has_sel = sel ~= nil and sel ~= ""
  local ctx = has_sel and
    string.format("Context — `%s` lines %d-%d:\n```%s\n%s\n```", fname, sl, el, ft, sel) or nil
  local verbs = {
    { name = "ask", run = function() ask(ctx, provider, model) end },
    { name = "command", run = function() command(ctx, provider, model) end },
    { name = "search", run = function() search(provider, model) end },
    { name = "explain", run = function()
      if not has_sel then return vim.notify("explain needs a selection", vim.log.levels.INFO) end
      open_conversation(core.dispatch({ verb = "explain", provider = provider, model = model,
        prompt = prompts.explain(sel, fname, sl, el) }))
    end },
  }
  vim.ui.select(verbs, { prompt = "Run prompt", format_item = function(v) return v.name end },
    function(v) if v then v.run() end end)
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

-- Open the permission audit log — every request + decision, so you can see what
-- agents ran and grow the whitelist (W in the conversation persists a rule).
vim.api.nvim_create_user_command("CodeAgentsPermissions", function()
  vim.cmd("botright split " .. vim.fn.fnameescape(require("code-agents.permission").perm_log_path()))
  vim.bo.autoread = true
  vim.bo.filetype = "json"
end, { desc = "Open the code-agents permission log" })

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

vim.keymap.set("n", "<leader>af", edit_focus, { desc = "code-agents: set session focus" })

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
    if awaiting > 0 then msg = msg .. (" — %d awaiting permission (<leader>aw)"):format(awaiting) end
    return vim.notify(msg, vim.log.levels.INFO)
  end
  if #done == 1 then return review_agent(done[1]) end
  vim.ui.select(done, { prompt = "Review", format_item = function(a) return a.id .. " [" .. a.status .. "]" end },
    function(a) if a then review_agent(a) end end)
end, { desc = "code-agents: review agent changes" })

-- Run a prompt: pick a verb (explain/ask/command/search) from a select window.
vim.keymap.set("n", "<leader>ap", function() pick_prompt() end,
  { desc = "code-agents: run a prompt (verb picker)" })
vim.keymap.set("x", "<leader>ap", function() pick_prompt(read_visual()) end,
  { desc = "code-agents: run a prompt with selection" })

-- Capital variant: pick provider (claude / opencode) + model for the verb.
vim.keymap.set("n", "<leader>aP", function()
  pick_provider_model(function(provider, model)
    pick_prompt(nil, nil, nil, nil, nil, provider, model)
  end)
end, { desc = "code-agents: run a prompt (pick provider/model)" })
vim.keymap.set("x", "<leader>aP", function()
  local sel, fname, sl, el, ft = read_visual() -- capture before the picker leaves visual mode
  pick_provider_model(function(provider, model)
    pick_prompt(sel, fname, sl, el, ft, provider, model)
  end)
end, { desc = "code-agents: run a prompt with selection (pick provider/model)" })

-- Jump to an agent awaiting permission — opens its conversation so you decide
-- in context (A/S/I/D there), or q to defer. No separate blocking prompt.
vim.keymap.set("n", "<leader>aw", function()
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

-- ── agent window navigation (]a / [a) ─────────────────────────────────────

local function focused_agent_index(agents)
  if not shared.agent then return nil end
  for i, a in ipairs(agents) do
    if a.id == shared.agent.id then return i end
  end
  return nil
end

vim.keymap.set("n", "]a", function()
  local agents = core.list()
  if #agents == 0 then return vim.notify("no code-agents", vim.log.levels.INFO) end
  local idx = focused_agent_index(agents)
  open_conversation(agents[(idx and idx < #agents) and (idx + 1) or 1])
end, { desc = "code-agents: next agent" })

vim.keymap.set("n", "[a", function()
  local agents = core.list()
  if #agents == 0 then return vim.notify("no code-agents", vim.log.levels.INFO) end
  local idx = focused_agent_index(agents)
  open_conversation(agents[(idx and idx > 1) and (idx - 1) or #agents])
end, { desc = "code-agents: prev agent" })
