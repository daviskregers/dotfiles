local M                = {}
M.range                = function(from, to)
    local result = {}
    for var = from, to do
        table.insert(result, var)
    end
    return result
end

-- preserve chonker cursor in insert
vim.opt.guicursor      = ""

-- use relative line numbers
vim.opt.nu             = true
vim.opt.relativenumber = true

-- use 4 spaces
vim.opt.tabstop        = 4
vim.opt.softtabstop    = 4
vim.opt.shiftwidth     = 4
vim.opt.expandtab      = true

-- do not wrap lines
vim.opt.wrap           = false

-- undo
vim.opt.swapfile       = false
vim.opt.backup         = false
vim.opt.undodir        = os.getenv("HOME") .. "/.vim/undodir"
vim.opt.undofile       = true

-- highlights
vim.opt.hlsearch       = false
vim.opt.incsearch      = true

vim.opt.termguicolors  = true

vim.opt.scrolloff      = 8
vim.opt.signcolumn     = "yes"
vim.opt.isfname:append("@-@")

vim.opt.updatetime  = 50

vim.opt.textwidth   = 80
vim.opt.colorcolumn = table.concat(M.range(80, 240), ",")

vim.opt.cursorline  = true

-- disable mouse
vim.opt.mouse       = ""

-- highlight yank
vim.api.nvim_create_augroup("highlight_yank", { clear = true })
vim.api.nvim_create_autocmd("TextYankPost", {
    group = "highlight_yank",
    pattern = { "*" },
    command = 'silent! lua vim.highlight.on_yank{higroup="IncSearch", timeout=300}',
})

vim.api.nvim_create_augroup("tiltfile", { clear = true })
vim.api.nvim_create_autocmd("BufRead", {
    group = "tiltfile",
    pattern = { "Tiltfile" },
    command = "setf=tiltfile"
})

-- use utf-8
vim.opt.fileencoding = "utf-8"

-- smart auto indenting when starting a new line.
vim.opt.autoindent   = true
vim.opt.smartindent  = true

-- automatically reload file on changes
vim.opt.autoread     = true

vim.api.nvim_create_augroup('checktime', { clear = true })
local reloadcmd = 'if mode() != "c" | checktime | endif'
vim.api.nvim_create_autocmd('FocusGained', {
    group = 'checktime',
    pattern = { '*' },
    command = reloadcmd
})
vim.api.nvim_create_autocmd('BufEnter', {
    group = 'checktime',
    pattern = { '*' },
    command = reloadcmd
})
vim.api.nvim_create_autocmd('CursorHold', {
    group = 'checktime',
    pattern = { '*' },
    command = reloadcmd
})
vim.api.nvim_create_autocmd('CursorHoldI', {
    group = 'checktime',
    pattern = { '*' },
    command = reloadcmd
})

vim.api.nvim_create_augroup('file_changed', { clear = true })
vim.api.nvim_create_autocmd('FileChangedShellPost', {
    group = 'file_changed',
    pattern = { '*' },
    command = 'echohl WarningMsg | echo "File changed on disk. Buffer reloaded." | echohl None'
})

-- format before save
-- vim.cmd [[autocmd BufWritePre <buffer> lua vim.lsp.buf.format()]]
-- vim.cmd [[autocmd BufWritePre * lua vim.lsp.buf.format()]]
--

-- folding
vim.opt.foldcolumn = "1"
vim.opt.foldlevel = 99
vim.opt.foldlevelstart = -1
vim.opt.foldenable = true
