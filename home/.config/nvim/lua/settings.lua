vim.g.mapleader        = " "

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

-- scrolloff
vim.opt.scrolloff      = 8

-- enable sign column
vim.opt.signcolumn     = "yes"
vim.opt.isfname:append("@-@")

-- colorcolumn
vim.opt.textwidth      = 80

local M                = {}
M.range                = function(from, to)
    local result = {}
    for var = from, to do
        table.insert(result, var)
    end
    return result
end

vim.opt.colorcolumn    = table.concat(M.range(80, 240), ",")

-- cursorline
vim.opt.cursorline     = true

-- disable mouse
vim.opt.mouse          = ""

-- use utf8
vim.opt.fileencoding   = "utf-8"

-- folding
vim.opt.foldcolumn     = "1"
vim.opt.foldlevel      = 20
vim.opt.foldlevelstart = -1
vim.opt.foldenable     = true

vim.cmd([[
    set foldmethod=expr
    set foldexpr=nvim_treesitter#foldexpr()
    set nofoldenable
]])

vim.opt.runtimepath:append(',~/.config/nvim/lua/plugin')

vim.api.nvim_create_augroup("Tiltfile", { clear = true })
vim.api.nvim_create_autocmd({"BufNewFile", "BufRead"}, {
    group = "Tiltfile",
    pattern = { "Tiltfile" },
    command = 'silent! set syntax=starlark}',
})
