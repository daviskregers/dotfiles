local map = vim.api.nvim_set_keymap

-- maps

map('n', '<leader>t', ':TestNearest<CR>', { silent = true, noremap = true })
map('n', '<leader>T', ':TestFile<CR>', { silent = true, noremap = true })
map('n', '<leader>a', ':TestSuite<CR>', { silent = true, noremap = true })
map('n', '<leader>l', ':TestLast<CR>', { silent = true, noremap = true })
map('n', '<leader>g', ':TestVisit<CR>', { silent = true, noremap = true })

-- settings
local g = vim.g

g["test#preserve_screen"] = false
g['test#strategy'] = {
  nearest = 'vimux',
  file = 'vimux',
  suite = 'vimux'
}
g.VimuxOrientation = "h"
g.VimuxHeight = "120"
g['test#neovim#term_position'] = 'vert'

-- auto commands
