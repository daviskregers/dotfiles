local rn = require("custom.review-notes")

describe("review-notes provider registry", function()
  before_each(function()
    rn.setup({ context_radius = 3, export_dir = vim.fn.tempname() })
  end)

  after_each(function()
    rn.clear_all()
  end)

  it("exposes inputs registry with markdown and pr", function()
    assert.is_table(rn.inputs)
    assert.is_table(rn.inputs.markdown)
    assert.is_table(rn.inputs.pr)
    assert.is_function(rn.inputs.markdown.load)
    assert.is_function(rn.inputs.pr.load)
  end)

  it("exposes outputs registry with markdown, pr, quickfix, agent", function()
    assert.is_table(rn.outputs)
    assert.is_function(rn.outputs.markdown.push)
    assert.is_function(rn.outputs.pr.push)
    assert.is_function(rn.outputs.quickfix.push)
    assert.is_function(rn.outputs.agent.push)
  end)
end)

describe("review-notes M.load", function()
  before_each(function()
    rn.setup({ context_radius = 3, export_dir = vim.fn.tempname() })
  end)

  after_each(function()
    rn.clear_all()
  end)

  it("ingests notes from an input provider", function()
    local path = vim.fn.tempname() .. ".md"
    local f = io.open(path, "w")
    f:write("src/x.lua:10: do thing\nlib/y.go:20-22: refactor\n")
    f:close()

    local count = rn.load("markdown", path)
    assert.equals(2, count)
    local notes = rn.get_notes()
    assert.equals(2, #notes)
    assert.equals("src/x.lua", notes[1].file)
    assert.equals(10, notes[1].start_line)
    vim.fn.delete(path)
  end)

  it("returns 0 when input has no findings", function()
    local path = vim.fn.tempname() .. ".md"
    local f = io.open(path, "w"); f:write("nothing here\n"); f:close()
    local count = rn.load("markdown", path)
    assert.equals(0, count)
    vim.fn.delete(path)
  end)

  it("errors on unknown input name", function()
    assert.has_error(function() rn.load("nonexistent", "anything") end)
  end)

  it("loaded notes have empty context arrays (not nil)", function()
    local path = vim.fn.tempname() .. ".md"
    local f = io.open(path, "w"); f:write("a.lua:1: msg\n"); f:close()
    rn.load("markdown", path)
    local n = rn.get_notes()[1]
    assert.are.same({}, n.context_before)
    assert.are.same({}, n.context_line)
    assert.are.same({}, n.context_after)
    vim.fn.delete(path)
  end)

  it("loaded notes have stable ids", function()
    local path = vim.fn.tempname() .. ".md"
    local f = io.open(path, "w"); f:write("a.lua:1: msg\n"); f:close()
    rn.load("markdown", path)
    assert.is_string(rn.get_notes()[1].id)
    vim.fn.delete(path)
  end)

  it("normalises absolute paths under git_root to relative", function()
    local root = rn.get_git_root()
    if not root or root == "" then return end -- skip if not in a git repo
    local md = string.format("#### 🟡 `%s/some/file.lua:42` — fix\n", root)
    local path = vim.fn.tempname() .. ".md"
    local f = io.open(path, "w"); f:write(md); f:close()
    rn.load("markdown", path)
    assert.equals("some/file.lua", rn.get_notes()[1].file)
    vim.fn.delete(path)
  end)

  it("leaves absolute paths outside git_root unchanged", function()
    local md = "#### 🟡 `/etc/passwd:1` — should not strip\n"
    local path = vim.fn.tempname() .. ".md"
    local f = io.open(path, "w"); f:write(md); f:close()
    rn.load("markdown", path)
    assert.equals("/etc/passwd", rn.get_notes()[1].file)
    vim.fn.delete(path)
  end)
end)

describe("review-notes notes_with_live_positions", function()
  before_each(function()
    rn.setup({ context_radius = 3, export_dir = vim.fn.tempname() })
  end)

  after_each(function()
    rn.clear_all()
  end)

  it("returns stored start_line when no extmark is tracked", function()
    local p = vim.fn.tempname() .. ".md"
    local f = io.open(p, "w"); f:write("a.lua:5: msg\n"); f:close()
    rn.load("markdown", p)
    local snap = rn.notes_with_live_positions()
    assert.equals(5, snap[1].start_line)
    vim.fn.delete(p)
  end)

  it("reflects edit-shifted line when extmark is placed in a loaded buffer", function()
    local buf = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_name(buf, (rn.get_git_root() or vim.fn.getcwd()) .. "/edit-test.lua")
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
      "line 1", "line 2", "line 3", "line 4", "line 5",
    })
    rn.add_note({
      bufnr = buf, file = "edit-test.lua", side = "file",
      start_line = 3, end_line = 3, text = "fix line 3",
    })
    rn.refresh_extmarks(buf, "edit-test.lua", "file")

    -- Insert two lines above line 3
    vim.api.nvim_buf_set_lines(buf, 0, 0, false, { "new1", "new2" })

    local snap = rn.notes_with_live_positions()
    assert.equals(5, snap[1].start_line) -- shifted from 3 to 5
  end)
end)

describe("review-notes actions", function()
  local sent
  local original_send

  before_each(function()
    rn.setup({ context_radius = 3, export_dir = vim.fn.tempname() })
    sent = nil
    local agents = require("custom.agents")
    original_send = agents.send
    agents.send = function(text) sent = text end
  end)

  after_each(function()
    require("custom.agents").send = original_send
    rn.clear_all()
  end)

  it("exposes a registry with /comment and /explain by default", function()
    assert.is_table(rn.actions)
    assert.is_function(rn.actions["/comment"])
    assert.is_function(rn.actions["/explain"])
  end)

  local note_fixture = {
    file = "src/x.lua", start_line = 10, end_line = 10,
    text = "use refresh tokens here",
    severity = "medium",
  }

  it("/comment sends `/comment <formatted note>` to active agent", function()
    rn.actions["/comment"](note_fixture)
    assert.is_string(sent)
    assert.equals("/comment ", sent:sub(1, 9))
    assert.matches("src/x%.lua:10", sent)
    assert.matches("use refresh tokens here", sent)
  end)

  it("/explain sends `/explain <formatted note>` to active agent", function()
    rn.actions["/explain"](note_fixture)
    assert.is_string(sent)
    assert.equals("/explain ", sent:sub(1, 9))
  end)

  it("send raw sends the formatted note without a slash command prefix", function()
    rn.actions["send raw"](note_fixture)
    assert.is_string(sent)
    assert.is_falsy(sent:find("^/"))
    assert.matches("src/x%.lua:10", sent)
  end)
end)

describe("review-notes PR roundtrip — kinds + source", function()
  local pr_input = require("custom.review.inputs.pr")
  local original_runner

  local SAMPLE = vim.json.encode({
    { id = 7001, path = "src/x.lua", line = 5, body = "comment one", user = { login = "u1" } },
    { id = 7002, path = "src/x.lua", line = 9, body = "comment two", user = { login = "u2" } },
  })

  before_each(function()
    rn.setup({ context_radius = 3, export_dir = vim.fn.tempname() })
    original_runner = pr_input._runner
    pr_input._runner = function() return SAMPLE end
  end)

  after_each(function()
    pr_input._runner = original_runner
    rn.clear_all()
  end)

  it("tags PR-loaded notes with kind=original and preserves pr_comment_id", function()
    rn.load("pr", "https://github.com/o/r/pull/123")
    local notes = rn.get_notes()
    assert.equals(2, #notes)
    assert.equals("original", notes[1].kind)
    assert.equals(7001, notes[1].pr_comment_id)
    assert.equals("original", notes[2].kind)
    assert.equals(7002, notes[2].pr_comment_id)
  end)

  it("stores the source PR ref on rn state for later push", function()
    rn.load("pr", "https://github.com/o/r/pull/123")
    assert.equals("https://github.com/o/r/pull/123", rn.get_source_pr())
  end)

  it("markdown input does not set source_pr or kind=original", function()
    local p = vim.fn.tempname() .. ".md"
    local f = io.open(p, "w"); f:write("a.lua:1: msg\n"); f:close()
    rn.load("markdown", p)
    assert.is_nil(rn.get_source_pr())
    assert.is_not.equals("original", rn.get_notes()[1].kind)
    vim.fn.delete(p)
  end)
end)

describe("review-notes reply action", function()
  local pr_input = require("custom.review.inputs.pr")
  local original_runner
  local sent

  before_each(function()
    rn.setup({ context_radius = 3, export_dir = vim.fn.tempname() })
    original_runner = pr_input._runner
    pr_input._runner = function() return vim.json.encode({
      { id = 8001, path = "src/x.lua", line = 5, body = "original comment", user = { login = "u" } },
    }) end
    rn.load("pr", "https://github.com/o/r/pull/9")
    sent = nil
    local agents = require("custom.agents")
    agents.send = function(text) sent = text end
  end)

  after_each(function()
    pr_input._runner = original_runner
    rn.clear_all()
  end)

  it("reply action creates a child note tied to the original by pr_comment_id", function()
    local original = rn.get_notes()[1]
    rn.add_reply(original, "thanks, will fix")
    local notes = rn.get_notes()
    assert.equals(2, #notes)
    local reply = notes[2]
    assert.equals("reply", reply.kind)
    assert.equals(8001, reply.replies_to_id)
    assert.equals("src/x.lua", reply.file)
    assert.equals(5, reply.start_line)
    assert.equals("thanks, will fix", reply.text)
  end)
end)

describe("review-notes thread helpers", function()
  before_each(function()
    rn.setup({ context_radius = 3, export_dir = vim.fn.tempname() })
  end)
  after_each(function() rn.clear_all() end)

  local function make_note(id, fields)
    fields = fields or {}
    rn.add_note({
      bufnr = vim.api.nvim_create_buf(true, true),
      file = "f.lua", side = "file", start_line = 1, end_line = 1,
      text = "n" .. id,
    })
    -- patch fields onto the freshly added note
    local n = rn.get_notes()[#rn.get_notes()]
    for k, v in pairs(fields) do n[k] = v end
    return n
  end

  it("get_thread returns root + chronological replies", function()
    local root = make_note(1, { kind = "original", pr_comment_id = 100 })
    local r1   = make_note(2, { kind = "original", pr_comment_id = 101, in_reply_to_id = 100, created_at = 2 })
    local r2   = make_note(3, { kind = "reply",    replies_to_id = 100, created_at = 1 })
    local thread = rn.get_thread(root)
    assert.equals(3, #thread)
    assert.equals(root, thread[1])
    -- replies sorted by created_at asc (r2 then r1)
    assert.equals(r2, thread[2])
    assert.equals(r1, thread[3])
  end)

  it("get_thread starting from a reply traverses up to root", function()
    local root  = make_note(1, { kind = "original", pr_comment_id = 50 })
    local reply = make_note(2, { kind = "original", pr_comment_id = 51, in_reply_to_id = 50 })
    local thread = rn.get_thread(reply)
    assert.equals(2, #thread)
    assert.equals(root, thread[1])
  end)

  it("get_thread on a standalone note returns just that note", function()
    local n = make_note(1, { kind = "local" })
    local thread = rn.get_thread(n)
    assert.equals(1, #thread)
    assert.equals(n, thread[1])
  end)
end)

describe("review-notes M.push failure tracking", function()
  local pr_out

  before_each(function()
    rn.setup({ context_radius = 3, export_dir = vim.fn.tempname() })
    pr_out = require("custom.review.outputs.pr")
  end)
  after_each(function() rn.clear_all() end)

  it("sets last_push_error on a note when its push fails", function()
    -- Add a local note
    local buf = vim.api.nvim_create_buf(true, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "l1", "l2", "l3" })
    rn.add_note({ bufnr = buf, file = "f.lua", side = "file", start_line = 1, end_line = 1, text = "x" })

    pr_out._runner = function(a)
      if a[1] == "pr" and a[2] == "view" then return "sha\n" end
      return nil  -- everything else fails
    end
    rn.push("pr", { pr = "https://github.com/o/r/pull/1" })

    local notes = rn.get_notes()
    assert.is_string(notes[1].last_push_error)
  end)

  it("clears last_push_error on a successful retry", function()
    local buf = vim.api.nvim_create_buf(true, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "l1" })
    rn.add_note({ bufnr = buf, file = "f.lua", side = "file", start_line = 1, end_line = 1, text = "x" })
    -- Manually set a stale error
    rn.get_notes()[1].last_push_error = "stale"

    pr_out._runner = function(a)
      if a[1] == "pr" and a[2] == "view" then return "sha\n" end
      return "{}"  -- success
    end
    rn.push("pr", { pr = "https://github.com/o/r/pull/1" })

    assert.is_nil(rn.get_notes()[1].last_push_error)
  end)
end)

describe("review-notes M.push", function()
  before_each(function()
    rn.setup({ context_radius = 3, export_dir = vim.fn.tempname() })
    -- Add a couple of notes so push has something to operate on
    local buf = vim.api.nvim_create_buf(true, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "l1", "l2", "l3", "l4", "l5" })
    rn.add_note({ bufnr = buf, file = "f.lua", side = "file", start_line = 2, end_line = 2, text = "fix" })
  end)

  after_each(function()
    rn.clear_all()
  end)

  it("dispatches to the named output provider", function()
    local res = rn.push("quickfix", { open = false })
    assert.is_true(res.ok)
    assert.equals(1, res.count)
    assert.equals(1, #vim.fn.getqflist())
  end)

  it("errors on unknown output name", function()
    assert.has_error(function() rn.push("nonexistent") end)
  end)

  it("forwards opts to the output provider", function()
    local tmp = vim.fn.tempname()
    vim.fn.mkdir(tmp, "p")
    local res = rn.push("markdown", { dir = tmp })
    assert.is_true(res.ok)
    assert.is_true(res.path:find(tmp, 1, true) ~= nil)
    vim.fn.delete(tmp, "rf")
  end)

  it("operates on get_notes() — pushes everything currently loaded", function()
    local res = rn.push("quickfix", { open = false })
    assert.equals(1, res.count)
    -- After loading more, push pushes all
    local p = vim.fn.tempname() .. ".md"
    local f = io.open(p, "w"); f:write("g.lua:5: extra\n"); f:close()
    rn.load("markdown", p)
    local res2 = rn.push("quickfix", { open = false })
    assert.equals(2, res2.count)
    vim.fn.delete(p)
  end)
end)
