local map = vim.api.nvim_set_keymap
local options = { noremap = true }

vim.g.ultest_use_pty = true

map('n', ']t', '<Plug>(ultest-next-fail)', options)
map('n', '[t', '<Plug>(ultest-prev-fail)', options)

-- TODO: configure phpunit etc
