vim.pack.add({
    'https://github.com/lukas-reineke/indent-blankline.nvim',
})

require("ibl").setup({
    scope = { enabled = false },                   -- drop the brighter active-scope guide
    whitespace = { highlight = { "Whitespace" } }, -- read live Whitespace, not cached IblWhitespace
})
