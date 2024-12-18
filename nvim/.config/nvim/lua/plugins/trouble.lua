return {
    "folke/trouble.nvim",
    event = "VeryLazy",
    dependencies = {
        "nvim-tree/nvim-web-devicons",
        "klen/nvim-config-local",
    },
    config = function()
        if CONFIG_TROUBLE_AUTO_OPEN == nil then
            CONFIG_TROUBLE_AUTO_OPEN = true
        end

        print('Trouble auto open:', CONFIG_TROUBLE_AUTO_OPEN)

        require('trouble').setup {
            auto_close = true,
            auto_preview = true,
            modes = {
                diagnostics = { auto_open = CONFIG_TROUBLE_AUTO_OPEN },
            }
        }
    end
}
