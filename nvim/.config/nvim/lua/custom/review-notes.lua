local M = {}

local state = {
  notes = {},
  counter = 0,
  ns_id = nil,
  opts = {},
  git_root = nil,
  source_pr = nil,  -- set when notes loaded from a PR
}

function M.setup(opts)
  state.opts = vim.tbl_deep_extend("force", {
    context_radius = 3,
    export_dir = ".dk-notes/reviews",
    sign_text = "RN",
  }, opts or {})
  state.notes = {}
  state.counter = 0
  state.ns_id = vim.api.nvim_create_namespace("review_notes")
  state.git_root = vim.fn.systemlist("git rev-parse --show-toplevel")[1]

  vim.api.nvim_set_hl(0, "ReviewNoteSign", { link = "DiagnosticInfo", default = true })
  vim.api.nvim_set_hl(0, "ReviewNoteVirtText", { link = "Comment", default = true })
  vim.api.nvim_set_hl(0, "ReviewNoteSignHigh",   { link = "DiagnosticError", default = true })
  vim.api.nvim_set_hl(0, "ReviewNoteSignMedium", { link = "DiagnosticWarn",  default = true })
  vim.api.nvim_set_hl(0, "ReviewNoteSignLow",    { link = "DiagnosticInfo",  default = true })
  vim.api.nvim_set_hl(0, "ReviewNoteVirtTextHigh",   { link = "DiagnosticError", default = true })
  vim.api.nvim_set_hl(0, "ReviewNoteVirtTextMedium", { link = "DiagnosticWarn",  default = true })
  vim.api.nvim_set_hl(0, "ReviewNoteVirtTextLow",    { link = "DiagnosticInfo",  default = true })
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

-- ── provider registries ────────────────────────────────────────────────

M.inputs = {
  markdown = require("custom.review.inputs.markdown"),
  pr       = require("custom.review.inputs.pr"),
}

M.outputs = {
  markdown = require("custom.review.outputs.markdown"),
  pr       = require("custom.review.outputs.pr"),
  quickfix = require("custom.review.outputs.quickfix"),
  agent    = require("custom.review.outputs.agent"),
}

-- ── action registry (LSP-code-action style for a single note) ───────────

-- Format a single note for sending to an agent. Same shape as the agent
-- output uses, kept inline so actions don't have to depend on the output
-- module's internal formatter.
local function format_note_for_agent(n)
  local range = (n.start_line == n.end_line)
    and tostring(n.start_line)
    or string.format("%d-%d", n.start_line, n.end_line)
  local header = string.format("%s:%s", n.file, range)
  if n.author then header = header .. " (" .. n.author .. ")" end
  return header .. "\n" .. (n.text or "")
end

local function send_with_prefix(prefix, note)
  require("custom.agents").send(prefix .. format_note_for_agent(note))
end

local function refresh_after_change()
  local buf = vim.api.nvim_get_current_buf()
  local ctx = M.resolve_buffer_context(buf)
  if ctx then M.refresh_extmarks(buf, ctx.file, ctx.side) end
end

local function preview_lines_for(note)
  if note.context_line and #note.context_line > 0 then return note.context_line end
  return { string.format("%s:%d (%s)", note.file, note.start_line, note.kind or "note") }
end

M.actions = {
  ["/comment"]    = function(note) send_with_prefix("/comment ", note) end,
  ["/explain"]    = function(note) send_with_prefix("/explain ", note) end,
  ["send raw"]    = function(note) send_with_prefix("",          note) end,
  ["goto source"] = function(note) M.goto_note(note) end,
  ["edit"] = function(note)
    if note.kind == "original" then
      return vim.notify("Can't edit a server-side comment locally", vim.log.levels.WARN)
    end
    M.open_comment_float({
      preview_lines = preview_lines_for(note),
      initial_text = note.text,
      on_confirm = function(text)
        M.edit_note(note.id, text)
        refresh_after_change()
      end,
    })
  end,
  ["reply"] = function(note)
    -- Resolve thread root (replying to a reply still threads to the root).
    local root = note
    if note.in_reply_to_id then
      for _, n in ipairs(state.notes) do
        if n.pr_comment_id == note.in_reply_to_id then root = n; break end
      end
    end
    if root.kind ~= "original" or not root.pr_comment_id then
      return vim.notify("Reply requires a PR-loaded original comment", vim.log.levels.WARN)
    end
    M.open_comment_float({
      preview_lines = { string.format("Reply to %s:%d (@%s)",
        root.file, root.start_line, root.author or "?") },
      initial_text = "",
      on_confirm = function(text)
        if text and text ~= "" then
          M.add_reply(root, text)
          refresh_after_change()
        end
      end,
    })
  end,
  ["delete"] = function(note)
    M.delete_note(note.id)
    refresh_after_change()
  end,
  ["resolve thread"] = function(note)
    local target = note
    if note.in_reply_to_id then
      for _, n in ipairs(state.notes) do
        if n.pr_comment_id == note.in_reply_to_id then target = n; break end
      end
    end
    if not target.thread_id then
      return vim.notify("No PR thread for this note", vim.log.levels.WARN)
    end
    if target.resolved then
      return vim.notify("Thread already resolved", vim.log.levels.INFO)
    end
    local ok = require("custom.review.inputs.pr").resolve_thread(target.thread_id)
    if ok then
      -- Mark all notes in this thread as resolved locally so UI matches.
      for _, n in ipairs(state.notes) do
        if n.thread_id == target.thread_id then n.resolved = true end
      end
      M.persist_to_disk()
      refresh_after_change()
      vim.notify("Thread resolved", vim.log.levels.INFO)
    else
      vim.notify("Failed to resolve thread", vim.log.levels.ERROR)
    end
  end,
}

-- Strip a prefix that matches state.git_root (or cwd as fallback) so loaded
-- notes use the same relative path that resolve_buffer_context produces.
local function relativise_path(p)
  if not p or not p:match("^/") then return p end
  local root = state.git_root or vim.fn.getcwd()
  if root and root ~= "" and p:sub(1, #root + 1) == root .. "/" then
    return p:sub(#root + 2)
  end
  return p
end

-- Ingest notes from an input provider. Returns count loaded.
function M.load(name, arg)
  local input = M.inputs[name]
  assert(input, "unknown input provider: " .. tostring(name))
  local loaded = input.load(arg) or {}
  local kind = (name == "pr") and "original" or "loaded"
  for _, n in ipairs(loaded) do
    state.counter = state.counter + 1
    table.insert(state.notes, {
      id = string.format("n_%d_%03d", os.time(), state.counter),
      kind = kind,
      file = relativise_path(n.file),
      side = n.side or "file",
      start_line = n.start_line,
      end_line = n.end_line,
      text = n.text,
      severity = n.severity,
      context_before = {},
      context_line = {},
      context_after = {},
      pr_comment_id = n.pr_comment_id,
      in_reply_to_id = n.in_reply_to_id,
      thread_id = n.thread_id,
      resolved = n.resolved,
      author = n.author,
      created_at = os.time(),
    })
  end
  if name == "pr" then state.source_pr = arg end
  if #loaded > 0 then M.persist_to_disk() end
  return #loaded
end

function M.get_source_pr()
  return state.source_pr
end

-- Resolve the thread that contains `note`. Returns { root, replies... } where
-- replies are sorted by created_at ascending. Replies include both server-side
-- (in_reply_to_id == root.pr_comment_id) and local pending (replies_to_id ==
-- root.pr_comment_id). Standalone notes return just the note itself.
function M.get_thread(note)
  if not note then return {} end
  local root = note
  if note.in_reply_to_id then
    for _, n in ipairs(state.notes) do
      if n.pr_comment_id == note.in_reply_to_id then root = n; break end
    end
  end
  if not root.pr_comment_id then return { root } end

  local replies = {}
  for _, n in ipairs(state.notes) do
    if n ~= root and (
      n.in_reply_to_id == root.pr_comment_id or
      n.replies_to_id  == root.pr_comment_id
    ) then
      table.insert(replies, n)
    end
  end
  table.sort(replies, function(a, b) return (a.created_at or 0) < (b.created_at or 0) end)

  local out = { root }
  for _, r in ipairs(replies) do table.insert(out, r) end
  return out
end

-- Add a reply to a PR-loaded original. Reply is itself a note with the same
-- file/line as the parent and a back-pointer via replies_to_id.
function M.add_reply(parent, text)
  if not parent or parent.kind ~= "original" or not parent.pr_comment_id then
    vim.notify("Reply requires an original PR comment", vim.log.levels.WARN)
    return nil
  end
  if not text or text == "" then return nil end
  state.counter = state.counter + 1
  local note = {
    id = string.format("n_%d_%03d", os.time(), state.counter),
    kind = "reply",
    file = parent.file,
    side = parent.side or "file",
    start_line = parent.start_line,
    end_line = parent.end_line,
    text = text,
    replies_to_id = parent.pr_comment_id,
    context_before = {},
    context_line = {},
    context_after = {},
    created_at = os.time(),
  }
  table.insert(state.notes, note)
  M.persist_to_disk()
  return note
end

-- Push current notes to a named output provider. Uses live positions
-- (extmark-tracked) so edits since load are reflected. Returns the
-- provider's status. If the provider returns a `posted` map (note.id →
-- updates), apply those updates back to state.notes so subsequent pushes
-- skip already-posted notes.
function M.push(name, opts)
  local output = M.outputs[name]
  assert(output, "unknown output provider: " .. tostring(name))

  -- Clear stale push errors before retry; failures will be re-set below if
  -- they persist. (Skipped notes — kind=original / pushed — keep theirs.)
  for _, note in ipairs(state.notes) do
    if not (note.kind == "original" or note.pushed) then
      note.last_push_error = nil
    end
  end

  local res = output.push(M.notes_with_live_positions(), opts or {})
  local mutated = false
  if res and type(res.posted) == "table" then
    for _, note in ipairs(state.notes) do
      local update = res.posted[note.id]
      if update then
        for k, v in pairs(update) do note[k] = v end
        mutated = true
      end
    end
  end
  if res and type(res.failures) == "table" then
    for _, note in ipairs(state.notes) do
      local err = res.failures[note.id]
      if err then
        note.last_push_error = err
        mutated = true
      end
    end
  end
  if mutated then M.persist_to_disk() end
  return res
end

function M.get_git_root()
  return state.git_root
end

function M.get_export_dir()
  local dir = state.opts.export_dir
  if dir and not dir:match("^/") then
    dir = (state.git_root or vim.fn.getcwd()) .. "/" .. dir
  end
  return dir
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

-- All notes intersecting a line (multiple may exist on the same line —
-- e.g. a PR original and a local reply).
function M.get_notes_at_line(file, line, side)
  local out = {}
  for _, note in ipairs(state.notes) do
    if note.file == file and note.side == side and line >= note.start_line and line <= note.end_line then
      table.insert(out, note)
    end
  end
  return out
end

function M.reset_state()
  state.notes = {}
  state.counter = 0
  state.source_pr = nil
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

function M.format_markdown(notes, git_meta)
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

  local function render_note(note, file)
    local line_label
    if note.start_line == note.end_line then
      line_label = string.format("Line %d (%s)", note.start_line, note.side)
    else
      line_label = string.format("Lines %d-%d (%s)", note.start_line, note.end_line, note.side)
    end
    if note.resolved then line_label = "✓ " .. line_label end
    add("#### " .. line_label)
    add("")

    local ext = file:match("%.(%w+)$") or ""
    add("```" .. ext)
    for _, l in ipairs(note.context_before or {}) do add(l) end
    if note.start_line == note.end_line then
      add("-- >>> LINE " .. note.start_line .. " <<<")
    else
      add("-- >>> LINES " .. note.start_line .. "-" .. note.end_line .. " <<<")
    end
    for _, l in ipairs(note.context_line or {}) do add(l) end
    for _, l in ipairs(note.context_after or {}) do add(l) end
    add("```")
    add("")
    add("**Comment:** " .. (note.text or ""))
    add("")
    add("---")
    add("")
  end

  local function partition(input)
    local u, r = {}, {}
    for _, n in ipairs(input) do
      if n.resolved then table.insert(r, n) else table.insert(u, n) end
    end
    return u, r
  end

  local function render_section(subset)
    local by_file = {}
    local file_order = {}
    for _, note in ipairs(subset) do
      if type(note.start_line) == "number" and note.file then
        if not by_file[note.file] then
          by_file[note.file] = {}
          table.insert(file_order, note.file)
        end
        table.insert(by_file[note.file], note)
      end
    end
    table.sort(file_order)
    for _, file in ipairs(file_order) do
      local file_notes = by_file[file]
      table.sort(file_notes, function(a, b)
        local al, bl = a.start_line or 0, b.start_line or 0
        if al ~= bl then return al < bl end
        return (a.created_at or 0) < (b.created_at or 0)
      end)
      add("### " .. file)
      add("")
      for _, note in ipairs(file_notes) do render_note(note, file) end
    end
  end

  local unresolved, resolved = partition(notes)
  local has_both = #unresolved > 0 and #resolved > 0

  if has_both then add("## Unresolved"); add("") end
  render_section(unresolved)
  if has_both then add("## Resolved"); add("") end
  render_section(resolved)

  return table.concat(lines, "\n")
end

function M.get_git_metadata()
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

  local git_meta = M.get_git_metadata()
  local md = M.format_markdown(state.notes, git_meta)

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

  vim.fn.setreg("+", path)
  vim.notify(string.format("Exported %d notes to %s (copied to clipboard)", #state.notes, path), vim.log.levels.INFO)

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
  local ok, data = pcall(vim.json.decode, raw, { luanil = { object = true, array = true } })
  if ok and data then
    local restored = {}
    for _, n in ipairs(data.notes or {}) do
      if type(n.start_line) == "number" then table.insert(restored, n) end
    end
    state.notes = restored
    state.counter = data.counter or 0
    vim.notify(string.format("Restored %d review notes", #state.notes), vim.log.levels.INFO)
  end
end

-- Extmarks

function M.get_namespace()
  return state.ns_id
end

local SEVERITY_HL = {
  high   = { sign = "ReviewNoteSignHigh",   virt = "ReviewNoteVirtTextHigh" },
  medium = { sign = "ReviewNoteSignMedium", virt = "ReviewNoteVirtTextMedium" },
  low    = { sign = "ReviewNoteSignLow",    virt = "ReviewNoteVirtTextLow" },
}

function M.place_extmark(bufnr, note)
  if not vim.api.nvim_buf_is_valid(bufnr) then return end
  local line_count = vim.api.nvim_buf_line_count(bufnr)
  if note.start_line > line_count then return end

  -- virt_text shows only the first line (the heading); body is in :rk popup.
  local max = state.opts.virt_text_max or 120
  local first_line = note.text:match("^[^\n]*") or ""
  local truncated = first_line:sub(1, max)
  if #first_line > max then truncated = truncated .. "..." end
  if #note.text > #first_line then truncated = truncated .. " …" end
  if note.resolved then truncated = "✓ " .. truncated end

  local hl = SEVERITY_HL[note.severity] or { sign = "ReviewNoteSign", virt = "ReviewNoteVirtText" }
  local ok, id = pcall(vim.api.nvim_buf_set_extmark, bufnr, state.ns_id, note.start_line - 1, 0, {
    sign_text = state.opts.sign_text,
    sign_hl_group = hl.sign,
    virt_text = { { " -- " .. truncated, hl.virt } },
    virt_text_pos = "eol",
  })
  if not ok then
    vim.notify("review-notes: extmark skip — " .. tostring(id), vim.log.levels.DEBUG)
    return
  end
  note._extmark_buf = bufnr
  note._extmark_id = id
end

-- Open a small floating window showing the full note at cursor — including
-- replies if part of a PR thread.
function M.peek_note_at_cursor()
  local ctx = M.resolve_buffer_context(0)
  if not ctx then return vim.notify("Not a reviewable buffer", vim.log.levels.WARN) end
  local line = vim.api.nvim_win_get_cursor(0)[1]
  local note = M.get_note_at_line(ctx.file, line, ctx.side)
  if not note then return vim.notify("No note at cursor", vim.log.levels.INFO) end

  local thread = M.get_thread(note)
  local lines = {}
  local function add_note_block(n, is_reply)
    local sev = n.severity and (" [" .. n.severity .. "]") or ""
    local kind_tag = is_reply and " (reply)" or ""
    if is_reply and n.kind == "reply" then kind_tag = " (pending reply)" end
    table.insert(lines, string.format("%s:%d%s%s", n.file, n.start_line, sev, kind_tag))
    if n.author then table.insert(lines, "by @" .. n.author) end
    if n.last_push_error then
      table.insert(lines, "⚠ last push: " .. n.last_push_error)
    end
    table.insert(lines, "")
    for s in (n.text or ""):gmatch("[^\n]+") do table.insert(lines, s) end
  end

  for i, n in ipairs(thread) do
    if i > 1 then
      table.insert(lines, "")
      table.insert(lines, "─── reply " .. (i - 1) .. " ───")
      table.insert(lines, "")
    end
    add_note_block(n, i > 1)
  end

  -- Cap width so long lines wrap rather than overflow the screen.
  local width = math.min(80, math.floor(vim.o.columns * 0.7))
  -- Estimate height after wrap so the window doesn't truncate content.
  local function rows_after_wrap(line)
    if line == "" then return 1 end
    return math.max(1, math.ceil(vim.fn.strdisplaywidth(line) / width))
  end
  local height = 0
  for _, l in ipairs(lines) do height = height + rows_after_wrap(l) end
  height = math.min(height, math.floor(vim.o.lines * 0.6))

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].filetype = "markdown"

  local win = vim.api.nvim_open_win(buf, false, {
    relative = "cursor",
    row = 1, col = 0,
    width = width, height = height,
    style = "minimal", border = "rounded",
    title = " Review Note ", title_pos = "center",
  })
  vim.wo[win].wrap = true
  vim.wo[win].linebreak = true
  vim.api.nvim_create_autocmd({ "CursorMoved", "BufLeave", "InsertEnter" }, {
    once = true,
    callback = function()
      if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
    end,
  })
end

-- For each note: if its buffer is loaded AND we placed an extmark there, use
-- the extmark's current row (which tracks edits). Otherwise fall back to the
-- stored start_line. Returns deep-copied notes; original state is untouched.
function M.notes_with_live_positions()
  local out = {}
  for _, note in ipairs(state.notes) do
    local copy = vim.deepcopy(note)
    if note._extmark_buf and note._extmark_id
      and vim.api.nvim_buf_is_valid(note._extmark_buf)
    then
      local pos = vim.api.nvim_buf_get_extmark_by_id(
        note._extmark_buf, state.ns_id, note._extmark_id, {})
      if pos and pos[1] then
        copy.start_line = pos[1] + 1
        copy.end_line = pos[1] + 1 + (note.end_line - note.start_line)
      end
    end
    table.insert(out, copy)
  end
  return out
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
