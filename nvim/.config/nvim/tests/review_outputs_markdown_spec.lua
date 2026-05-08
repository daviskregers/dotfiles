local md_out = require("custom.review.outputs.markdown")

local function notes_fixture()
  return {
    {
      file = "src/a.lua",
      side = "file",
      start_line = 5,
      end_line = 5,
      text = "fix this",
      context_before = { "before1", "before2" },
      context_line = { "target line" },
      context_after = { "after1", "after2" },
    },
  }
end

describe("review.outputs.markdown", function()
  local tmp_dir

  before_each(function()
    tmp_dir = vim.fn.tempname()
    vim.fn.mkdir(tmp_dir, "p")
  end)

  after_each(function()
    vim.fn.delete(tmp_dir, "rf")
  end)

  it("writes a markdown file with the formatted notes", function()
    local res = md_out.push(notes_fixture(), { dir = tmp_dir })
    assert.is_true(res.ok)
    assert.equals(1, res.count)
    assert.is_string(res.path)
    assert.is_true(vim.fn.filereadable(res.path) == 1)
  end)

  it("uses the configured dir for output", function()
    local res = md_out.push(notes_fixture(), { dir = tmp_dir })
    assert.is_true(res.path:find(tmp_dir, 1, true) ~= nil)
  end)

  it("file content includes the note text", function()
    local res = md_out.push(notes_fixture(), { dir = tmp_dir })
    local f = io.open(res.path, "r")
    local content = f:read("*a"); f:close()
    assert.matches("fix this", content)
    assert.matches("src/a%.lua", content)
  end)

  it("returns ok with count=0 for empty list (no file written)", function()
    local res = md_out.push({}, { dir = tmp_dir })
    assert.is_true(res.ok)
    assert.equals(0, res.count)
    assert.is_nil(res.path)
  end)

  it("falls back to default export dir when dir not provided", function()
    -- We can't safely write to the default path in tests, so just verify the
    -- function does not crash when dir is nil and notes are empty.
    local res = md_out.push({}, nil)
    assert.is_true(res.ok)
  end)
end)
