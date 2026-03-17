return {
    {
        "olimorris/codecompanion.nvim",
        version = "^19.0.0",
        opts = {},
        dependencies = {
            "nvim-lua/plenary.nvim",
            "nvim-treesitter/nvim-treesitter",
        },
        keys = {
            { "<C-\\>", ":CodeCompanion<CR>", mode = "n", desc = "Run CodeCompanion" },
            { "<C-\\>", ":CodeCompanion<CR>", mode = "v", desc = "Run CodeCompanion on selection" },
            { "<C-_>", ":CodeCompanionChat<CR>", mode = "n", desc = "Toggle CodeCompanion Chat" },
        },
    },
}
