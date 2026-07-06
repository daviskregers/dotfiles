local ui = require("code-agents.ui")

-- Replicates the reported bug: <leader>pq input returned q=nil (the cmdline
-- vim.ui.input was interrupted by background agent callbacks). The float input
-- must reliably deliver the typed text to on_submit.
describe("ui.prompt", function()
  it("delivers the typed text on submit (not nil)", function()
    local got
    local h = ui.prompt("Search", function(t) got = t end)
    vim.api.nvim_buf_set_lines(h.buf, 0, -1, false, { "serverless framework" })
    h.submit()
    assert.are.equal("serverless framework", got)
  end)

  it("does not fire on empty input", function()
    local got = "unset"
    local h = ui.prompt("Search", function(t) got = t end)
    h.submit()
    assert.are.equal("unset", got)
  end)

  it("does not fire on cancel", function()
    local got = "unset"
    local h = ui.prompt("Search", function(t) got = t end)
    vim.api.nvim_buf_set_lines(h.buf, 0, -1, false, { "x" })
    h.cancel()
    assert.are.equal("unset", got)
  end)

  it("does not hijack '%' (literal percent stays typeable); uses <C-f> for current file", function()
    vim.cmd("edit /tmp/some-origin-file.lua")
    local h = ui.prompt("t", function() end)
    local imaps = vim.api.nvim_buf_get_keymap(h.buf, "i")
    local function has(lhs)
      for _, m in ipairs(imaps) do if m.lhs == lhs then return true end end
      return false
    end
    assert.is_false(has("%"))                        -- percent is NOT remapped
    assert.is_true(has("<C-F>") or has("<C-f>"))     -- current-file insert lives on <C-f>
    if vim.api.nvim_win_is_valid(h.win) then vim.api.nvim_win_close(h.win, true) end
  end)

  it("submit is idempotent (second call is a no-op)", function()
    local calls = 0
    local h = ui.prompt("Search", function() calls = calls + 1 end)
    vim.api.nvim_buf_set_lines(h.buf, 0, -1, false, { "x" })
    h.submit(); h.submit()
    assert.are.equal(1, calls)
  end)
end)
