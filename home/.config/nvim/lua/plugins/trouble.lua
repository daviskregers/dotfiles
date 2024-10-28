return {
    "folke/trouble.nvim",
    event = "VeryLazy",
    dependencies = {
        "nvim-tree/nvim-web-devicons",
        "klen/nvim-config-local",
    },
    config = function()
        -- if vim.g.TROUBLE_AUTO_OPEN == nil then
        --     print('TROUBLE_AUTO_OPEN is not set, defaulting to true')
        --     vim.g.TROUBLE_AUTO_OPEN = true
        -- end

        print('Trouble auto open:', vim.g.TROUBLE_AUTO_OPEN)

        require('trouble').setup {
            auto_close = true,
            auto_preview = true,
            modes = {
                diagnostics = { auto_open = vim.g.TROUBLE_AUTO_OPEN },
            }
        }
    end
}
