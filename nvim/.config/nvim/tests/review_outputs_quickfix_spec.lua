local qf = require("custom.review.outputs.quickfix")

local function notes_fixture()
  return {
    { file = "src/a.lua", start_line = 5, end_line = 5, text = "fix this" },
    { file = "lib/b.go", start_line = 10, end_line = 12, text = "refactor block" },
  }
end

describe("review.outputs.quickfix", function()
  before_each(function()
    vim.fn.setqflist({}, "r")
  end)

  it("populates the quickfix list with one entry per note", function()
    qf.push(notes_fixture(), { open = false })
    local list = vim.fn.getqflist()
    assert.equals(2, #list)
    assert.matches("src/a%.lua", vim.fn.bufname(list[1].bufnr))
    assert.equals(5, list[1].lnum)
    assert.matches("fix this", list[1].text)
  end)

  it("sets the qf list title to identify it as review notes", function()
    qf.push(notes_fixture(), { open = false })
    local what = vim.fn.getqflist({ title = 1 })
    assert.matches("[Rr]eview", what.title)
  end)

  it("returns ok status with note count", function()
    local res = qf.push(notes_fixture(), { open = false })
    assert.is_true(res.ok)
    assert.equals(2, res.count)
  end)

  it("handles empty notes list gracefully", function()
    local res = qf.push({}, { open = false })
    assert.is_true(res.ok)
    assert.equals(0, res.count)
    assert.equals(0, #vim.fn.getqflist())
  end)

  it("opens the quickfix window when open=true", function()
    -- close any open qf window first
    vim.cmd("cclose")
    qf.push(notes_fixture(), { open = true })
    -- find a window with quickfix buf
    local found = false
    for _, w in ipairs(vim.api.nvim_list_wins()) do
      local buf = vim.api.nvim_win_get_buf(w)
      if vim.bo[buf].buftype == "quickfix" then found = true; break end
    end
    assert.is_true(found)
    vim.cmd("cclose")
  end)

  it("uses end_line for range when present and different from start_line", function()
    qf.push(notes_fixture(), { open = false })
    local list = vim.fn.getqflist()
    assert.equals(10, list[2].lnum)
    -- end_lnum is qf's range marker (vim 8+)
    assert.equals(12, list[2].end_lnum)
  end)

  it("prefixes resolved items with ✓ in the qf text", function()
    qf.push({
      { file = "a.lua", start_line = 1, end_line = 1, text = "done",   resolved = true },
      { file = "b.lua", start_line = 2, end_line = 2, text = "active", resolved = false },
    }, { open = false })
    local list = vim.fn.getqflist()
    -- Find which entry has the ✓ prefix regardless of order.
    local resolved_text, active_text
    for _, e in ipairs(list) do
      if e.text:match("^✓") then resolved_text = e.text else active_text = e.text end
    end
    assert.matches("done", resolved_text)
    assert.equals("active", active_text)
  end)

  it("orders unresolved items before resolved", function()
    qf.push({
      { file = "a.lua", start_line = 1, end_line = 1, text = "resolved", resolved = true },
      { file = "b.lua", start_line = 2, end_line = 2, text = "active",   resolved = false },
    }, { open = false })
    local list = vim.fn.getqflist()
    assert.matches("active", list[1].text)
    assert.matches("resolved", list[2].text)
  end)

  it("maps severity to qf type (high=E, medium=W, low=I)", function()
    qf.push({
      { file = "a.lua", start_line = 1, end_line = 1, text = "high",   severity = "high" },
      { file = "b.lua", start_line = 2, end_line = 2, text = "medium", severity = "medium" },
      { file = "c.lua", start_line = 3, end_line = 3, text = "low",    severity = "low" },
      { file = "d.lua", start_line = 4, end_line = 4, text = "none" },
    }, { open = false })
    local list = vim.fn.getqflist()
    assert.equals("E", list[1].type)
    assert.equals("W", list[2].type)
    assert.equals("I", list[3].type)
    assert.equals("",  list[4].type)
  end)
end)
