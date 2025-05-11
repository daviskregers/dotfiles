-- :h lspconfig-all
--
-- :echo executable('lua-language-server')
-- ^ if returns 1, neovim can find it.
--
-- :help lsp
-- CTRL-X CTRL-O - omnicompletion
-- CTRL-] - jump to definition
-- =G format file
return {
    {
        "neovim/nvim-lspconfig",
        dependencies = {
            {
                "folke/lazydev.nvim",
                ft = "lua",
                opts = {
                    library = {
                        { path = "${3rd}/luv/library", words = { "vim%.uv" } },
                    }
                }
            },
            "saghen/blink.cmp",
            "williamboman/mason.nvim",
            "williamboman/mason-lspconfig.nvim",
        },
        config = function()
            local capabilities = require("blink.cmp").get_lsp_capabilities()
            local lspconfig = require("lspconfig")

            require("mason").setup()
            require("mason-lspconfig").setup {
                automatic_enable = true,
            }

            lspconfig.lua_ls.setup { capabilities = capabilities }
            lspconfig.gopls.setup {}
            lspconfig.intelephense.setup {}
            lspconfig.omnisharp.setup {
                settings = {
                    FormattingOptions = {
                        -- Enables support for reading code style, naming convention and analyzer
                        -- settings from .editorconfig.
                        EnableEditorConfigSupport = true,
                        -- Specifies whether 'using' directives should be grouped and sorted during
                        -- document formatting.
                        OrganizeImports = true,
                    },
                    MsBuild = {
                        -- If true, MSBuild project system will only load projects for files that
                        -- were opened in the editor. This setting is useful for big C# codebases
                        -- and allows for faster initialization of code navigation features only
                        -- for projects that are relevant to code that is being edited. With this
                        -- setting enabled OmniSharp may load fewer projects and may thus display
                        -- incomplete reference lists for symbols.
                        LoadProjectsOnDemand = false,
                    },
                    RoslynExtensionsOptions = {
                        -- Enables support for roslyn analyzers, code fixes and rulesets.
                        EnableAnalyzersSupport = true,
                        -- Enables support for showing unimported types and unimported extension
                        -- methods in completion lists. When committed, the appropriate using
                        -- directive will be added at the top of the current file. This option can
                        -- have a negative impact on initial completion responsiveness,
                        -- particularly for the first few completion sessions after opening a
                        -- solution.
                        EnableImportCompletion = true,
                        -- Only run analyzers against open files when 'enableRoslynAnalyzers' is
                        -- true
                        AnalyzeOpenDocumentsOnly = false,
                    },
                    Sdk = {
                        -- Specifies whether to include preview versions of the .NET SDK when
                        -- determining which version to use for project loading.
                        IncludePrereleases = true,
                    },
                },
            }

            vim.keymap.set("n", "<leader>f", function() vim.lsp.buf.format() end)

            vim.api.nvim_create_autocmd('LspAttach', {
                callback = function(args)
                    local opts = { buffer = args.buf }

                    vim.keymap.set("i", "<C-h>", function() vim.lsp.buf.signature_help() end, opts)
                    vim.keymap.set("n", "K", function() vim.lsp.buf.hover() end, opts)
                    vim.keymap.set("n", "[d", function() vim.diagnostic.goto_next() end, opts)
                    vim.keymap.set("n", "]d", function() vim.diagnostic.goto_prev() end, opts)
                    vim.keymap.set("n", "gca", function() vim.lsp.buf.code_action() end, opts)
                    vim.keymap.set("n", "gd", function() vim.lsp.buf.definition() end, opts)
                    vim.keymap.set("n", "grn", function() vim.lsp.buf.rename() end, opts)
                    vim.keymap.set("n", "grr", function() vim.lsp.buf.references() end, opts)
                    vim.keymap.set("n", "gvd", function() vim.diagnostic.open_float() end, opts)
                    vim.keymap.set("n", "gws", function() vim.lsp.buf.workspace_symbol() end, opts)

                    local client = vim.lsp.get_client_by_id(args.data.client_id)
                    if not client then
                        print("For some reason we attached client that is nil")
                        return
                    end

                    if client.supports_method('textDocument/formatting') then
                        vim.api.nvim_create_autocmd('BufWritePre', {
                            buffer = args.buf,
                            callback = function()
                                if CONFIG_DISABLE_FORMATTING then
                                    return
                                end
                                vim.lsp.buf.format({ bufnr = args.buf, id = client.id })
                            end,
                        })
                    end
                end
            })
        end
    },
    {
        'https://git.sr.ht/~whynothugo/lsp_lines.nvim',
        config = function()
            require('lsp_lines').setup()
            vim.keymap.set(
                '',
                '<Leader>dl',
                require('lsp_lines').toggle,
                { desc = 'Toggle lsp_lines' }
            )
        end,
    },
}
