local u = require('utils')

-- Highlight current line
u.create_augroup({
    { 'VimEnter,VimEnter,BufWinEnter', '*', 'setlocal', 'cursorline' },
    { 'WinLeave', '*', 'setlocal', 'nocursorline' }
}, 'CurrentLine')

require('nvim-cursorline').setup {
    cursorline = {
        enable = true,
        timeout = 1000,
        number = false,
    },
    cursorword = {
        enable = true,
        min_length = 3,
        hl = { underline = true },
    }
}
