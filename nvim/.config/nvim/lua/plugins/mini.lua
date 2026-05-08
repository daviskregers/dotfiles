return {
    {
        'echasnovski/mini.nvim',
        config = function()
            local statusline = require 'mini.statusline'
            local agent_status = require 'custom.agent_statusline'
            agent_status.setup()

            statusline.setup {
                use_icons = true,
                content = {
                    active = function()
                        local mode, mode_hl = statusline.section_mode({ trunc_width = 120 })
                        local git           = statusline.section_git({ trunc_width = 40 })
                        local diff          = statusline.section_diff({ trunc_width = 75 })
                        local diagnostics   = statusline.section_diagnostics({ trunc_width = 75 })
                        local lsp           = statusline.section_lsp({ trunc_width = 75 })
                        local filename      = statusline.section_filename({ trunc_width = 140 })
                        local fileinfo      = statusline.section_fileinfo({ trunc_width = 120 })
                        local location      = statusline.section_location({ trunc_width = 75 })
                        local search        = statusline.section_searchcount({ trunc_width = 75 })
                        local cc            = agent_status.get()

                        return statusline.combine_groups({
                            { hl = mode_hl,                  strings = { mode } },
                            { hl = 'MiniStatuslineDevinfo',  strings = { git, diff, diagnostics, lsp } },
                            '%<',
                            { hl = 'MiniStatuslineFilename', strings = { filename } },
                            '%=',
                            { hl = 'MiniStatuslineDevinfo',  strings = { cc } },
                            { hl = 'MiniStatuslineFileinfo', strings = { fileinfo } },
                            { hl = mode_hl,                  strings = { search, location } },
                        })
                    end,
                },
            }

            vim.api.nvim_set_hl(0, 'MiniStatuslineModeNormal', { link = 'DiffChange', default = true })
        end
    },
}
