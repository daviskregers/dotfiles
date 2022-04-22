local global = vim.o
local window = vim.wo
local buffer = vim.bo

local cmd = vim.cmd

-- If you’re not sure if an option is global, buffer or window-local,
-- consult the Vim help! For example, :h 'number':

global.swapfile = false
global.dir = '/tmp'
global.smartcase = true
global.laststatus = 2
global.hlsearch = true
global.incsearch = true
global.ignorecase = true
global.scrolloff = 12
global.hidden = true
global.pumheight = 10
global.ruler = true
global.cmdheight = 2
global.mouse = 'a'
global.splitbelow = true
global.splitright = true
global.smarttab = true
global.expandtab = true
global.smartindent = true
global.autoindent = true
global.background = 'dark'
global.showtabline = 2
global.showmode = false
global.backup = false
global.writebackup = false
global.updatetime = 300
global.timeoutlen = 500
global.clipboard = 'unnamedplus'
global.guifont = 'FiraCode Nerd Font:h12'
global.termguicolors = true
global.tags ='tags;,./tags;'
global.grepprg = 'rg --nogroup --nocolor'
global.completeopt = "menuone,noinsert,noselect"

window.wrap = false
window.conceallevel = 0
window.number = true
window.relativenumber = true
window.cursorline = true
window.colorcolumn = '120'
window.foldmethod = 'indent'
window.foldenable = false

buffer.syntax = 'ON'
buffer.tabstop = 4
buffer.shiftwidth = 4
buffer.autoread = true
buffer.softtabstop = 4

vim.opt.sw = 4
vim.opt.ts = 4

cmd('au CursorHold * checktime')
cmd('au! BufWritePost $MYVIMRC :Reload')
cmd('au Filetype * setlocal omnifunc=v:lua.vim.lsp.omnifunc')

vim.g['gutentags_cache_dir'] = '~/.cache/tags'


vim.o.updatetime = 300
vim.o.incsearch = false
vim.wo.signcolumn = 'yes'
