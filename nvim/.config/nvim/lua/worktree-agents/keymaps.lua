-- Keymaps + pickers for background worktree agents. Implementation lives in
-- lua/custom/worktree-agents.lua. Namespace: <leader>w* (the interactive
-- agent registry owns <leader>a{n,l,R,x,s,...}; this is the background half).

local W = require("worktree-agents.core")

-- ── helpers ──────────────────────────────────────────────────────────────

local function label(a)
  return string.format("%s  [%s]  (%s%s)", a.id, a.status, a.provider,
    a.model and "/" .. a.model or "")
end

-- Fuzzy-pick one item from a list via telescope (falls back to vim.ui.select).
-- format(item) → display string; calls on_choice(item) on select.
local function pick(items, prompt, format, on_choice)
  format = format or tostring
  local ok, pickers = pcall(require, "telescope.pickers")
  if not ok then
    return vim.ui.select(items, { prompt = prompt, format_item = format },
      function(c) if c then on_choice(c) end end)
  end
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  pickers.new(require("telescope.themes").get_dropdown({}), {
    prompt_title = prompt,
    finder = finders.new_table {
      results = items,
      entry_maker = function(it)
        local d = format(it)
        return { value = it, display = d, ordinal = d }
      end,
    },
    sorter = conf.generic_sorter({}),
    attach_mappings = function(bufnr)
      actions.select_default:replace(function()
        local e = action_state.get_selected_entry()
        actions.close(bufnr)
        if e then on_choice(e.value) end
      end)
      return true
    end,
  }):find()
end

-- Pick an agent, then run fn(agent). Notifies if none.
local function with_picked_agent(prompt, fn)
  local agents = W.list()
  if #agents == 0 then return vim.notify("no background agents", vim.log.levels.INFO) end
  pick(agents, prompt, label, fn)
end

-- Open an agent's output.log read-only in a split (autoread picks up appends).
local function open_output(a)
  local log = W.output_log(a.id)
  if not log or vim.fn.filereadable(log) == 0 then
    return vim.notify("no output yet for " .. a.id, vim.log.levels.INFO)
  end
  W.focused = a.id
  vim.cmd("botright split " .. vim.fn.fnameescape(log))
  vim.bo.autoread = true
  vim.bo.readonly = true
  vim.bo.modifiable = false
end

-- Show the agent's full change set (vs base) as a unified diff in a scratch buffer.
local function open_diff(a)
  local patch = W.changes_patch(a)
  if vim.trim(patch) == "" then
    return vim.notify("no changes from " .. a.id .. " yet", vim.log.levels.INFO)
  end
  vim.cmd("botright new")
  local buf = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(patch, "\n"))
  vim.bo[buf].filetype = "diff"
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].modifiable = false
  pcall(vim.api.nvim_buf_set_name, buf, "wt-diff://" .. a.id)
end

-- ── spawn ──────────────────────────────────────────────────────────────────

-- Read the current visual selection → context block, and leave visual mode.
-- Relative path stays valid inside the agent's worktree. Returns nil if empty.
local function selection_context()
  local mode = vim.fn.mode()                       -- "v" charwise, "V" linewise, <C-v> block
  local sl, sc = vim.fn.line("v"), vim.fn.col("v")
  local el, ec = vim.fn.line("."), vim.fn.col(".")
  if sl > el or (sl == el and sc > ec) then sl, sc, el, ec = el, ec, sl, sc end
  local ft = vim.bo.filetype
  local fname = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":.")
  vim.cmd("normal! \27")                            -- exit visual mode
  local lines
  if mode == "v" then                               -- charwise: precise cols (inclusive end)
    local last = vim.api.nvim_buf_get_lines(0, el - 1, el, false)[1] or ""
    lines = vim.api.nvim_buf_get_text(0, sl - 1, sc - 1, el - 1, math.min(ec, #last), {})
  else                                              -- linewise / blockwise: whole lines
    lines = vim.api.nvim_buf_get_lines(0, sl - 1, el, false)
  end
  local sel = table.concat(lines, "\n")
  if sel == "" then return nil end
  return string.format("\n\nContext — `%s` lines %d-%d:\n```%s\n%s\n```", fname, sl, el, ft, sel)
end

local function spawn(opts, context)
  vim.ui.input({ prompt = "Agent task: " }, function(task)
    if task and task ~= "" then W.spawn(context and (task .. context) or task, opts) end
  end)
end

-- Pick provider → model (telescope), then spawn (optionally with selection context).
local function spawn_pick(context)
  local providers = vim.tbl_keys(W.config.providers)
  table.sort(providers)
  pick(providers, "Provider", nil, function(provider)
    local models = W.list_models(provider)
    if #models == 0 then return spawn({ provider = provider }, context) end
    pick(models, "Model (" .. provider .. ")", nil, function(model)
      spawn({ provider = provider, model = model }, context)
    end)
  end)
end

-- <leader>w is a pure prefix (group) — spawn lives on wa so which-key shows.
vim.keymap.set("n", "<leader>wa", function() spawn({}) end,
  { desc = "Worktree agent: new (default provider)" })
vim.keymap.set("x", "<leader>wa", function() spawn({}, selection_context()) end,
  { desc = "Worktree agent: new with selection as context" })

-- Capital variant: choose provider + model for this one spawn.
vim.keymap.set("n", "<leader>wA", function() spawn_pick(nil) end,
  { desc = "Worktree agent: spawn (pick provider/model)" })
vim.keymap.set("x", "<leader>wA", function() spawn_pick(selection_context()) end,
  { desc = "Worktree agent: spawn with selection (pick provider/model)" })

-- ── list (telescope control panel) ──────────────────────────────────────────

vim.keymap.set("n", "<leader>wl", function()
  local agents = W.list()
  if #agents == 0 then return vim.notify("no background agents", vim.log.levels.INFO) end
  local ok_t, pickers = pcall(require, "telescope.pickers")
  if not ok_t then  -- fallback to ui.select
    return with_picked_agent("Agent", open_output)
  end
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  local previewers = require("telescope.previewers")

  local function selected() return action_state.get_selected_entry().value end
  local function make_finder()
    return finders.new_table {
      results = W.list(),
      entry_maker = function(a) return { value = a, display = label(a), ordinal = a.id } end,
    }
  end

  pickers.new(require("telescope.themes").get_ivy({}), {
    prompt_title = "Agents — CR output · C-d diff · C-g apply(pull) · C-x discard · C-e send · C-r sync · C-k stop",
    finder = make_finder(),
    sorter = conf.generic_sorter({}),
    previewer = previewers.new_buffer_previewer({
      define_preview = function(self, entry)
        local log = W.output_log(entry.value.id)
        local lines = (log and vim.fn.filereadable(log) == 1) and vim.fn.readfile(log) or { "(no output)" }
        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
      end,
    }),
    attach_mappings = function(bufnr, map)
      -- act: close picker then run fn (for actions that open another UI).
      local function act(fn)
        return function() local a = selected(); actions.close(bufnr); fn(a) end
      end
      -- act_refresh: mutate then refresh the list in place (stay in the picker).
      local function act_refresh(fn)
        return function()
          local a = selected()
          fn(a)
          local picker = action_state.get_current_picker(bufnr)
          if picker then picker:refresh(make_finder(), { reset_prompt = false }) end
        end
      end
      local function chat_to(a) require("worktree-agents.chat").compose(a, function(t) W.send(a.id, t) end) end

      actions.select_default:replace(act(open_output))     -- <CR> = output
      -- Ctrl actions work in BOTH insert and normal mode (no <Esc> needed).
      -- NB: never map <C-m> — it is byte-identical to <CR> and would hijack select.
      map({ "i", "n" }, "<C-d>", act(open_diff))
      map({ "i", "n" }, "<C-e>", act(chat_to))
      map({ "i", "n" }, "<C-g>", act(function(a) W.apply(a.id) end))
      map({ "i", "n" }, "<C-r>", act_refresh(function(a) W.sync(a.id) end))
      map({ "i", "n" }, "<C-k>", act_refresh(function(a) W.stop(a.id) end))
      map({ "i", "n" }, "<C-x>", act_refresh(function(a)
        if vim.fn.confirm("Discard " .. a.id .. "? Removes its worktree + branch.", "&Yes\n&No", 2) == 1 then
          W.discard(a.id)
        end
      end))
      return true
    end,
  }):find()
end, { desc = "Worktree agents: list/control" })

-- ── per-agent actions (ui.select) ───────────────────────────────────────────

vim.keymap.set("n", "<leader>wo", function() with_picked_agent("Output", open_output) end,
  { desc = "Worktree agent: output" })
vim.keymap.set("n", "<leader>wd", function() with_picked_agent("Diff", open_diff) end,
  { desc = "Worktree agent: diff" })
vim.keymap.set("n", "<leader>wp", function() with_picked_agent("Pull in", function(a) W.apply(a.id) end) end,
  { desc = "Worktree agent: apply (pull into working tree)" })
vim.keymap.set("n", "<leader>wx", function()
  with_picked_agent("Discard", function(a)
    if vim.fn.confirm("Discard " .. a.id .. "? Removes its worktree + branch.", "&Yes\n&No", 2) == 1 then
      W.discard(a.id)
    end
  end)
end, { desc = "Worktree agent: discard" })
vim.keymap.set("n", "<leader>wu", function() with_picked_agent("Sync", function(a) W.sync(a.id) end) end,
  { desc = "Worktree agent: sync from base" })
vim.keymap.set("n", "<leader>wS", function() with_picked_agent("Stop", function(a) W.stop(a.id) end) end,
  { desc = "Worktree agent: stop" })

vim.keymap.set("n", "<leader>ws", function()
  with_picked_agent("Send to", function(a)
    require("worktree-agents.chat").compose(a, function(text) W.send(a.id, text) end)
  end)
end, { desc = "Worktree agent: send/steer" })

-- ── commands ─────────────────────────────────────────────────────────────────

vim.api.nvim_create_user_command("ClankLog", function()
  local ok, W2 = pcall(require, "worktree-agents.core")
  local path = ok and (W2.root() .. "/" .. (W2.repo_key() or "unknown") .. "/clank.log")
  if not path or vim.fn.filereadable(path) == 0 then
    return vim.notify("no clank.log yet", vim.log.levels.INFO)
  end
  vim.cmd("botright split " .. vim.fn.fnameescape(path))
  vim.bo.autoread = true
end, { desc = "Open the worktree-agents diagnostic log" })

-- ── reattach on startup ──────────────────────────────────────────────────────

vim.schedule(function()
  if W.repo_toplevel() then pcall(W.reattach) end
end)
