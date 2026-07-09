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

  it("delivers a multi-line paste joined with newlines", function()
    local got
    local h = ui.prompt("Search", function(t) got = t end)
    vim.api.nvim_buf_set_lines(h.buf, 0, -1, false, { "line one", "line two", "line three" })
    h.submit()
    assert.are.equal("line one\nline two\nline three", got)
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

  -- Submit is ^S (insert+normal) and normal-mode <CR>. Insert-mode <CR> is left
  -- UNMAPPED so Enter inserts a newline — robust across terminals/tmux that fold
  -- Shift+Enter into a plain <CR> (the old <S-CR> newline binding never arrived).
  it("submits on <C-s> and normal-mode <CR>; insert-mode <CR> inserts a newline", function()
    local h = ui.prompt("t", function() end)
    local function has(mode, lhs)
      for _, m in ipairs(vim.api.nvim_buf_get_keymap(h.buf, mode)) do
        if m.lhs == lhs then return true end
      end
      return false
    end
    assert.is_true(has("i", "<C-S>") or has("i", "<C-s>")) -- ^S submits in insert mode
    assert.is_true(has("n", "<CR>"))                       -- Enter submits in normal mode
    assert.is_false(has("i", "<CR>"))                      -- insert Enter → literal newline
    assert.is_false(has("i", "<S-CR>"))                    -- no fragile Shift+Enter binding
    if vim.api.nvim_win_is_valid(h.win) then vim.api.nvim_win_close(h.win, true) end
  end)

  it("prefills the buffer with the given multi-line text", function()
    local h = ui.prompt("t", function() end, { prefill = "one\ntwo" })
    assert.are.same({ "one", "two" }, vim.api.nvim_buf_get_lines(h.buf, 0, -1, false))
    if vim.api.nvim_win_is_valid(h.win) then vim.api.nvim_win_close(h.win, true) end
  end)

  it("with allow_empty, an empty submit still fires on_submit (for clear-on-empty)", function()
    local got = "unset"
    local h = ui.prompt("t", function(t) got = t end, { allow_empty = true })
    h.submit()
    assert.are.equal("", got)
  end)

  it("submit is idempotent (second call is a no-op)", function()
    local calls = 0
    local h = ui.prompt("Search", function() calls = calls + 1 end)
    vim.api.nvim_buf_set_lines(h.buf, 0, -1, false, { "x" })
    h.submit(); h.submit()
    assert.are.equal(1, calls)
  end)

  it("clear empties the buffer without submitting", function()
    local got = "unset"
    local h = ui.prompt("Search", function(t) got = t end)
    vim.api.nvim_buf_set_lines(h.buf, 0, -1, false, { "line one", "line two" })
    h.clear()
    assert.are.same({ "" }, vim.api.nvim_buf_get_lines(h.buf, 0, -1, false))
    assert.are.equal("unset", got)                   -- clearing does not fire on_submit
    if vim.api.nvim_win_is_valid(h.win) then vim.api.nvim_win_close(h.win, true) end
  end)

  it("binds <C-u> to clear the content in insert and normal mode", function()
    local h = ui.prompt("t", function() end)
    local function has(mode, lhs)
      for _, m in ipairs(vim.api.nvim_buf_get_keymap(h.buf, mode)) do
        if m.lhs == lhs then return true end
      end
      return false
    end
    assert.is_true(has("i", "<C-U>") or has("i", "<C-u>"))
    assert.is_true(has("n", "<C-U>") or has("n", "<C-u>"))
    if vim.api.nvim_win_is_valid(h.win) then vim.api.nvim_win_close(h.win, true) end
  end)
end)
