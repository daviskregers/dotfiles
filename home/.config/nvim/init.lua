local map = vim.api.nvim_set_keymap
local options = { noremap = true }

vim.g.mapleader = ","
vim.g['gutentags_cache_dir'] = '~/.cache/tags'
vim.o.autoindent = true
vim.o.expandtab = true
vim.o.incsearch = false
vim.o.shiftwidth = 4
vim.o.tabstop = 4
vim.o.updatetime = 300
vim.opt.backup = false
vim.opt.clipboard = 'unnamedplus'
vim.opt.completeopt = { "menu", "menuone", "noselect" }
vim.opt.syntax = "ON"
vim.opt.termguicolors = true
vim.opt.writebackup = false
vim.wo.signcolumn = 'yes'

require('plugins')

require('autocomplete')
require('autopairs')
require('cursor')
require('file-explorer')
require('git')
require('indents')
require('linters')
require('lsp')
require('markdown')
require('marking')
require('packages')
require('preview')
require('projects')
require('refactor')
require('search')
require('snippets')
require('tabs')
require('tagbar')
require('testing')
require('todos')
require('toggle-comments')
require('treesitter')
require('trouble-list')
require('whichkey')
require('whitespace')

require('colorscheme')
require('statusline')


-- move line up or down
map('n', '<A-j>', ':m .+1<CR>==', options)
map('n', '<A-k>', ':m .-2<CR>==', options)
map('i', '<A-j>', '<Esc>:m .+1<CR>==gi', options)
map('i', '<A-k>', '<Esc>:m .-2<CR>==gi', options)
map('v', '<A-j>', ':m \'>+1<CR>gv=gv', options)
map('v', '<A-k>', ':m \'<-2<CR>gv=gv', options)

map('n', '<A-Down>', ':m .+1<CR>==', options)
map('n', '<A-Up>', ':m .-2<CR>==', options)
map('i', '<A-Down>', '<Esc>:m .+1<CR>==gi', options)
map('i', '<A-Up>', '<Esc>:m .-2<CR>==gi', options)
map('v', '<A-Down>', ':m \'>+1<CR>gv=gv', options)
map('v', '<A-Up>', ':m \'<-2<CR>gv=gv', options)
-- sort lines
map('v', '<leader>s', ':sort u<CR>', {})

-- line numbers
vim.wo.number = true
vim.wo.relativenumber = true

-- Increase selection region
map('x', 'K', '<Plug>(expand_region_expand)', options)
map('x', 'J', '<Plug>(expand_region_shrink)', options)

-- color column
vim.wo.colorcolumn = '120'
vim.api.nvim_set_hl(0, 'ColorColumn', { background = '#e17055' })

-- comments
vim.api.nvim_set_hl(0, 'TSComment', { bold = true, foreground = 'red' })

-- text align
map('v', 'gA', ':Align ', options)

-- Better indentation
map('v', '<', '<gv', options)
map('v', '>', '>gv', options)

-- TODO: setup git mergetool
-- TODO: coverage highlighting
-- TODO: add debugging tools
-- TODO: test php, ultest
-- TODO: test nodejs, ultest
-- TODO: test typescript, ultest
-- TODO: test C#, ultest
-- TODO: test elixir, ultest
-- TODO: test markdown, ultest
-- TODO: add custom snippets
-- TODO: cleanup
