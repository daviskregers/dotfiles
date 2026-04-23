local M = {}

local state = {
  notes = {},
  counter = 0,
  ns_id = nil,
  opts = {},
  git_root = nil,
}

function M.setup(opts)
  state.opts = vim.tbl_deep_extend("force", {
    context_radius = 3,
    export_dir = ".reviews",
    sign_text = "RN",
  }, opts or {})
  state.notes = {}
  state.counter = 0
  state.ns_id = vim.api.nvim_create_namespace("review_notes")
  state.git_root = vim.fn.systemlist("git rev-parse --show-toplevel")[1]

  vim.api.nvim_set_hl(0, "ReviewNoteSign", { link = "DiagnosticInfo", default = true })
  vim.api.nvim_set_hl(0, "ReviewNoteVirtText", { link = "Comment", default = true })
end

local function get_context_lines(bufnr, start_line, end_line, radius)
  local total = vim.api.nvim_buf_line_count(bufnr)
  local before_start = math.max(1, start_line - radius)
  local after_end = math.min(total, end_line + radius)

  local before = vim.api.nvim_buf_get_lines(bufnr, before_start - 1, start_line - 1, false)
  local target = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)
  local after = vim.api.nvim_buf_get_lines(bufnr, end_line, after_end, false)

  return before, target, after
end

function M.add_note(params)
  if not params.start_line or params.start_line < 1 then
    vim.notify("review-notes: invalid line number", vim.log.levels.WARN)
    return nil
  end
  local radius = state.opts.context_radius or 3
  local before, target, after = get_context_lines(params.bufnr, params.start_line, params.end_line, radius)

  state.counter = state.counter + 1
  local note = {
    id = string.format("n_%d_%03d", os.time(), state.counter),
    file = params.file,
    side = params.side,
    start_line = params.start_line,
    end_line = params.end_line,
    text = params.text,
    context_before = before,
    context_line = target,
    context_after = after,
    created_at = os.time(),
  }

  table.insert(state.notes, note)
  M.persist_to_disk()
  return note
end

function M.get_notes()
  return state.notes
end

function M.delete_note(id)
  for i, note in ipairs(state.notes) do
    if note.id == id then
      table.remove(state.notes, i)
      M.persist_to_disk()
      return true
    end
  end
  return false
end

function M.edit_note(id, new_text)
  for _, note in ipairs(state.notes) do
    if note.id == id then
      note.text = new_text
      note.updated_at = os.time()
      M.persist_to_disk()
      return true
    end
  end
  return false
end

function M.get_notes_for_file(file)
  local result = {}
  for _, note in ipairs(state.notes) do
    if note.file == file then
      table.insert(result, note)
    end
  end
  return result
end

function M.get_note_at_line(file, line, side)
  for _, note in ipairs(state.notes) do
    if note.file == file and note.side == side and line >= note.start_line and line <= note.end_line then
      return note
    end
  end
  return nil
end

function M.reset_state()
  state.notes = {}
  state.counter = 0
end

function M.clear_all()
  M.reset_state()
  -- Remove session file
  local dir = state.opts.persist_dir or state.opts.export_dir
  if not dir:match("^/") then
    dir = (state.git_root or vim.fn.getcwd()) .. "/" .. dir
  end
  local path = dir .. "/.session.json"
  vim.fn.delete(path)
end

M.get_context_lines = get_context_lines

local function detect_diffview_side()
  local cur_win = vim.api.nvim_get_current_win()
  local wins = vim.api.nvim_tabpage_list_wins(0)
  local diff_wins = {}
  for _, win in ipairs(wins) do
    if vim.wo[win].diff then
      table.insert(diff_wins, win)
    end
  end
  if #diff_wins < 2 then return "file" end

  table.sort(diff_wins, function(a, b)
    return vim.api.nvim_win_get_position(a)[2] < vim.api.nvim_win_get_position(b)[2]
  end)

  return cur_win == diff_wins[1] and "old" or "new"
end

function M.resolve_buffer_context(bufnr)
  local bufname = vim.api.nvim_buf_get_name(bufnr)
  local git_root = state.git_root

  if bufname:match("diffview:///panels/") or bufname:match("/log/") then
    return nil
  end

  if not bufname:match("^diffview://") then
    if git_root and bufname:find(git_root, 1, true) == 1 then
      return { file = bufname:sub(#git_root + 2), side = "file" }
    end
    return { file = bufname, side = "file" }
  end

  local path_part = bufname:sub(#"diffview://" + 1)
  if git_root and path_part:find(git_root, 1, true) == 1 then
    path_part = path_part:sub(#git_root + 2)
  end

  local _, file
  _, file = path_part:match("^(:%d+:)/(.+)$")
  if not file then
    _, file = path_part:match("^(%x+)/(.+)$")
  end
  if not file then
    _, file = path_part:match("^(%[custom%])/(.+)$")
  end
  if not file then return nil end

  local side = detect_diffview_side()
  return { file = file, side = side }
end

local function format_markdown(notes, git_meta)
  local lines = {}
  local function add(s) table.insert(lines, s) end

  add("# Review Notes")
  add("")
  if git_meta.branch then add("- **Branch:** `" .. git_meta.branch .. "`") end
  if git_meta.ref then add("- **Ref:** `" .. git_meta.ref .. "`") end
  add("- **Date:** " .. os.date("%Y-%m-%d %H:%M:%S"))
  add("- **Total notes:** " .. #notes)
  add("")

  if git_meta.diff_stat and git_meta.diff_stat ~= "" then
    add("## Diff Stats")
    add("")
    add("```")
    add(git_meta.diff_stat)
    add("```")
    add("")
  end

  add("---")
  add("")

  local by_file = {}
  local file_order = {}
  for _, note in ipairs(notes) do
    if not by_file[note.file] then
      by_file[note.file] = {}
      table.insert(file_order, note.file)
    end
    table.insert(by_file[note.file], note)
  end
  table.sort(file_order)

  for _, file in ipairs(file_order) do
    local file_notes = by_file[file]
    table.sort(file_notes, function(a, b) return a.start_line < b.start_line end)

    add("## " .. file)
    add("")

    for _, note in ipairs(file_notes) do
      local line_label
      if note.start_line == note.end_line then
        line_label = string.format("Line %d (%s)", note.start_line, note.side)
      else
        line_label = string.format("Lines %d-%d (%s)", note.start_line, note.end_line, note.side)
      end
      add("### " .. line_label)
      add("")

      local ext = file:match("%.(%w+)$") or ""
      add("```" .. ext)
      for _, l in ipairs(note.context_before) do add(l) end
      if note.start_line == note.end_line then
        add("-- >>> LINE " .. note.start_line .. " <<<")
      else
        add("-- >>> LINES " .. note.start_line .. "-" .. note.end_line .. " <<<")
      end
      for _, l in ipairs(note.context_line) do add(l) end
      for _, l in ipairs(note.context_after) do add(l) end
      add("```")
      add("")
      add("**Comment:** " .. note.text)
      add("")
      add("---")
      add("")
    end
  end

  return table.concat(lines, "\n")
end

local function get_git_metadata()
  local branch = vim.fn.systemlist("git rev-parse --abbrev-ref HEAD")[1]
  local ref = vim.fn.systemlist("git rev-parse --short HEAD")[1]
  local diff_stat_lines = vim.fn.systemlist("git diff --stat HEAD")
  return {
    branch = branch,
    ref = ref,
    diff_stat = table.concat(diff_stat_lines, "\n"),
  }
end

function M.export(opts)
  opts = opts or {}
  if #state.notes == 0 then
    vim.notify("No review notes to export", vim.log.levels.WARN)
    return nil
  end

  local git_meta = get_git_metadata()
  local md = format_markdown(state.notes, git_meta)

  local dir = state.opts.export_dir
  if not dir:match("^/") then
    dir = (state.git_root or vim.fn.getcwd()) .. "/" .. dir
  end
  vim.fn.mkdir(dir, "p")

  local filename = os.date("%Y-%m-%d-%H%M%S") .. ".md"
  local path = dir .. "/" .. filename

  local f = io.open(path, "w")
  if not f then
    vim.notify("Failed to write: " .. path, vim.log.levels.ERROR)
    return nil
  end
  f:write(md)
  f:close()

  vim.notify(string.format("Exported %d notes to %s", #state.notes, path), vim.log.levels.INFO)

  if not opts.keep then
    state.notes = {}
    state.counter = 0
  end

  return path
end

-- Persistence

function M.persist_to_disk()
  local dir = state.opts.persist_dir or state.opts.export_dir
  if not dir:match("^/") then
    dir = (state.git_root or vim.fn.getcwd()) .. "/" .. dir
  end
  vim.fn.mkdir(dir, "p")
  local path = dir .. "/.session.json"
  local ok_enc, data = pcall(vim.json.encode, { notes = state.notes, counter = state.counter })
  if not ok_enc then
    vim.notify("review-notes: JSON encode failed: " .. tostring(data), vim.log.levels.ERROR)
    return
  end
  local f, err = io.open(path, "w")
  if not f then
    vim.notify("review-notes: persist failed: " .. tostring(err) .. " path=" .. path, vim.log.levels.ERROR)
    return
  end
  f:write(data)
  f:close()
end

function M.load_from_disk()
  local dir = state.opts.persist_dir or state.opts.export_dir
  if not dir:match("^/") then
    dir = (state.git_root or vim.fn.getcwd()) .. "/" .. dir
  end
  local path = dir .. "/.session.json"
  local f = io.open(path, "r")
  if not f then return end
  local raw = f:read("*a")
  f:close()
  local ok, data = pcall(vim.json.decode, raw)
  if ok and data then
    state.notes = data.notes or {}
    state.counter = data.counter or 0
    vim.notify(string.format("Restored %d review notes", #state.notes), vim.log.levels.INFO)
  end
end

-- Extmarks

function M.get_namespace()
  return state.ns_id
end

function M.place_extmark(bufnr, note)
  if not vim.api.nvim_buf_is_valid(bufnr) then return end
  local line_count = vim.api.nvim_buf_line_count(bufnr)
  if note.start_line > line_count then return end

  local truncated = note.text:sub(1, 50)
  if #note.text > 50 then truncated = truncated .. "..." end

  local ok, err = pcall(vim.api.nvim_buf_set_extmark, bufnr, state.ns_id, note.start_line - 1, 0, {
    sign_text = state.opts.sign_text,
    sign_hl_group = "ReviewNoteSign",
    virt_text = { { " -- " .. truncated, "ReviewNoteVirtText" } },
    virt_text_pos = "eol",
  })
  if not ok then
    vim.notify("review-notes: extmark skip — " .. tostring(err), vim.log.levels.DEBUG)
  end
end

function M.refresh_extmarks(bufnr, file, side)
  if not vim.api.nvim_buf_is_valid(bufnr) then return end
  M.clear_extmarks(bufnr)
  for _, note in ipairs(state.notes) do
    if note.file == file and (side == nil or note.side == side) then
      M.place_extmark(bufnr, note)
    end
  end
end

function M.clear_extmarks(bufnr)
  vim.api.nvim_buf_clear_namespace(bufnr, state.ns_id, 0, -1)
end

-- Cursor utilities

function M.safe_cursor(line)
  local line_count = vim.api.nvim_buf_line_count(0)
  local target = math.min(math.max(1, line), line_count)
  vim.api.nvim_win_set_cursor(0, { target, 0 })
end

-- Diffview integration

function M.is_diffview_open()
  local ok, lib = pcall(require, "diffview.lib")
  if not ok then return false end
  local view = lib.get_current_view()
  return view ~= nil
end

function M.goto_note(note)
  if M.is_diffview_open() then
    local lib = require("diffview.lib")
    local view = lib.get_current_view()
    -- Navigate diffview to show this file's diff
    view:set_file_by_path(note.file, true, true)
    -- Schedule cursor jump after diffview loads the file
    vim.schedule(function()
      local layout = view.cur_layout
      if layout then
        -- Pick the right panel based on note side
        local win
        if note.side == "old" and layout.a and layout.a:is_valid() then
          win = layout.a
        elseif layout.b and layout.b:is_valid() then
          win = layout.b
        else
          win = layout:get_main_win()
        end
        if win and win:is_valid() then
          local line_count = vim.api.nvim_buf_line_count(vim.api.nvim_win_get_buf(win.id))
          local target = math.min(math.max(1, note.start_line), line_count)
          vim.api.nvim_set_current_win(win.id)
          vim.api.nvim_win_set_cursor(win.id, { target, 0 })
        end
      end
    end)
  else
    local git_root = state.git_root or vim.fn.getcwd()
    vim.cmd("drop " .. vim.fn.fnameescape(git_root .. "/" .. note.file))
    M.safe_cursor(note.start_line)
  end
end

-- Float input window

function M.open_comment_float(opts)
  local width = math.min(70, math.floor(vim.o.columns * 0.6))
  local height = math.max(8, #opts.preview_lines + 5)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "acwrite"
  vim.bo[buf].filetype = "markdown"
  vim.b[buf].completion = false
  vim.api.nvim_buf_set_name(buf, "review-note://" .. tostring(buf))

  local lines = {}
  for _, l in ipairs(opts.preview_lines) do
    table.insert(lines, "  " .. l)
  end
  table.insert(lines, string.rep("─", width - 2))
  table.insert(lines, opts.initial_text or "")
  table.insert(lines, "")
  table.insert(lines, string.rep("─", width - 2))
  table.insert(lines, "  :w save  |  :q cancel")
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = " Review Note ",
    title_pos = "center",
  })

  local edit_start = #opts.preview_lines + 2
  vim.api.nvim_win_set_cursor(win, { edit_start, 0 })
  vim.cmd("startinsert!")

  local closed = false
  -- User text is between separator (line #preview) and bottom separator (3 lines from end)
  local text_start = #opts.preview_lines + 1 -- 0-indexed, after top separator
  local help_line_count = 3 -- empty line + bottom separator + help text

  local function confirm()
    if closed then return end
    closed = true
    local total = vim.api.nvim_buf_line_count(buf)
    local all_lines = vim.api.nvim_buf_get_lines(buf, text_start, total - help_line_count, false)
    local text = vim.trim(table.concat(all_lines, "\n"))
    if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
    if vim.api.nvim_buf_is_valid(buf) then vim.api.nvim_buf_delete(buf, { force = true }) end
    if text ~= "" and opts.on_confirm then
      opts.on_confirm(text)
    end
  end

  local function cancel()
    if closed then return end
    closed = true
    if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
    if vim.api.nvim_buf_is_valid(buf) then vim.api.nvim_buf_delete(buf, { force = true }) end
    if opts.on_cancel then opts.on_cancel() end
  end

  vim.api.nvim_create_autocmd("BufWriteCmd", {
    buffer = buf,
    callback = confirm,
  })

  -- :q closes window → trigger cancel
  vim.api.nvim_create_autocmd("WinClosed", {
    pattern = tostring(win),
    callback = cancel,
    once = true,
  })

  return buf, win
end

return M
