local mason_status_ok, mason = pcall(require, "mason")
if not mason_status_ok then
    vim.notify("Error loading mason")
    return
end

local null_ls_status_ok, null_ls = pcall(require, "null-ls")
if not null_ls_status_ok then
    vim.notify("Error loading null-ls")
    return
end

local mason_null_ls_status_ok, mason_null_ls = pcall(require, "mason-null-ls")
if not mason_null_ls_status_ok then
    vim.notify("Error loading mason-null-ls")
    return
end

-- TODO: this should be elsewhere
mason.setup()

-- https://github.com/jose-elias-alvarez/null-ls.nvim/tree/main/lua/null-ls/builtins/
local code_actions = null_ls.builtins.code_actions
local completion = null_ls.builtins.completion
local diagnostics = null_ls.builtins.diagnostics
local formatting = null_ls.builtins.formatting

null_ls.setup {
    debug = false,
    sources = {
        code_actions.eslint_d,
        code_actions.gitsigns,

        completion.luasnip,

        diagnostics.actionlint,
        diagnostics.ansiblelint,
        diagnostics.checkmake,
        diagnostics.codespell,
        diagnostics.cppcheck,
        diagnostics.credo,
        diagnostics.djlint,
        diagnostics.editorconfig_checker,
        diagnostics.eslint_d,
        diagnostics.flake8,
        diagnostics.gitlint,
        diagnostics.golangci_lint,
        diagnostics.jsonlint,
        diagnostics.markdownlint,
        diagnostics.php,
        diagnostics.phpcs,
        diagnostics.phpmd.with { extra_args = { "$FILENAME", "json", "phpmd.xml" } },
        diagnostics.phpstan,
        diagnostics.psalm,
        diagnostics.revive,
        diagnostics.rubocop,
        diagnostics.selene,
        diagnostics.semgrep,
        diagnostics.sqlfluff,
        diagnostics.stylelint,
        diagnostics.stylint,
        diagnostics.trail_space,
        diagnostics.tsc,
        diagnostics.vulture,

        formatting.autopep8,
        formatting.beautysh,
        formatting.black.with { extra_args = { "--fast" } },
        formatting.blade_formatter,
        formatting.brittany,
        formatting.cmake_format,
        formatting.djlint,
        formatting.eslint_d,
        formatting.fixjson,
        formatting.gofumpt,
        formatting.goimports,
        formatting.google_java_format,
        formatting.isort,
        formatting.json_tool,
        formatting.markdownlint,
        formatting.mix,
        formatting.nginx_beautifier,
        formatting.pg_format,
        formatting.phpcbf,
        formatting.phpcsfixer,
        formatting.prettier.with { extra_args = { "--no-semi", "--single-quote", "--jsx-single-quote" } },
        formatting.prettierd,
        formatting.rubocop,
        formatting.rustfmt,
        formatting.shellharden,
        formatting.shfmt,
        formatting.sqlfluff,
        formatting.sqlformat,
        formatting.stylelint,
        formatting.terraform_fmt,
        formatting.tidy,
        formatting.trim_newlines,
        formatting.trim_whitespace,
        formatting.uncrustify,
        formatting.xmllint,
    },
    update_in_insert = true,
}

mason_null_ls.setup({
    ensure_installed = {
        'editorconfig-checker',
        'luacheck',
        'markdownlint',
        'phpcs',
        'phpmd',
        'phpstan',

    },
    automatic_installation = true,
})
