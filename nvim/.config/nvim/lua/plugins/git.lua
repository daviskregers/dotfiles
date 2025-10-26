return {
    {
        "NeogitOrg/neogit",
        dependencies = {
            "nvim-lua/plenary.nvim",
            "sindrets/diffview.nvim",
            "nvim-telescope/telescope.nvim",
        },
        config = true,
        keys = {
            {
                "<leader>gg",
                function() require("neogit").open() end,
                desc = "Open NeoGit",
            }
        }
    },
    {
        "lewis6991/gitsigns.nvim",
        config = function()
            require('gitsigns').setup({
                signs = {
                    add          = { text = '│' },
                    change       = { text = '│' },
                    delete       = { text = '_' },
                    topdelete    = { text = '‾' },
                    changedelete = { text = '~' },
                    untracked    = { text = '┆' },
                },
                current_line_blame = true,
                on_attach = function(bufnr)
                    local gs = package.loaded.gitsigns

                    local function map(mode, l, r, opts)
                        opts = opts or {}
                        opts.buffer = bufnr
                        vim.keymap.set(mode, l, r, opts)
                    end

                    -- Navigation
                    map('n', ']h', function()
                        if vim.wo.diff then return ']c' end
                        vim.schedule(function() gs.next_hunk() end)
                        return '<Ignore>'
                    end, { expr = true, desc = 'next hunk' })

                    map('n', '[h', function()
                        if vim.wo.diff then return '[c' end
                        vim.schedule(function() gs.prev_hunk() end)
                        return '<Ignore>'
                    end, { expr = true, desc = 'prev hunk' })

                    map('n', '<leader>gs', gs.stage_hunk, { desc = "git - stage hunk" })
                    map('n', '<leader>gr', gs.reset_hunk, { desc = "git - reset hunk" })
                    map('v', '<leader>gs', function() gs.stage_hunk { vim.fn.line('.'), vim.fn.line('v') } end,
                        { desc = "git - stage hunk" })
                    map('v', '<leader>gr', function() gs.reset_hunk { vim.fn.line('.'), vim.fn.line('v') } end,
                        { desc = "git - reset hunk" })
                    map('n', '<leader>gS', gs.stage_buffer, { desc = "git - stage buffer" })
                    map('n', '<leader>gu', gs.undo_stage_hunk, { desc = "git - undo stage hunk" })
                    map('n', '<leader>gR', gs.reset_buffer, { desc = "git - reset buffer" })
                    map('n', '<leader>gp', gs.preview_hunk, { desc = "git - preview hunk" })
                    map('n', '<leader>gb', function() gs.blame_line { full = true } end, { desc = "git - blameline" })
                    map('n', '<leader>gb', gs.blame, { desc = "git - blame" })
                    map('n', '<leader>gB', gs.toggle_current_line_blame, { desc = "git - blame current line" })
                    map('n', '<leader>gd', gs.diffthis, { desc = "git - diff" })
                    map('n', '<leader>gD', function() gs.diffthis('~') end, { desc = "git - diff" })
                    map('n', '<leader>gt', gs.toggle_deleted, { desc = "git - toggle deleted" })

                    map({ 'o', 'x' }, 'ih', ':<C-U>Gitsigns select_hunk<CR>', { desc = "git - select hunk" })
                end
            })
        end
    },
    {
        {
            "FabijanZulj/blame.nvim",
            lazy = false,
            config = function()
                require('blame').setup {}
            end,
        },
    }
}
