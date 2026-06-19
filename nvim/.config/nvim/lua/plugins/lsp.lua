vim.pack.add({
    'https://github.com/mason-org/mason.nvim',
})

require("mason").setup()

local registry = require("mason-registry")
local function ensure_installed(packages)
    registry.refresh(function()
        for _, name in ipairs(packages) do
            local pkg = registry.get_package(name)
            if not pkg:is_installed() then
                pkg:install()
            end
        end
    end)
end

ensure_installed({
    "elixir-ls",
    "eslint-lsp",
    "gopls",
    "intelephense",
    "lua-language-server",
    "omnisharp",
    "pyright",
    "stylua",
    "typescript-language-server",
    "vue-language-server",
})

vim.keymap.set('n', 'gd', vim.lsp.buf.definition, { desc = "Go to definition" })
vim.keymap.set("n", '<leader>f', vim.lsp.buf.format, { desc = "Format Local buffer" })
vim.keymap.set("n", "<leader>pd", vim.diagnostic.open_float, { desc = "Show line diagnostics" })

vim.diagnostic.config({
    virtual_text = {
        prefix = '●', -- Could be '■', '▎', 'x'
        source = "always", -- Or "if_many"
    },
    severity_sort = true,
    float = {
        source = "always", -- Or "if_many"
    },
    signs = true,
    underline = true,
})

local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities = vim.tbl_deep_extend("force", capabilities, require("blink.cmp").get_lsp_capabilities())

vim.lsp.config("*", { capabilities = capabilities })
vim.lsp.config("lua_ls", {
    cmd = { "lua-language-server" },
    filetypes = { "lua" },
    root_markers = { ".luarc.json", ".luarc.jsonc", ".git" },
    settings = {
        Lua = {
            diagnostics = { globals = { "vim" } },
        },
    },
})
vim.lsp.config("gopls", {
    cmd = { "gopls" },
    filetypes = { "go", "gomod", "gowork", "gotmpl" },
    root_markers = { "go.work", "go.mod", ".git" },
})
vim.lsp.config("intelephense", {
    cmd = { "intelephense", "--stdio" },
    filetypes = { "php" },
    root_markers = { "composer.json", ".git" },
})
local mason_pkgs = vim.fn.stdpath("data") .. "/mason/packages"

-- TypeScript/JS, plus Vue <script> via the @vue/typescript-plugin (volar hybrid mode).
vim.lsp.config("typescript", {
    cmd = { "typescript-language-server", "--stdio" },
    filetypes = {
        "javascript", "javascriptreact",
        "typescript", "typescriptreact",
        "vue",
    },
    root_markers = { "tsconfig.json", "jsconfig.json", "package.json", ".git" },
    init_options = {
        plugins = {
            {
                name = "@vue/typescript-plugin",
                location = mason_pkgs .. "/vue-language-server/node_modules/@vue/typescript-plugin",
                languages = { "vue" },
            },
        },
    },
})
-- Vue templates (volar). Delegates <script> TS to the typescript server above.
vim.lsp.config("vue_ls", {
    cmd = { "vue-language-server", "--stdio" },
    filetypes = { "vue" },
    root_markers = { "package.json", ".git" },
    init_options = {
        typescript = {
            tsdk = mason_pkgs .. "/typescript-language-server/node_modules/typescript/lib",
        },
    },
})
vim.lsp.config("pyright", {
    cmd = { "pyright-langserver", "--stdio" },
    filetypes = { "python" },
    root_markers = {
        "pyproject.toml", "setup.py", "setup.cfg",
        "requirements.txt", "Pipfile", "pyrightconfig.json", ".git",
    },
})
vim.lsp.config("elixirls", {
    cmd = { "elixir-ls" },
    filetypes = { "elixir", "eelixir", "heex", "surface" },
    root_markers = { "mix.exs", ".git" },
})
vim.lsp.config("omnisharp", {
    cmd = { "OmniSharp" }, -- requires the .NET SDK (`dotnet`) on PATH at runtime
    filetypes = { "cs", "vb" },
    root_markers = { "*.sln", "*.csproj", "omnisharp.json", ".git" },
})
-- ESLint diagnostics/fixes; complements the typescript server (lint rules, not language features).
vim.lsp.config("eslint", {
    cmd = { "vscode-eslint-language-server", "--stdio" },
    filetypes = {
        "javascript", "javascriptreact",
        "typescript", "typescriptreact",
        "vue", "svelte", "astro",
    },
    root_markers = {
        ".eslintrc", ".eslintrc.js", ".eslintrc.cjs", ".eslintrc.json",
        ".eslintrc.yaml", ".eslintrc.yml",
        "eslint.config.js", "eslint.config.mjs", "eslint.config.cjs", "eslint.config.ts",
        "package.json", ".git",
    },
    -- eslint resolves its working dir from settings.workspaceFolder; inject the
    -- resolved root (raw path) or it fails with "path argument must be of type string".
    before_init = function(_, config)
        local root_dir = config.root_dir
        if root_dir then
            config.settings = config.settings or {}
            config.settings.workspaceFolder = {
                uri = root_dir,
                name = vim.fn.fnamemodify(root_dir, ":t"),
            }
        end
    end,
    settings = {
        validate = "on",
        useESLintClass = false,
        experimental = {},
        format = true,
        quiet = false,
        onIgnoredFiles = "off",
        run = "onType",
        problems = { shortenToSingleLine = false },
        nodePath = "",
        workingDirectory = { mode = "auto" },
        codeAction = {
            disableRuleComment = { enable = true, location = "separateLine" },
            showDocumentation = { enable = true },
        },
    },
    handlers = {
        ["eslint/openDoc"] = function(_, result)
            if result then vim.ui.open(result.url) end
            return {}
        end,
        ["eslint/confirmESLintExecution"] = function(_, result)
            if not result then return end
            return 4 -- approved
        end,
        ["eslint/probeFailed"] = function()
            vim.notify("ESLint probe failed.", vim.log.levels.WARN)
            return {}
        end,
        ["eslint/noLibrary"] = function()
            vim.notify("Unable to find ESLint library.", vim.log.levels.WARN)
            return {}
        end,
    },
})
vim.lsp.enable({
    "lua_ls",
    "intelephense",
    "gopls",
    "typescript",
    "vue_ls",
    "pyright",
    "elixirls",
    "omnisharp",
    "eslint",
})

vim.api.nvim_create_user_command("LspInfo", "checkhealth vim.lsp", {})

vim.api.nvim_create_autocmd("LspAttach", {
    callback = function(args)
        local client = vim.lsp.get_client_by_id(args.data.client_id)
        if not client then
            print("For some reason we attached client that is nil")
            return
        end

        -- local opts = { buffer = args.buf }
        -- local term_opener = require("plugins.terminal-open-file")

        -- vim.keymap.set("n", "gd", function()
        --     print("hello!")
        --     if term_opener.is_terminal_buffer() then
        --         term_opener.open_file_under_cusror()
        --         return
        --     end
        --     vim.lsp.buf.definition()
        -- end, opts)

        if client:supports_method("textDocument/formatting") then
            vim.api.nvim_create_autocmd("BufWritePre", {
                buffer = args.buf,
                callback = function()
                    if CONFIG_DISABLE_FORMATTING then
                        return
                    end
                    vim.lsp.buf.format({ bufnr = args.buf, id = client.id })
                end,
            })
        end
    end,
})
