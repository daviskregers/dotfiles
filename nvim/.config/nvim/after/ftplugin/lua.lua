local set = vim.opt_local

-- set.shiftwidth = 2
set.number = true
set.relativenumber = true

-- reload / execute config
vim.keymap.set("n", "<leader><leader>x", "<cmd>source %<CR>")
vim.keymap.set("n", "<leader>x", ":.lua<CR>")
vim.keymap.set("v", "<leader>x", ":lua<CR>")
