-- Agent registry: named CLI slots toggled in/out of nvim. Replaces
-- codecompanion / opencode.nvim / 99 / copilot. One generic primitive.
--
-- State lives in `state`. Each agent = { id, type, buf, win, job, mode }.
-- `active` = id of the currently-active slot.

local M = {}

local state = {
  agents = {},   -- map: id -> agent
  active = nil,  -- id
}

M.types = {
  claude   = { cmd = "claude" },
  haiku    = { cmd = "claude --model haiku" },
  opencode = { cmd = "opencode" },
  codex    = { cmd = "codex" },
  pi       = { cmd = "pi" },
}

-- ── project-local default agent ────────────────────────────────────────

local function project_agent_file()
  return vim.fs.find(".dk-notes", { upward = true, type = "directory" })[1]
    and vim.fs.find(".dk-notes", { upward = true, type = "directory" })[1] .. "/.agent"
end

local function read_default_agent()
  local f = project_agent_file()
  if not f then return nil end
  local ok, content = pcall(vim.fn.readfile, f)
  if ok and content[1] then return vim.trim(content[1]) end
  return nil
end

local function write_default_agent(agent_type)
  local f = project_agent_file()
  if not f then
    return vim.notify("No .dk-notes/ directory found", vim.log.levels.WARN)
  end
  local ok = pcall(vim.fn.writefile, { agent_type }, f)
  if ok then
    vim.notify("Default agent set to: " .. agent_type, vim.log.levels.INFO)
  else
    vim.notify("Failed to write " .. f, vim.log.levels.ERROR)
  end
end

local function global_agent_file()
  return vim.fn.stdpath("config") .. "/.agent"
end

local function read_global_agent()
  local f = global_agent_file()
  local ok, content = pcall(vim.fn.readfile, f)
  if ok and content[1] then return vim.trim(content[1]) end
  return nil
end

-- Exposed for testing - returns project default → global default → nil
function M.get_default_agent()
  local project = read_default_agent()
  if project then return project end
  return read_global_agent()
end

-- Pick and set project default agent via UI
function M.set_default_agent()
  local f = project_agent_file()
  if not f then
    return vim.notify("No .dk-notes/ directory found", vim.log.levels.WARN)
  end
  local types = vim.tbl_keys(M.types)
  table.sort(types)
  vim.ui.select(types, {
    prompt = "Default agent: ",
    format_item = function(t)
      local current = read_default_agent() or read_global_agent()
      if t == current then return t .. " *" end
      return t
    end,
  }, function(choice)
    if choice then write_default_agent(choice) end
  end)
end

M.verbs = {
  explain = {
    keymap = "ae",
    template = "Explain this and what it does at one abstraction below — "
            .. "complexity, cost, side effects, what the runtime/interpreter actually does:\n\n{selection}",
  },
  refactor = { keymap = "ar", template = "Refactor for clarity. Show the diff:\n\n{selection}" },
  test     = { keymap = "at", template = "Write tests for:\n\n{selection}" },
  fix      = { keymap = "af", template = "Fix any issues in:\n\n{selection}" },
  ask      = { keymap = "aq", template = "{description}\n\n{selection}", needs_description = true },
}

-- ── lookups ────────────────────────────────────────────────────────────

local function get(id)
  return state.agents[id]
end

local function active_agent()
  return state.active and state.agents[state.active] or nil
end

local function alive(a)
  return a and a.buf and vim.api.nvim_buf_is_valid(a.buf)
end

local function visible(a)
  return alive(a) and a.win and vim.api.nvim_win_is_valid(a.win)
end

-- ── windows ────────────────────────────────────────────────────────────

M.default_width = 80

local function open_window(a)
  local mode = a.mode or "split"
  if mode == "float" then
    local cols, rows = vim.o.columns, vim.o.lines
    local w, h = math.floor(cols * 0.8), math.floor(rows * 0.8)
    a.win = vim.api.nvim_open_win(a.buf, true, {
      relative = "editor",
      width    = w, height = h,
      col      = math.floor((cols - w) / 2),
      row      = math.floor((rows - h) / 2),
      style    = "minimal",
      border   = "rounded",
    })
  else
    a.win = vim.api.nvim_open_win(a.buf, true, {
      split = "right",
      win   = vim.api.nvim_get_current_win(),
      width = a.width or M.default_width,
    })
  end
end

function M.resize(delta)
  local a = active_agent()
  if not (a and a.win and vim.api.nvim_win_is_valid(a.win)) then return end
  local w = vim.api.nvim_win_get_width(a.win) + delta
  if w < 20 then w = 20 end
  vim.api.nvim_win_set_width(a.win, w)
  a.width = w
end

local function hide_window(a)
  if visible(a) then
    vim.api.nvim_win_hide(a.win)
    a.win = nil
  end
end

-- Hide every agent except `keep_id` (or all, if nil). Enforces the
-- "one agent visible at a time" UX.
local function hide_others(keep_id)
  for id, a in pairs(state.agents) do
    if id ~= keep_id then hide_window(a) end
  end
end

-- ── public: spawn / toggle / send / lifecycle ──────────────────────────

function M.spawn(type_name, label, opts)
  opts = opts or {}
  local t = M.types[type_name]
  assert(t, "unknown agent type: " .. tostring(type_name))
  assert(label and label ~= "", "label required")
  assert(not state.agents[label], "label in use: " .. label)

  hide_others(nil)  -- single-visible-at-a-time

  local a = { id = label, type = type_name, mode = opts.mode or "split" }
  a.buf = vim.api.nvim_create_buf(false, true)
  open_window(a)
  -- :term reuses the current buffer if it's empty (matches toggle-terminal.lua pattern)
  if vim.bo[a.buf].buftype ~= "terminal" then
    vim.cmd.term(t.cmd)
    a.buf = vim.api.nvim_get_current_buf()
  end
  a.job = vim.bo[a.buf].channel
  vim.b[a.buf].agent_id = label

  state.agents[label] = a
  state.active = label

  vim.api.nvim_create_autocmd("TermClose", {
    buffer = a.buf,
    once   = true,
    callback = function() M.kill(label) end,
  })
  return a
end

function M.toggle(id, mode)
  id = id or state.active
  local a = id and get(id)
  if not alive(a) then
    local default = M.get_default_agent() or "opencode"
    return M.spawn(default, default, { mode = mode or "split" })
  end
  if visible(a) then
    hide_window(a)
  else
    hide_others(a.id)
    if mode then a.mode = mode end
    open_window(a)
    vim.api.nvim_set_current_buf(a.buf)
  end
  state.active = a.id
end

function M.kill(id)
  id = id or state.active
  local a = id and get(id)
  if not a or a._killing then return end
  a._killing = true
  hide_window(a)
  if alive(a) then pcall(vim.api.nvim_buf_delete, a.buf, { force = true }) end
  state.agents[id] = nil
  if state.active == id then
    state.active = next(state.agents)
  end
end

function M.set_active(id)
  if state.agents[id] then state.active = id end
end

-- Bring `id` to the front: hide other agents, show this one, focus it.
-- Idempotent — calling on the already-active visible agent is a no-op.
function M.focus(id)
  id = id or state.active
  local a = id and get(id)
  if not alive(a) then return end
  hide_others(a.id)
  if not visible(a) then open_window(a) end
  if visible(a) then vim.api.nvim_set_current_win(a.win) end
  state.active = a.id
end

function M.rename(id, new_label)
  id = id or state.active
  local a = id and get(id)
  if not a or not new_label or new_label == "" then return end
  if state.agents[new_label] then
    return vim.notify("label in use: " .. new_label, vim.log.levels.WARN)
  end
  state.agents[id] = nil
  a.id = new_label
  state.agents[new_label] = a
  if state.active == id then state.active = new_label end
end

function M.list()
  local out = {}
  for _, a in pairs(state.agents) do table.insert(out, a) end
  table.sort(out, function(x, y) return x.id < y.id end)
  return out
end

function M.active()
  return active_agent()
end

function M.send(text)
  local a = active_agent()
  if not (a and a.job) then
    return vim.notify("no active agent", vim.log.levels.WARN)
  end
  vim.api.nvim_chan_send(a.job, text)
end

-- ── selection / message helpers (pure, testable) ───────────────────────

-- Renders a verb template given selection + filename + range + (optional)
-- user description. Pure function; test directly.
function M.format_message(template, selection, fname, sl, el, description)
  template = template or "{selection}"
  local header = string.format("%s:%d-%d", fname, sl, el)
  return (template
    :gsub("{selection}", header .. "\n" .. selection)
    :gsub("{description}", description or ""))
end

-- Reads the current visual selection. Returns selection, fname, start_line,
-- end_line. Must be called from a visual-mode keymap.
local function read_visual_selection()
  local sl, sc = vim.fn.line("v"), vim.fn.col("v")
  local el, ec = vim.fn.line("."), vim.fn.col(".")
  if sl > el or (sl == el and sc > ec) then sl, sc, el, ec = el, ec, sl, sc end
  vim.cmd("normal! \027")
  local lines = vim.api.nvim_buf_get_text(0, sl - 1, sc - 1, el - 1, ec, {})
  local fname = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":.")
  return table.concat(lines, "\n"), fname, sl, el
end

function M.send_selection(template, opts)
  opts = opts or {}
  local sel, fname, sl, el = read_visual_selection()
  local function go(description)
    M.send(M.format_message(template, sel, fname, sl, el, description))
  end
  if opts.needs_description then
    vim.ui.input({ prompt = "Description: " }, function(d)
      if d and d ~= "" then go(d) end
    end)
  else
    go("")
  end
end

-- ── statusline ─────────────────────────────────────────────────────────

function M.statusline()
  return state.active and ("[" .. state.active .. "]") or ""
end

-- ── test seam ──────────────────────────────────────────────────────────

-- Reset state. Tests use this in before_each.
function M._reset()
  for id, _ in pairs(state.agents) do M.kill(id) end
  state.agents = {}
  state.active = nil
end

return M
