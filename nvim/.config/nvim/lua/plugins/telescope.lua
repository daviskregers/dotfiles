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
            require("telescope").load_extension("rest")
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
            vim.keymap.set("n", "<leader>pa", function()
                local files = {}
                for _, dir in ipairs({ ".ai-artifacts", ".reviews" }) do
                    if vim.fn.isdirectory(dir) == 1 then
                        for name, type in vim.fs.dir(dir, { depth = 10 }) do
                            if type == "file" then
                                local path = dir .. "/" .. name
                                local stat = vim.uv.fs_stat(path)
                                if stat then
                                    table.insert(files, { path = path, mtime = stat.mtime.sec })
                                end
                            end
                        end
                    end
                end
                if #files == 0 then
                    vim.notify("No .ai-artifacts or .reviews files found", vim.log.levels.INFO)
                    return
                end
                table.sort(files, function(a, b) return a.mtime > b.mtime end)
                local paths = {}
                for _, f in ipairs(files) do
                    table.insert(paths, f.path)
                end
                local pickers = require('telescope.pickers')
                local finders = require('telescope.finders')
                local conf = require('telescope.config').values
                local previewers = require('telescope.previewers')
                pickers.new(require('telescope.themes').get_ivy({}), {
                    prompt_title = "AI artifacts / reviews (mtime desc)",
                    finder = finders.new_table {
                        results = paths,
                        entry_maker = function(entry)
                            return {
                                value = entry,
                                display = entry,
                                ordinal = entry,
                                path = entry,
                            }
                        end,
                    },
                    sorter = conf.generic_sorter({}),
                    previewer = conf.file_previewer({}),
                }):find()
            end, { desc = "Telescope ai artifacts/reviews" })
        end,
    }
}
