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
            require("mason-lspconfig").setup()
            require("mason-lspconfig").setup_handlers {
                function(server_name) -- default handler (optional)
                    require("lspconfig")[server_name].setup {}
                end,
            }


            lspconfig.lua_ls.setup { capabilities = capabilities }
            lspconfig.gopls.setup {}
            lspconfig.intelephense.setup {}

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
