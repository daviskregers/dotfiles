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
                function()
                    require("neogit").open()
                end,
                desc = "Open NeoGit",
            },
            {
                "<leader>gc",
                "<cmd>Neogit branch<CR>",
                desc = "Git branch",
            },
            {
                "<leader>gd",
                "<cmd>Neogit diff<CR>",
                desc = "Git diff",
            },
        },
    },
    {
        "sindrets/diffview.nvim",
        dependencies = {
            { "nvim-tree/nvim-web-devicons" },
        },
        keys = {
            {
                "<leader>gr",
                "<cmd>DiffviewOpen<CR>",
                desc = "Git diffview open",
            },
            {
                "<leader>gq",
                "<cmd>DiffviewClose<CR>",
                desc = "Git diffview close",
            },
        },
    },
    {
        "lewis6991/gitsigns.nvim",
        config = function()
            require("gitsigns").setup({
                signs = {
                    add = { text = "│" },
                    change = { text = "│" },
                    delete = { text = "_" },
                    topdelete = { text = "‾" },
                    changedelete = { text = "~" },
                    untracked = { text = "┆" },
                },
                current_line_blame = true,
                attach_to_untracked = true,
                on_attach = function(bufnr)
                    local gs = package.loaded.gitsigns

                    local function map(mode, l, r, opts)
                        opts = opts or {}
                        opts.buffer = bufnr
                        vim.keymap.set(mode, l, r, opts)
                    end

                    map("n", "<leader>gf", function()
                        local qf_items = {}
                        local git_root = vim.fn.systemlist("git rev-parse --show-toplevel")[1]

                        -- Get hunk locations from git diff (tracked modified files)
                        local diff_output = vim.fn.systemlist("git diff --no-color --unified=0 --no-ext-diff HEAD")
                        local current_file = nil
                        for _, line in ipairs(diff_output) do
                            -- Match file header: +++ b/path/to/file
                            local file = line:match("^%+%+%+ b/(.*)")
                            if file then
                                current_file = file
                            end
                            -- Match hunk header: @@ -old,count +new,count @@
                            if current_file then
                                local lnum = line:match("^@@ %-%d+,?%d* %+(%d+),?%d* @@")
                                if lnum then
                                    table.insert(qf_items, {
                                        filename = git_root .. "/" .. current_file,
                                        lnum = tonumber(lnum),
                                        col = 1,
                                        text = "[modified] " .. (line:match("^@@ .* @@(.*)$") or ""),
                                    })
                                end
                            end
                        end

                        -- Get deleted files
                        local deleted = vim.fn.systemlist(
                            "git -C " .. vim.fn.shellescape(git_root) .. " diff --name-only --diff-filter=D HEAD"
                        )
                        for _, file in ipairs(deleted) do
                            if file ~= "" then
                                table.insert(qf_items, {
                                    filename = git_root .. "/" .. file,
                                    lnum = 1,
                                    col = 1,
                                    text = "[deleted] " .. file,
                                })
                            end
                        end

                        -- Get untracked (new) files
                        local untracked = vim.fn.systemlist(
                            "git -C " .. vim.fn.shellescape(git_root) .. " ls-files --others --exclude-standard"
                        )
                        for _, file in ipairs(untracked) do
                            if file ~= "" then
                                table.insert(qf_items, {
                                    filename = git_root .. "/" .. file,
                                    lnum = 1,
                                    col = 1,
                                    text = "[new file]",
                                })
                            end
                        end

                        if #qf_items == 0 then
                            vim.notify("No git changes found", vim.log.levels.INFO)
                            return
                        end

                        vim.fn.setqflist({}, "r", {
                            title = "Git Changes",
                            items = qf_items,
                        })
                        vim.cmd("copen")
                    end, { desc = "git - set qflist" })

                    -- Navigation
                    map("n", "]h", function()
                        if vim.wo.diff then
                            return "]c"
                        end
                        vim.schedule(function()
                            gs.nav_hunk("next")
                        end)
                        return "<Ignore>"
                    end, { expr = true, desc = "next hunk" })

                    map("n", "[h", function()
                        if vim.wo.diff then
                            return "[c"
                        end
                        vim.schedule(function()
                            gs.nav_hunk("prev")
                        end)
                        return "<Ignore>"
                    end, { expr = true, desc = "prev hunk" })

                    map("n", "<leader>gs", gs.stage_hunk, { desc = "git - stage hunk" })
                    map("n", "<leader>gr", gs.reset_hunk, { desc = "git - reset hunk" })
                    map("v", "<leader>gs", function()
                        gs.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
                    end, { desc = "git - stage hunk" })
                    map("v", "<leader>gr", function()
                        gs.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
                    end, { desc = "git - reset hunk" })
                    map("n", "<leader>gS", gs.stage_buffer, { desc = "git - stage buffer" })
                    map("n", "<leader>gu", gs.undo_stage_hunk, { desc = "git - undo stage hunk" })
                    map("n", "<leader>gR", gs.reset_buffer, { desc = "git - reset buffer" })
                    map("n", "<leader>gp", gs.preview_hunk, { desc = "git - preview hunk" })
                    map("n", "<leader>gb", function()
                        gs.blame_line({ full = true })
                    end, { desc = "git - blameline" })
                    map("n", "<leader>gb", gs.blame, { desc = "git - blame" })
                    map("n", "<leader>gB", gs.toggle_current_line_blame, { desc = "git - blame current line" })
                    map("n", "<leader>gd", gs.diffthis, { desc = "git - diff" })
                    map("n", "<leader>gD", function()
                        gs.diffthis("~")
                    end, { desc = "git - diff" })
                    map("n", "<leader>gt", gs.toggle_deleted, { desc = "git - toggle deleted" })

                    map({ "o", "x" }, "ih", ":<C-U>Gitsigns select_hunk<CR>", { desc = "git - select hunk" })
                end,
            })
        end,
    },
    {
        {
            "FabijanZulj/blame.nvim",
            lazy = false,
            config = function()
                require("blame").setup({})
            end,
        },
    },
    {
        "KEY60228/reviewthem.nvim",
        dependencies = {
            "sindrets/diffview.nvim", -- optional (need at least one diff tool)
            "nvim-telescope/telescope.nvim", -- optional
        },
        config = function()
            require("reviewthem").setup({
                diff_tool = "diffview", -- "diffview" or "alt-diffview"
                comment_sign = "💬", -- Sign shown in gutter for comments
                ui = "builtin", -- "builtin" or "telescope"
                keymaps = {
                    start_review = "<leader>rs",
                    add_comment = "<leader>rc",
                    submit_review = "<leader>rw",
                    abort_review = "<leader>rq",
                    show_comments = "<leader>rl",
                    toggle_reviewed = "<leader>rt",
                    show_status = "<leader>rk",
                    confirm_comment = "<C-s>",
                    cancel_comment = "<Esc>",
                },
            })
        end,
    },
}
