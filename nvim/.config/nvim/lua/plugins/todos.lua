return {
    "folke/todo-comments.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    opts = {
    },
    keys = {
        { '<leader>pd', ":TodoTelescope<CR>", mode = 'n', desc = 'TODOs' }
    }
}
