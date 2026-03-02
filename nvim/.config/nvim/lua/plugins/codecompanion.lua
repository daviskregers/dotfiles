return {
    {
        "olimorris/codecompanion.nvim",
        dependencies = {
            "nvim-lua/plenary.nvim",
            "nvim-treesitter/nvim-treesitter",
        },
        opts = {
            opts = {
              log_level = "DEBUG", -- or "TRACE"
            },
        },
        keys = {
            { '<leader>cc', ":CodeCompanion<cr>", mode = 'n', desc = 'Code Companion' },
            { '<leader>cc', ":'<,'>CodeCompanion<cr>", mode = 'v', desc = 'Code Companion' },
            { '<leader>ca', ":CodeCompanionActions<cr>", mode = 'n', desc = 'Code Companion Actions' },
            { '<leader>ch', ":CodeCompanionChat<cr>", mode = 'n', desc = 'Code Companion Chat' },
            { '<leader>cm', ":CodeCompanionCmd", mode = 'n', desc = 'Code Companion Command' },
        }
    },
}
