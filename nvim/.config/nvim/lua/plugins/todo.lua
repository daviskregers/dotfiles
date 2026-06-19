vim.pack.add({
    'https://github.com/folke/todo-comments.nvim',
})

local todo = require('todo-comments')

todo.setup()

vim.keymap.set("n", "<leader>pt", ':TodoTelescope<CR>', { desc = "Find TODOs" })

vim.keymap.set("n", "]t", function()
    todo.jump_next()
end, { desc = "Next todo comment" })

vim.keymap.set("n", "[t", function()
    todo.jump_prev()
end, { desc = "Previous todo comment" })
