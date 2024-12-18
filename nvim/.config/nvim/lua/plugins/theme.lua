return {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    lazy = false,
    opts = {
        flavour = "mocha",
        term_colors = true,
        transparent_background = false,
        no_italic = false,
        no_bold = false,
        styles = {
            comments = {},
            conditionals = {},
            loops = {},
            functions = {},
            keywords = {},
            strings = {},
            variables = {},
            numbers = {},
            booleans = {},
            properties = {},
            types = {},
        },
        color_overrides = {
            mocha = {
                base = "#000000",
                mantle = "#000000",
                crust = "#000000",
            },
        },
        highlight_overrides = {
            mocha = function(C)
                return {
                    TabLineSel = { bg = C.pink },
                    CmpBorder = { fg = C.surface2 },
                    Pmenu = { bg = C.none },
                    TelescopeBorder = { link = "FloatBorder" },
                }
            end,
        },
    },
    config = true,
    init = function(plugin)
        vim.cmd.colorscheme "catppuccin"

        vim.api.nvim_set_hl(0, 'BlameLineNvim', { fg = "#4c4c4c" })
        vim.api.nvim_set_hl(0, 'Comment', { fg = "#D33257" })
        vim.api.nvim_set_hl(0, 'ExtraWhitespace', { bg = "red" })
        vim.api.nvim_set_hl(0, 'ColorColumn', { bg = "#380a09" })
        vim.api.nvim_set_hl(0, 'DiffDelete', { bg = "red" })

        vim.api.nvim_create_augroup("highlight_yank", { clear = true })
        vim.api.nvim_create_autocmd("TextYankPost", {
            group = "highlight_yank",
            pattern = { "*" },
            command = 'silent! lua vim.highlight.on_yank{higroup="IncSearch", timeout=300}',
        })
    end
}
