return {
    {
        'saghen/blink.cmp',
        dependencies = 'rafamadriz/friendly-snippets',

        version = 'v0.*',

        ---@module 'blink.cmp'
        ---@type blink.cmp.Config
        opts = {
            keymap = { preset = 'default' },

            appearance = {
                use_nvim_cmp_as_default = true,
                nerd_font_variant = 'mono'
            },

            signature = { enabled = true },

            sources = {
                default = { 'lsp', 'path', 'snippets', 'buffer' },
                per_filetype = {
                    sql = { 'dadbod', 'buffer' },
                    mysql = { 'dadbod', 'buffer' },
                    plsql = { 'dadbod', 'buffer' },
                    codecompanion = { 'codecompanion' },
                    codecompanion_input = { 'codecompanion' },
                },
                providers = {
                    dadbod = {
                        name = 'Dadbod',
                        module = 'vim_dadbod_completion.blink',
                        score_offset = 85,
                    },
                    codecompanion = {
                        name = 'CodeCompanion',
                        module = 'codecompanion.providers.completion.blink',
                        score_offset = 100,
                    },
                },
            },
        },
    }
}
