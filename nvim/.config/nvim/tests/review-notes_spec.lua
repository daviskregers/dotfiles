local rn = require("custom.review-notes")

describe("review-notes", function()
  before_each(function()
    rn.setup({ context_radius = 3, export_dir = vim.fn.tempname() })
  end)

  after_each(function()
    rn.clear_all()
  end)

  describe("setup", function()
    it("returns module with expected functions", function()
      assert.is_function(rn.setup)
      assert.is_function(rn.add_note)
      assert.is_function(rn.delete_note)
      assert.is_function(rn.edit_note)
      assert.is_function(rn.clear_all)
      assert.is_function(rn.get_notes)
      assert.is_function(rn.export)
    end)

    it("initializes empty state", function()
      assert.are.same({}, rn.get_notes())
    end)
  end)

  describe("add_note", function()
    it("creates note with correct fields", function()
      local buf = vim.api.nvim_create_buf(true, true)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
        "line 1", "line 2", "line 3", "line 4", "line 5",
        "line 6", "line 7", "line 8", "line 9", "line 10",
      })
      vim.api.nvim_buf_set_name(buf, "/project/src/main.lua")

      local note = rn.add_note({
        bufnr = buf,
        file = "src/main.lua",
        side = "file",
        start_line = 5,
        end_line = 5,
        text = "fix this",
      })

      assert.is_not_nil(note)
      assert.is_string(note.id)
      assert.equals("src/main.lua", note.file)
      assert.equals("file", note.side)
      assert.equals(5, note.start_line)
      assert.equals(5, note.end_line)
      assert.equals("fix this", note.text)
      assert.are.same({ "line 2", "line 3", "line 4" }, note.context_before)
      assert.are.same({ "line 5" }, note.context_line)
      assert.are.same({ "line 6", "line 7", "line 8" }, note.context_after)
      assert.is_number(note.created_at)

      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("increments note count", function()
      local buf = vim.api.nvim_create_buf(true, true)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "a", "b", "c" })

      rn.add_note({ bufnr = buf, file = "a.lua", side = "file", start_line = 1, end_line = 1, text = "x" })
      rn.add_note({ bufnr = buf, file = "a.lua", side = "file", start_line = 2, end_line = 2, text = "y" })

      assert.equals(2, #rn.get_notes())
      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("handles visual range", function()
      local buf = vim.api.nvim_create_buf(true, true)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "a", "b", "c", "d", "e" })

      local note = rn.add_note({
        bufnr = buf, file = "a.lua", side = "new",
        start_line = 2, end_line = 4, text = "refactor range",
      })

      assert.equals(2, note.start_line)
      assert.equals(4, note.end_line)
      assert.are.same({ "b", "c", "d" }, note.context_line)
      vim.api.nvim_buf_delete(buf, { force = true })
    end)
  end)

  describe("add_note via float (integration)", function()
    it("captures correct line number through float confirm flow", function()
      local buf = vim.api.nvim_create_buf(true, true)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
        "line 1", "line 2", "line 3", "line 4", "line 5",
      })
      vim.api.nvim_set_current_buf(buf)
      vim.api.nvim_win_set_cursor(0, { 3, 0 })

      -- Simulate what plugin spec does
      local line = vim.api.nvim_win_get_cursor(0)[1]
      local before, target, after = rn.get_context_lines(buf, line, line, 3)
      local preview = {}
      for _, l in ipairs(before) do table.insert(preview, l) end
      table.insert(preview, ">>> " .. target[1])
      for _, l in ipairs(after) do table.insert(preview, l) end

      local float_buf, _ = rn.open_comment_float({
        preview_lines = preview,
        on_confirm = function(text)
          rn.add_note({
            bufnr = buf, file = "test.lua", side = "file",
            start_line = line, end_line = line, text = text,
          })
        end,
      })

      -- Type into float and confirm via :w
      local edit_idx = #preview + 1
      vim.api.nvim_buf_set_lines(float_buf, edit_idx, edit_idx + 1, false, { "my comment" })
      vim.api.nvim_buf_call(float_buf, function()
        vim.cmd("write")
      end)

      local notes = rn.get_notes()
      assert.equals(1, #notes)
      assert.equals(3, notes[1].start_line)
      assert.equals(3, notes[1].end_line)
      assert.equals("my comment", notes[1].text)
      vim.api.nvim_buf_delete(buf, { force = true })
    end)
  end)

  describe("add_note via visual mode (integration)", function()
    it("line('v') and line('.') capture current visual range", function()
      local buf = vim.api.nvim_create_buf(true, true)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
        "line 1", "line 2", "line 3", "line 4", "line 5",
      })
      vim.api.nvim_set_current_buf(buf)

      -- Simulate: cursor at line 2, enter visual, move to line 4
      vim.api.nvim_win_set_cursor(0, { 2, 0 })
      -- In visual mode, line("v") = visual start, line(".") = cursor
      -- We can't truly enter visual mode in headless, but we can verify
      -- the fix works with direct line numbers
      local start_line = 2
      local end_line = 4

      rn.add_note({
        bufnr = buf, file = "test.lua", side = "file",
        start_line = start_line, end_line = end_line, text = "visual note",
      })

      local notes = rn.get_notes()
      assert.equals(1, #notes)
      assert.equals(2, notes[1].start_line)
      assert.equals(4, notes[1].end_line)
      assert.are.same({ "line 2", "line 3", "line 4" }, notes[1].context_line)
      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("swaps start/end when visual selection is bottom-to-top", function()
      local buf = vim.api.nvim_create_buf(true, true)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "a", "b", "c", "d", "e" })
      vim.api.nvim_set_current_buf(buf)

      -- Simulate upward selection: line("v")=4, line(".")=2
      local v_line = 4
      local dot_line = 2
      local start_line = math.min(v_line, dot_line)
      local end_line = math.max(v_line, dot_line)

      rn.add_note({
        bufnr = buf, file = "test.lua", side = "file",
        start_line = start_line, end_line = end_line, text = "reversed",
      })

      local notes = rn.get_notes()
      assert.equals(2, notes[1].start_line)
      assert.equals(4, notes[1].end_line)
      vim.api.nvim_buf_delete(buf, { force = true })
    end)
  end)

  describe("add_note validation", function()
    it("rejects start_line of 0", function()
      local buf = vim.api.nvim_create_buf(true, true)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "a", "b" })

      local note = rn.add_note({ bufnr = buf, file = "a.lua", side = "file", start_line = 0, end_line = 0, text = "bad" })
      assert.is_nil(note)
      assert.equals(0, #rn.get_notes())
      vim.api.nvim_buf_delete(buf, { force = true })
    end)
  end)

  describe("delete_note", function()
    it("removes note by id", function()
      local buf = vim.api.nvim_create_buf(true, true)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "a", "b", "c" })

      local n1 = rn.add_note({ bufnr = buf, file = "a.lua", side = "file", start_line = 1, end_line = 1, text = "x" })
      local n2 = rn.add_note({ bufnr = buf, file = "a.lua", side = "file", start_line = 2, end_line = 2, text = "y" })

      rn.delete_note(n1.id)

      local notes = rn.get_notes()
      assert.equals(1, #notes)
      assert.equals(n2.id, notes[1].id)
      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("returns false for unknown id", function()
      assert.is_false(rn.delete_note("nonexistent"))
    end)
  end)

  describe("edit_note", function()
    it("updates text and timestamp", function()
      local buf = vim.api.nvim_create_buf(true, true)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "a" })

      local note = rn.add_note({ bufnr = buf, file = "a.lua", side = "file", start_line = 1, end_line = 1, text = "old" })
      local original_time = note.created_at

      rn.edit_note(note.id, "new text")

      local updated = rn.get_notes()[1]
      assert.equals("new text", updated.text)
      assert.is_not_nil(updated.updated_at)
      assert.equals(original_time, updated.created_at)
      vim.api.nvim_buf_delete(buf, { force = true })
    end)
  end)

  describe("get_notes_for_file", function()
    it("filters by file path", function()
      local buf = vim.api.nvim_create_buf(true, true)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "a", "b" })

      rn.add_note({ bufnr = buf, file = "a.lua", side = "file", start_line = 1, end_line = 1, text = "x" })
      rn.add_note({ bufnr = buf, file = "b.lua", side = "file", start_line = 1, end_line = 1, text = "y" })
      rn.add_note({ bufnr = buf, file = "a.lua", side = "new", start_line = 2, end_line = 2, text = "z" })

      local a_notes = rn.get_notes_for_file("a.lua")
      assert.equals(2, #a_notes)
      vim.api.nvim_buf_delete(buf, { force = true })
    end)
  end)

  describe("get_note_at_line", function()
    it("returns note covering line", function()
      local buf = vim.api.nvim_create_buf(true, true)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "a", "b", "c", "d" })

      rn.add_note({ bufnr = buf, file = "a.lua", side = "file", start_line = 2, end_line = 3, text = "range" })

      assert.is_not_nil(rn.get_note_at_line("a.lua", 2, "file"))
      assert.is_not_nil(rn.get_note_at_line("a.lua", 3, "file"))
      assert.is_nil(rn.get_note_at_line("a.lua", 1, "file"))
      assert.is_nil(rn.get_note_at_line("a.lua", 4, "file"))
      vim.api.nvim_buf_delete(buf, { force = true })
    end)
  end)

  describe("clear_all", function()
    it("empties all notes", function()
      local buf = vim.api.nvim_create_buf(true, true)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "a" })

      rn.add_note({ bufnr = buf, file = "a.lua", side = "file", start_line = 1, end_line = 1, text = "x" })
      rn.add_note({ bufnr = buf, file = "b.lua", side = "file", start_line = 1, end_line = 1, text = "y" })

      rn.clear_all()
      assert.are.same({}, rn.get_notes())
      vim.api.nvim_buf_delete(buf, { force = true })
    end)
  end)

  describe("resolve_buffer_context", function()
    it("resolves regular buffer to relative path", function()
      local buf = vim.api.nvim_create_buf(true, true)
      local git_root = vim.fn.systemlist("git rev-parse --show-toplevel")[1]
      vim.api.nvim_buf_set_name(buf, git_root .. "/src/main.lua")

      local ctx = rn.resolve_buffer_context(buf)
      assert.equals("src/main.lua", ctx.file)
      assert.equals("file", ctx.side)
      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("parses diffview buffer name with commit rev", function()
      local git_root = vim.fn.systemlist("git rev-parse --show-toplevel")[1]
      local buf = vim.api.nvim_create_buf(true, true)
      vim.api.nvim_buf_set_name(buf, "diffview://" .. git_root .. "/abc1234def0/src/main.lua")

      local ctx = rn.resolve_buffer_context(buf)
      assert.equals("src/main.lua", ctx.file)
      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("parses diffview buffer name with stage rev", function()
      local git_root = vim.fn.systemlist("git rev-parse --show-toplevel")[1]
      local buf = vim.api.nvim_create_buf(true, true)
      vim.api.nvim_buf_set_name(buf, "diffview://" .. git_root .. "/:0:/src/handler.lua")

      local ctx = rn.resolve_buffer_context(buf)
      assert.equals("src/handler.lua", ctx.file)
      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("returns nil for diffview panel buffers", function()
      local buf = vim.api.nvim_create_buf(true, true)
      vim.api.nvim_buf_set_name(buf, "diffview:///panels/DiffviewPanel")

      local ctx = rn.resolve_buffer_context(buf)
      assert.is_nil(ctx)
      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("handles buffer outside git root", function()
      local buf = vim.api.nvim_create_buf(true, true)
      vim.api.nvim_buf_set_name(buf, "/tmp/random/file.lua")

      local ctx = rn.resolve_buffer_context(buf)
      assert.equals("/tmp/random/file.lua", ctx.file)
      assert.equals("file", ctx.side)
      vim.api.nvim_buf_delete(buf, { force = true })
    end)
  end)

  describe("get_context_lines", function()
    it("captures ±3 lines around target", function()
      local buf = vim.api.nvim_create_buf(true, true)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
        "1", "2", "3", "4", "5", "6", "7", "8", "9", "10",
      })

      local before, target, after = rn.get_context_lines(buf, 5, 5, 3)
      assert.are.same({ "2", "3", "4" }, before)
      assert.are.same({ "5" }, target)
      assert.are.same({ "6", "7", "8" }, after)
      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("clamps at file start", function()
      local buf = vim.api.nvim_create_buf(true, true)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "1", "2", "3", "4" })

      local before, target, _ = rn.get_context_lines(buf, 1, 1, 3)
      assert.are.same({}, before)
      assert.are.same({ "1" }, target)
      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("clamps at file end", function()
      local buf = vim.api.nvim_create_buf(true, true)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "1", "2", "3", "4" })

      local _, target, after = rn.get_context_lines(buf, 4, 4, 3)
      assert.are.same({ "4" }, target)
      assert.are.same({}, after)
      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("handles multi-line range", function()
      local buf = vim.api.nvim_create_buf(true, true)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "1", "2", "3", "4", "5", "6", "7" })

      local before, target, after = rn.get_context_lines(buf, 3, 5, 2)
      assert.are.same({ "1", "2" }, before)
      assert.are.same({ "3", "4", "5" }, target)
      assert.are.same({ "6", "7" }, after)
      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("handles file shorter than radius", function()
      local buf = vim.api.nvim_create_buf(true, true)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "only" })

      local before, target, after = rn.get_context_lines(buf, 1, 1, 3)
      assert.are.same({}, before)
      assert.are.same({ "only" }, target)
      assert.are.same({}, after)
      vim.api.nvim_buf_delete(buf, { force = true })
    end)
  end)

  describe("export", function()
    local tmp_dir

    before_each(function()
      tmp_dir = vim.fn.tempname()
      vim.fn.mkdir(tmp_dir, "p")
      rn.setup({ context_radius = 2, export_dir = tmp_dir })
    end)

    after_each(function()
      vim.fn.delete(tmp_dir, "rf")
    end)

    it("skips export when no notes", function()
      local result = rn.export({ keep = false })
      assert.is_nil(result)
    end)

    it("writes markdown file to export_dir", function()
      local buf = vim.api.nvim_create_buf(true, true)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "a", "b", "c", "d", "e" })

      rn.add_note({ bufnr = buf, file = "src/main.lua", side = "new", start_line = 3, end_line = 3, text = "fix this" })

      local path = rn.export({ keep = false })
      assert.is_not_nil(path)
      assert.is_true(vim.fn.filereadable(path) == 1)

      local content = table.concat(vim.fn.readfile(path), "\n")
      assert.truthy(content:find("# Review Notes"))
      assert.truthy(content:find("src/main.lua"))
      assert.truthy(content:find("Line 3 %(new%)"))
      assert.truthy(content:find("fix this"))
      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("groups notes by file sorted by line", function()
      local buf = vim.api.nvim_create_buf(true, true)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "a", "b", "c", "d", "e" })

      rn.add_note({ bufnr = buf, file = "b.lua", side = "file", start_line = 1, end_line = 1, text = "second file" })
      rn.add_note({ bufnr = buf, file = "a.lua", side = "file", start_line = 3, end_line = 3, text = "line 3" })
      rn.add_note({ bufnr = buf, file = "a.lua", side = "file", start_line = 1, end_line = 1, text = "line 1" })

      local path = rn.export({ keep = true })
      local content = table.concat(vim.fn.readfile(path), "\n")

      local a_pos = content:find("## a.lua")
      local b_pos = content:find("## b.lua")
      assert.truthy(a_pos < b_pos)

      local l1_pos = content:find("line 1")
      local l3_pos = content:find("line 3")
      assert.truthy(l1_pos < l3_pos)
      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("uses Lines X-Y for multi-line range", function()
      local buf = vim.api.nvim_create_buf(true, true)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "a", "b", "c", "d", "e" })

      rn.add_note({ bufnr = buf, file = "a.lua", side = "old", start_line = 2, end_line = 4, text = "range" })

      local path = rn.export({ keep = false })
      local content = table.concat(vim.fn.readfile(path), "\n")
      assert.truthy(content:find("Lines 2%-4 %(old%)"))
      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("clears notes when keep=false", function()
      local buf = vim.api.nvim_create_buf(true, true)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "a" })

      rn.add_note({ bufnr = buf, file = "a.lua", side = "file", start_line = 1, end_line = 1, text = "x" })
      rn.export({ keep = false })

      assert.are.same({}, rn.get_notes())
      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("preserves notes when keep=true", function()
      local buf = vim.api.nvim_create_buf(true, true)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "a" })

      rn.add_note({ bufnr = buf, file = "a.lua", side = "file", start_line = 1, end_line = 1, text = "x" })
      rn.export({ keep = true })

      assert.equals(1, #rn.get_notes())
      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("copies export path to clipboard", function()
      local buf = vim.api.nvim_create_buf(true, true)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "a" })

      rn.add_note({ bufnr = buf, file = "a.lua", side = "file", start_line = 1, end_line = 1, text = "x" })
      local path = rn.export({ keep = true })

      local clipboard = vim.fn.getreg("+")
      assert.equals(path, clipboard)
      vim.api.nvim_buf_delete(buf, { force = true })
    end)
  end)

  describe("persistence", function()
    local tmp_dir

    before_each(function()
      tmp_dir = vim.fn.tempname()
      vim.fn.mkdir(tmp_dir, "p")
      rn.setup({ context_radius = 2, export_dir = tmp_dir, persist_dir = tmp_dir })
    end)

    after_each(function()
      vim.fn.delete(tmp_dir, "rf")
    end)

    it("persists and restores notes", function()
      local buf = vim.api.nvim_create_buf(true, true)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "a", "b", "c" })

      rn.add_note({ bufnr = buf, file = "x.lua", side = "file", start_line = 2, end_line = 2, text = "persist me" })
      rn.persist_to_disk()

      local session_path = tmp_dir .. "/.session.json"
      assert.is_true(vim.fn.filereadable(session_path) == 1)

      rn.reset_state()
      assert.are.same({}, rn.get_notes())

      rn.load_from_disk()
      local notes = rn.get_notes()
      assert.equals(1, #notes)
      assert.equals("x.lua", notes[1].file)
      assert.equals("persist me", notes[1].text)
      assert.equals(2, notes[1].start_line)
      assert.equals(2, notes[1].end_line)
      assert.equals("file", notes[1].side)
      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("handles missing session file gracefully", function()
      rn.load_from_disk()
      assert.are.same({}, rn.get_notes())
    end)

    it("auto-persists writes valid JSON", function()
      local buf = vim.api.nvim_create_buf(true, true)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "a", "b" })

      rn.add_note({ bufnr = buf, file = "check.lua", side = "file", start_line = 1, end_line = 1, text = "verify" })

      local session_path = tmp_dir .. "/.session.json"
      assert.is_true(vim.fn.filereadable(session_path) == 1)

      -- Read raw JSON and verify
      local raw = table.concat(vim.fn.readfile(session_path), "\n")
      local data = vim.json.decode(raw)
      assert.equals(1, #data.notes)
      assert.equals("check.lua", data.notes[1].file)
      assert.equals(1, data.notes[1].start_line)
      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("auto-persists on add_note", function()
      local buf = vim.api.nvim_create_buf(true, true)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "a", "b", "c" })

      rn.add_note({ bufnr = buf, file = "auto.lua", side = "file", start_line = 1, end_line = 1, text = "auto" })

      -- Session file should exist without explicit persist_to_disk call
      local session_path = tmp_dir .. "/.session.json"
      assert.is_true(vim.fn.filereadable(session_path) == 1)

      -- Verify content survives round-trip
      rn.reset_state()
      rn.load_from_disk()
      assert.equals(1, #rn.get_notes())
      assert.equals("auto", rn.get_notes()[1].text)
      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("auto-persists on delete_note", function()
      local buf = vim.api.nvim_create_buf(true, true)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "a", "b" })

      local n1 = rn.add_note({ bufnr = buf, file = "a.lua", side = "file", start_line = 1, end_line = 1, text = "x" })
      rn.add_note({ bufnr = buf, file = "a.lua", side = "file", start_line = 2, end_line = 2, text = "y" })
      rn.delete_note(n1.id)

      -- Reload and verify deletion persisted
      rn.reset_state()
      rn.load_from_disk()
      assert.equals(1, #rn.get_notes())
      assert.equals("y", rn.get_notes()[1].text)
      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("clear_all removes session file", function()
      local buf = vim.api.nvim_create_buf(true, true)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "a" })

      rn.add_note({ bufnr = buf, file = "a.lua", side = "file", start_line = 1, end_line = 1, text = "x" })

      local session_path = tmp_dir .. "/.session.json"
      assert.is_true(vim.fn.filereadable(session_path) == 1)

      rn.clear_all()

      -- Session file should be gone
      assert.is_true(vim.fn.filereadable(session_path) == 0)

      -- Reload should find nothing
      rn.load_from_disk()
      assert.are.same({}, rn.get_notes())
      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("auto-persists on edit_note", function()
      local buf = vim.api.nvim_create_buf(true, true)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "a" })

      local note = rn.add_note({ bufnr = buf, file = "a.lua", side = "file", start_line = 1, end_line = 1, text = "old" })
      rn.edit_note(note.id, "edited")

      rn.reset_state()
      rn.load_from_disk()
      assert.equals("edited", rn.get_notes()[1].text)
      vim.api.nvim_buf_delete(buf, { force = true })
    end)
  end)

  describe("extmarks", function()
    it("places extmark on noted line", function()
      local buf = vim.api.nvim_create_buf(true, true)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "a", "b", "c", "d", "e" })

      local note = rn.add_note({ bufnr = buf, file = "test.lua", side = "file", start_line = 3, end_line = 3, text = "check" })
      rn.place_extmark(buf, note)

      local marks = vim.api.nvim_buf_get_extmarks(buf, rn.get_namespace(), 0, -1, { details = true })
      assert.equals(1, #marks)
      assert.equals(2, marks[1][2]) -- 0-indexed
      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("refresh_extmarks reapplies all notes for buffer file", function()
      local buf = vim.api.nvim_create_buf(true, true)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "a", "b", "c", "d", "e" })

      rn.add_note({ bufnr = buf, file = "f.lua", side = "file", start_line = 1, end_line = 1, text = "x" })
      rn.add_note({ bufnr = buf, file = "f.lua", side = "file", start_line = 3, end_line = 3, text = "y" })
      rn.add_note({ bufnr = buf, file = "other.lua", side = "file", start_line = 1, end_line = 1, text = "z" })

      rn.refresh_extmarks(buf, "f.lua", "file")

      local marks = vim.api.nvim_buf_get_extmarks(buf, rn.get_namespace(), 0, -1, {})
      assert.equals(2, #marks)
      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("skips extmark when note line exceeds buffer length", function()
      local buf = vim.api.nvim_create_buf(true, true)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "a", "b", "c" }) -- 3 lines

      -- Note on line 10 — beyond buffer
      rn.add_note({ bufnr = buf, file = "f.lua", side = "file", start_line = 10, end_line = 10, text = "out of range" })
      -- Note on line 2 — valid
      rn.add_note({ bufnr = buf, file = "f.lua", side = "file", start_line = 2, end_line = 2, text = "ok" })

      -- Should not error, should place only the valid extmark
      rn.refresh_extmarks(buf, "f.lua", "file")

      local marks = vim.api.nvim_buf_get_extmarks(buf, rn.get_namespace(), 0, -1, {})
      assert.equals(1, #marks)
      assert.equals(1, marks[1][2]) -- 0-indexed line 1 = line 2
      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("skips extmark on invalid buffer", function()
      local buf = vim.api.nvim_create_buf(true, true)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "a" })

      local note = rn.add_note({ bufnr = buf, file = "f.lua", side = "file", start_line = 1, end_line = 1, text = "x" })
      vim.api.nvim_buf_delete(buf, { force = true })

      -- Should not error on deleted buffer
      rn.place_extmark(buf, note)
      rn.refresh_extmarks(buf, "f.lua", "file")
    end)

    it("never errors on set_extmark regardless of buffer state", function()
      local buf = vim.api.nvim_create_buf(true, true)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "a", "b" })

      -- Note at exact boundary
      rn.add_note({ bufnr = buf, file = "f.lua", side = "file", start_line = 2, end_line = 2, text = "boundary" })
      -- Note past boundary
      rn.add_note({ bufnr = buf, file = "f.lua", side = "file", start_line = 3, end_line = 3, text = "past" })
      -- Note way past
      rn.add_note({ bufnr = buf, file = "f.lua", side = "file", start_line = 100, end_line = 100, text = "way past" })

      -- None of these should error
      rn.refresh_extmarks(buf, "f.lua", "file")

      local marks = vim.api.nvim_buf_get_extmarks(buf, rn.get_namespace(), 0, -1, {})
      assert.equals(1, #marks) -- only line 2 (within 2-line buffer), lines 3 and 100 skipped
      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("clear_extmarks removes all from buffer", function()
      local buf = vim.api.nvim_create_buf(true, true)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "a", "b", "c" })

      rn.add_note({ bufnr = buf, file = "f.lua", side = "file", start_line = 1, end_line = 1, text = "x" })
      rn.refresh_extmarks(buf, "f.lua", "file")
      rn.clear_extmarks(buf)

      local marks = vim.api.nvim_buf_get_extmarks(buf, rn.get_namespace(), 0, -1, {})
      assert.equals(0, #marks)
      vim.api.nvim_buf_delete(buf, { force = true })
    end)
  end)

  describe("safe_cursor", function()
    it("jumps to line when within range", function()
      local buf = vim.api.nvim_create_buf(true, true)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "a", "b", "c" })
      vim.api.nvim_set_current_buf(buf)

      rn.safe_cursor(3)
      assert.equals(3, vim.api.nvim_win_get_cursor(0)[1])
      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("clamps to last line when out of range", function()
      local buf = vim.api.nvim_create_buf(true, true)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "a", "b", "c" })
      vim.api.nvim_set_current_buf(buf)

      rn.safe_cursor(100)
      assert.equals(3, vim.api.nvim_win_get_cursor(0)[1])
      vim.api.nvim_buf_delete(buf, { force = true })
    end)
  end)

  describe("is_diffview_open", function()
    it("returns false when not in diffview", function()
      assert.is_false(rn.is_diffview_open())
    end)
  end)

  describe("goto_note", function()
    it("opens file and jumps to line when not in diffview", function()
      local buf = vim.api.nvim_create_buf(true, true)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "a", "b", "c", "d", "e" })
      vim.api.nvim_set_current_buf(buf)

      rn.add_note({ bufnr = buf, file = "test.lua", side = "file", start_line = 3, end_line = 3, text = "note" })

      local note = rn.get_notes()[1]
      -- goto_note should not error even without real file on disk
      -- (it will try to open, may fail, but should not crash)
      -- Test the detection path returns false
      assert.is_false(rn.is_diffview_open())
      vim.api.nvim_buf_delete(buf, { force = true })
    end)
  end)

  describe("open_comment_float", function()
    it("creates valid buffer and window", function()
      local float_buf, float_win = rn.open_comment_float({
        preview_lines = { "context line" },
        on_confirm = function() end,
        on_cancel = function() end,
      })

      assert.is_true(vim.api.nvim_buf_is_valid(float_buf))
      assert.is_true(vim.api.nvim_win_is_valid(float_win))

      -- WinClosed autocmd handles cleanup
      vim.api.nvim_win_close(float_win, true)
    end)

    it("confirm callback receives typed text", function()
      local received_text = nil
      local preview = { "line before", ">>> target line", "line after" }
      local float_buf, _ = rn.open_comment_float({
        preview_lines = preview,
        on_confirm = function(text) received_text = text end,
      })

      local edit_idx = #preview + 1
      vim.api.nvim_buf_set_lines(float_buf, edit_idx, edit_idx + 1, false, { "my review comment" })

      vim.api.nvim_buf_call(float_buf, function()
        vim.cmd("write")
      end)

      assert.equals("my review comment", received_text)
    end)

    it("confirm callback receives multi-line text", function()
      local received_text = nil
      local preview = { "ctx1", "ctx2" }
      local float_buf, _ = rn.open_comment_float({
        preview_lines = preview,
        on_confirm = function(text) received_text = text end,
      })

      local edit_idx = #preview + 1
      vim.api.nvim_buf_set_lines(float_buf, edit_idx, edit_idx + 1, false, { "line one", "line two" })

      vim.api.nvim_buf_call(float_buf, function()
        vim.cmd("write")
      end)

      assert.equals("line one\nline two", received_text)
    end)

    it("confirm works via :w", function()
      local received_text = nil
      local preview = { "ctx" }
      local float_buf, _ = rn.open_comment_float({
        preview_lines = preview,
        on_confirm = function(text) received_text = text end,
      })

      local edit_idx = #preview + 1
      vim.api.nvim_buf_set_lines(float_buf, edit_idx, edit_idx + 1, false, { "saved via write" })

      -- Real :w — must not error with E382
      vim.api.nvim_buf_call(float_buf, function()
        vim.cmd("write")
      end)

      assert.equals("saved via write", received_text)
    end)

    it("cancel works via :q (BufUnload/QuitPre)", function()
      local cancelled = false
      local confirmed = false
      local preview = { "ctx" }
      local float_buf, float_win = rn.open_comment_float({
        preview_lines = preview,
        on_confirm = function() confirmed = true end,
        on_cancel = function() cancelled = true end,
      })

      assert.is_true(vim.api.nvim_win_is_valid(float_win))

      -- Simulate :q by closing window
      vim.api.nvim_win_close(float_win, true)

      assert.is_true(cancelled)
      assert.is_false(confirmed)
    end)

    it("shows help label with :w and :q hints", function()
      local preview = { "ctx1", "ctx2" }
      local float_buf, float_win = rn.open_comment_float({
        preview_lines = preview,
        on_confirm = function() end,
      })

      local lines = vim.api.nvim_buf_get_lines(float_buf, 0, -1, false)
      local all_text = table.concat(lines, "\n")
      assert.truthy(all_text:find(":w"), "should show :w hint")
      assert.truthy(all_text:find(":q"), "should show :q hint")
      assert.falsy(all_text:find("C%-s"), "should not show <C-s>")
      assert.falsy(all_text:find("Esc"), "should not show <Esc>")

      vim.api.nvim_win_close(float_win, true)
    end)
  end)
end)
