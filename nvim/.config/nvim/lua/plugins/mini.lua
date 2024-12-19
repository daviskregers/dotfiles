return {
    {
        'echasnovski/mini.nvim',
        config = function()
            local statusline = require 'mini.statusline'
            statusline.setup { use_icons = true }

            vim.api.nvim_set_hl(0, 'MiniStatuslineModeNormal', { link = 'DiffChange', default = true })
        end
    },
}
