vim.pack.add {
    { src = "https://github.com/romus204/tree-sitter-manager.nvim" }
}

vim.treesitter.language.register("python", "tiltfile")

require("tree-sitter-manager").setup({
    -- Default Options
    parser_dir = vim.fn.stdpath("data") .. "/site/parser",
    query_dir = vim.fn.stdpath("data") .. "/site/queries",
    assume_installed = {}, -- blacklist languages
    ensure_installed = {
        "c", "lua", "vim", "vimdoc", "query",
        "markdown", "markdown_inline", "python", "yaml",
        "typescript", "mermaid",
    }, -- parsers to install at startup
    -- border = "rounded", -- border style for the TUI window
    -- auto_install = false, -- auto-install when a new filetype is encountered
    -- noauto_install = {}, -- blacklist from auto_install
    -- highlight = true, -- enable treesitter highlighting (use list to whitelist)
    -- nohighlight = {}, -- blacklist from highlight
    -- languages = {}, -- override or add new parser sources
    nerdfont = true, -- use Nerd Font icons in the manager UI
})

vim.api.nvim_create_autocmd("FileType", {
    pattern = "*",
    callback = function(args)
        local buf = args.buf
        local ft = vim.bo[buf].filetype

        local lang = vim.treesitter.language.get_lang(ft)
        if not lang then
            return
        end

        local ok_add = pcall(vim.treesitter.language.add, lang)
        if not ok_add then
            return
        end

        pcall(vim.treesitter.start, buf, lang)
    end,
})
