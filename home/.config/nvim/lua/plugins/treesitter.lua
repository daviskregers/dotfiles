return {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    config = function()
        local configs = require("nvim-treesitter.configs")

        configs.setup({
            ensure_installed = { "c", "lua", "vim", "vimdoc", "query", "javascript", "html", "typescript", "php", "bash", "luadoc", "make", "markdown", "markdown_inline", "phpdoc", "python", "rust", "sql", "terraform", "toml", "vue" },
            sync_install = false,
            highlight = { enable = true },
            indent = { enable = true },
        })
    end
}
