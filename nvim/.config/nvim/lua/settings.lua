-- remap leader
vim.g.mapleader        = " "
vim.g.maplocalleader   = "\\"

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

local colorcolumn   = require('custom.colorcolumn')
vim.opt.colorcolumn = colorcolumn.colorcolumn
-- vim.opt.textwidth   = colorcolumn.textwidth

vim.api.nvim_create_augroup("Tiltfile", { clear = true })
vim.api.nvim_create_autocmd({ "BufNewFile", "BufRead" }, {
    group = "Tiltfile",
    pattern = { "Tiltfile" },
    command = 'silent! set syntax=starlark}',
})

vim.api.nvim_create_autocmd("TextYankPost", {
    desc = "Highlight when yanking text",
    group = vim.api.nvim_create_augroup("highlight-yank", { clear = true }),
    callback = function()
        vim.highlight.on_yank()
    end,
})

vim.api.nvim_create_autocmd("TermOpen", {
    desc = "Custom settings for terminal",
    group = vim.api.nvim_create_augroup("terminal-open", { clear = true }),
    callback = function()
        vim.opt.nu             = false
        vim.opt.relativenumber = false
    end,
})

vim.opt.autoread = true

local function refresh_log_files()
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(buf) then
            local name = vim.api.nvim_buf_get_name(buf)
            if name:match("%.log$") then
                local ok, _ = pcall(vim.cmd, "checktime " .. buf)
                if not ok then
                    vim.cmd("edit!")
                end
            end
        end
    end
end

vim.timer = vim.loop.new_timer()
vim.timer:start(0, 2000, vim.schedule_wrap(refresh_log_files))

