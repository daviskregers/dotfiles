vim.pack.add({ 'https://github.com/dgox16/oldworld.nvim' })

require("oldworld").setup({
    terminal_colors = true, -- enable terminal colors
    variant = "oled",       -- default, oled, cooler
    -- styles = {              -- You can pass the style using the format: style = true
    --     comments = {},      -- style for comments
    --     keywords = {},      -- style for keywords
    --     identifiers = {},   -- style for identifiers
    --     functions = {},     -- style for functions
    --     variables = {},     -- style for variables
    --     booleans = {},      -- style for booleans
    -- },
    -- integrations = {        -- You can disable/enable integrations
    --     alpha = true,
    --     cmp = true,
    --     flash = true,
    --     gitsigns = true,
    --     hop = false,
    --     indent_blankline = true,
    --     lazy = true,
    --     lsp = true,
    --     markdown = true,
    --     mason = true,
    --     navic = false,
    --     neo_tree = false,
    --     neogit = false,
    --     neorg = false,
    --     noice = true,
    --     notify = true,
    --     rainbow_delimiters = true,
    --     telescope = true,
    --     treesitter = true,
    -- },
    -- highlight_overrides = {}
})

vim.cmd.colorscheme("oldworld")

local function set_whitespace()
    vim.api.nvim_set_hl(0, "Whitespace", { fg = "#2a2a2a" })
    pcall(function() require("ibl.highlights").setup() end)
end

vim.api.nvim_create_autocmd("ColorScheme", { callback = set_whitespace })
set_whitespace()
