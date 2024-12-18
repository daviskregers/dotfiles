local SymbolKind = vim.lsp.protocol.SymbolKind

return {
    {
        {
            'VonHeikemen/lsp-zero.nvim',
            branch = 'v3.x',
            lazy = true,
            config = false,
            init = function()
                -- Disable automatic setup, we are doing it manually
                vim.g.lsp_zero_extend_cmp = 0
                vim.g.lsp_zero_extend_lspconfig = 0
            end,
        },
        {
            'williamboman/mason.nvim',
            lazy = false,
            config = true,
        },

        -- Autocompletion
        {
            'hrsh7th/nvim-cmp',
            event = 'InsertEnter',
            dependencies = {
                { 'saadparwaiz1/cmp_luasnip' },
                { 'L3MON4D3/LuaSnip' },
                { 'honza/vim-snippets' },
            },
            config = function()
                -- Here is where you configure the autocompletion settings.
                local lsp_zero = require('lsp-zero')
                lsp_zero.extend_cmp()

                -- And you can configure cmp even more, if you want to.
                local cmp = require('cmp')
                local cmp_action = require('lsp-zero').cmp_action()

                local snipmate = require('luasnip.loaders.from_snipmate')
                snipmate.lazy_load()
                snipmate.load({ paths = './snippets' })

                local vscode = require('luasnip.loaders.from_vscode')
                vscode.lazy_load()

                cmp.setup({
                    sources = {
                        { name = 'nvim_lsp' },
                        { name = 'luasnip' },
                    },
                    mapping = cmp.mapping.preset.insert({
                        -- `Enter` key to confirm completion
                        ['<CR>'] = cmp.mapping.confirm({ select = false }),

                        -- Ctrl+Space to trigger completion menu
                        ['<C-Space>'] = cmp.mapping.complete(),

                        -- Navigate between snippet placeholder
                        ['<C-f>'] = cmp_action.luasnip_jump_forward(),
                        ['<C-b>'] = cmp_action.luasnip_jump_backward(),

                        -- Scroll up and down in the completion documentation
                        ['<C-u>'] = cmp.mapping.scroll_docs(-4),
                        ['<C-d>'] = cmp.mapping.scroll_docs(4),
                    })
                })
            end
        },

        -- LSP
        {
            'neovim/nvim-lspconfig',
            cmd = { 'LspInfo', 'LspInstall', 'LspStart' },
            event = { 'BufReadPre', 'BufNewFile' },
            dependencies = {
                { 'hrsh7th/cmp-nvim-lsp' },
                { 'williamboman/mason-lspconfig.nvim' },
            },
            config = function()
                -- This is where all the LSP shenanigans will live
                local lsp_zero = require('lsp-zero')
                lsp_zero.extend_lspconfig()

                lsp_zero.on_attach(function(_client, bufnr)
                    lsp_zero.default_keymaps({ buffer = bufnr })

                    vim.keymap.set("n", "gd", vim.lsp.buf.definition,
                        { buffer = bufnr, remap = false, desc = "go to definition" })
                    vim.keymap.set("n", "K", vim.lsp.buf.hover, { buffer = bufnr, remap = false, desc = "hover" })
                    vim.keymap.set("n", "<leader>vws", vim.lsp.buf.workspace_symbol,
                        { buffer = bufnr, remap = false, desc = "workspace symbol" })
                    vim.keymap.set("n", "<leader>vd", vim.diagnostic.open_float,
                        { buffer = bufnr, remap = false, desc = "open diagnostic float" })
                    vim.keymap.set("n", "[d", vim.diagnostic.goto_next,
                        { buffer = bufnr, remap = false, desc = "next diagnostic error" })
                    vim.keymap.set("n", "]d", vim.diagnostic.goto_prev,
                        { buffer = bufnr, remap = false, desc = "prev diagnostic error" })
                    vim.keymap.set("n", "<leader>vca", vim.lsp.buf.code_action,
                        { buffer = bufnr, remap = false, desc = "code action" })
                    vim.keymap.set("n", "<leader>vrr", vim.lsp.buf.references,
                        { buffer = bufnr, remap = false, desc = "references" })
                    vim.keymap.set("n", "<leader>vrn", vim.lsp.buf.rename,
                        { buffer = bufnr, remap = false, desc = "rename" })
                    vim.keymap.set("i", "<C-h>", vim.lsp.buf.signature_help,
                        { buffer = bufnr, remap = false, desc = "signature help" })

                    vim.keymap.set({ 'n', 'x' }, '<leader>f', function()
                        vim.lsp.buf.format({ async = false, timeout_ms = 10000 })
                    end, { desc = "Format file" })
                end)

                require('mason-lspconfig').setup({
                    ensure_installed = {},
                    handlers = {
                        lsp_zero.default_setup,
                        lua_ls = function()
                            -- (Optional) Configure lua language server for neovim
                            local lua_opts = lsp_zero.nvim_lua_ls()
                            require('lspconfig').lua_ls.setup(lua_opts)
                        end,
                        omnisharp = function()
                            local lua_opts = lsp_zero.nvim_lua_ls()
                            require('lspconfig').omnisharp.setup({
                                capabilities = lua_opts.capabilities,
                                -- cmd = { omnisharp_bin, "--languageserver", "--hostPID", tostring(pid) },
                                on_attach = function(_client, bufnr)
                                    -- Enable completion triggered by <c-x><c-o>
                                    vim.api.nvim_buf_set_option(bufnr, 'omnifunc', 'v:lua.vim.lsp.omnifunc')
                                    local opts = { noremap = true, silent = true }

                                    -- Mappings.
                                    -- See `:help vim.lsp.*` for documentation on any of the below functions
                                    vim.api.nvim_buf_set_keymap(bufnr, 'n', 'gD',
                                        '<cmd>lua vim.lsp.buf.declaration()<CR>', opts)
                                    vim.api.nvim_buf_set_keymap(bufnr, 'n', 'gd', '<cmd>lua vim.lsp.buf.definition()<CR>',
                                        opts)
                                    vim.api.nvim_buf_set_keymap(bufnr, 'n', 'K', '<cmd>lua vim.lsp.buf.hover()<CR>', opts)
                                    vim.api.nvim_buf_set_keymap(bufnr, 'n', 'gi',
                                        '<cmd>lua vim.lsp.buf.implementation()<CR>', opts)
                                    vim.api.nvim_buf_set_keymap(bufnr, 'n', '<C-k>',
                                        '<cmd>lua vim.lsp.buf.signature_help()<CR>', opts)
                                    vim.api.nvim_buf_set_keymap(bufnr, 'n', '<space>wa',
                                        '<cmd>lua vim.lsp.buf.add_workspace_folder()<CR>', opts)
                                    vim.api.nvim_buf_set_keymap(bufnr, 'n', '<space>wr',
                                        '<cmd>lua vim.lsp.buf.remove_workspace_folder()<CR>', opts)
                                    vim.api.nvim_buf_set_keymap(bufnr, 'n', '<space>wl',
                                        '<cmd>lua print(vim.inspect(vim.lsp.buf.list_workspace_folders()))<CR>', opts)
                                    vim.api.nvim_buf_set_keymap(bufnr, 'n', '<space>D',
                                        '<cmd>lua vim.lsp.buf.type_definition()<CR>', opts)
                                    vim.api.nvim_buf_set_keymap(bufnr, 'n', '<space>rn',
                                        '<cmd>lua vim.lsp.buf.rename()<CR>', opts)
                                    vim.api.nvim_buf_set_keymap(bufnr, 'n', '<space>ca',
                                        '<cmd>lua vim.lsp.buf.code_action()<CR>', opts)
                                    vim.api.nvim_buf_set_keymap(bufnr, 'n', 'gr', '<cmd>lua vim.lsp.buf.references()<CR>',
                                        opts)
                                    vim.api.nvim_buf_set_keymap(bufnr, 'n', '<space>f',
                                        '<cmd>lua vim.lsp.buf.formatting()<CR>', opts)
                                end
                            })
                        end
                    }
                })
            end
        },

        -- typescript
        {
            'lukahartwig/pnpm.nvim',
            dependencies = {
                { 'nvim-telescope/telescope.nvim' }
            },
            config = function()
                local telescope = require('telescope')
                telescope.load_extension('pnpm')
                vim.keymap.set('n', '<leader>pw', telescope.extensions.pnpm.workspace, { desc = "Switch pnpm workspace" })
            end
        },
        {
            "vuki656/package-info.nvim",
            dependencies = { "MunifTanjim/nui.nvim" },
            config = true
        },

        -- diagnostics
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
        {
            'VidocqH/lsp-lens.nvim',
            config = function()
                require('lsp-lens').setup({
                    enable = true,
                    include_declaration = true, -- Reference include declaration
                    sections = {                -- Enable / Disable specific request, formatter example looks 'Format Requests'
                        definition = true,
                        references = true,
                        implements = true,
                        git_authors = false,
                    },
                    -- ignore_filetype = {
                    --     "prisma",
                    -- },
                    -- Target Symbol Kinds to show lens information
                    -- target_symbol_kinds = { SymbolKind.Function, SymbolKind.Method, SymbolKind.Interface },
                    -- Symbol Kinds that may have target symbol kinds as children
                    -- wrapper_symbol_kinds = { SymbolKind.Class, SymbolKind.Struct },
                })
            end,
        },
        {
            'dnlhc/glance.nvim',
            config = function()
                vim.keymap.set('n', 'gD', '<CMD>Glance definitions<CR>')
                vim.keymap.set('n', 'gR', '<CMD>Glance references<CR>')
                vim.keymap.set('n', 'gY', '<CMD>Glance type_definitions<CR>')
                vim.keymap.set('n', 'gM', '<CMD>Glance implementations<CR>')
                local glance = require('glance')

                glance.setup()
            end,
        },
        -- {
        --     dir = '~/.config/nvim/lua/plugin/remove-php-imports',
        --     name = 'remove-php-imports',
        --     ft = 'php',
        --     config = function()
        --         require('plugin.remove-php-imports').setup()
        --     end
        -- }
    }
}
