return {
    "folke/trouble.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {
        auto_close = true,
        auto_preview = true,
        modes = {
            diagnostics = { auto_open = true },
        }
    }
}
