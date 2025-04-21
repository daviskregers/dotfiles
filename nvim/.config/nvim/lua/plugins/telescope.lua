-- :checkhealth telescope
return {
    {
        'nvim-telescope/telescope.nvim',
        dependencies = {
            'nvim-lua/plenary.nvim',
            { 'nvim-telescope/telescope-fzf-native.nvim', build = 'make' }
        },
        config = function()
            require('telescope').setup {
                defaults = {
                    file_ignore_patterns = {
                        '.git/',
                    },
                },
                pickers = {
                    find_files = {
                        theme = "ivy",
                        hidden = true,
                    },
                    live_grep = {
                        theme = "ivy",
                        hidden = true,
                    },
                    help_tags = {
                        theme = "ivy",
                        hidden = true,
                    }
                },
                extensions = {
                    fzf = {}
                }
            }

            require('telescope').load_extension('fzf')
            require('config.telescope.multigrep').setup {}

            vim.keymap.set("n", "<C-p>", require('telescope.builtin').find_files, { desc = 'Telescope find files' })
            -- vim.keymap.set('n', '<leader>ps', require('telescope.builtin').live_grep, { desc = 'Telescope live grep' })
            vim.keymap.set('n', '<leader>ph', require('telescope.builtin').help_tags, { desc = 'Telescope help' })
            vim.keymap.set("n", "<leader>pc", function()
                require('telescope.builtin').find_files {
                    cwd = vim.fn.stdpath("config")
                }
            end)
            vim.keymap.set("n", "<leader>pp", function()
                require('telescope.builtin').find_files {
                    cwd = vim.fs.joinpath(vim.fn.stdpath("data"), "lazy")
                }
            end)
        end,
    }
}
