return {
    {
        "NickvanDyke/opencode.nvim",
        dependencies = {
            -- Recommended for `ask()` and `select()`.
            -- Required for `snacks` provider.
            ---@module 'snacks' <- Loads `snacks.nvim` types for configuration intellisense.
            { "folke/snacks.nvim", opts = { input = {}, picker = {}, terminal = {} } },
        },
        config = function()
            ---@type opencode.Opts
            vim.g.opencode_opts = {
                prompts = {
                    ask_append = { prompt = "", ask = true }, -- Handy to insert context mid-prompt. Simpler than exposing every context as a prompt by default.
                    ask_this = { prompt = "@this: ", ask = true, submit = true },
                    -- diagnostics = { prompt = "Explain @diagnostics", submit = true },
                    -- diff = { prompt = "Review the following git diff for correctness and readability: @diff", submit = true },
                    -- document = { prompt = "Add comments documenting @this", submit = true },
                    explain = { prompt = "Explain @this and its context", submit = true },
                    -- fix = { prompt = "Fix @diagnostics", submit = true },
                    -- implement = { prompt = "Implement @this", submit = true },
                    -- optimize = { prompt = "Optimize @this for performance and readability", submit = true },
                    -- review = { prompt = "Review @this for correctness and readability", submit = true },
                    -- test = { prompt = "Add tests for @this", submit = true },
                },
            }

            vim.o.autoread = true

            vim.keymap.set({ "n", "x" }, "<leader>ot", function()
                require("opencode").toggle()
            end, { desc = "Toggle opencode" })

            vim.keymap.set({ "n", "x" }, "<leader>oa", function()
                require("opencode").ask("@this: ", { submit = true })
            end, { desc = "Ask opencode" })

            vim.keymap.set({ "n", "x" }, "<leader>oe", function()
                require("opencode").prompt("Explain @this and it's context", { submit = true })
            end, { desc = "Explain opencode" })

            vim.keymap.set({ "n", "x" }, "<leader>or", function()
                require("opencode").prompt(
                    [[
                    Review the following git diff: @diff

                    Focus on correctness, performance, and readability.
                ]],
                    { submit = true }
                )
            end, { desc = "Explain opencode" })

            vim.keymap.set({ "n", "x" }, "<leader>oq", function()
                require("opencode").prompt(
                    [[
                        Explain @diagnostics
                ]],
                    { submit = true }
                )
            end, { desc = "Explain opencode" })

            vim.keymap.set({ "n", "x" }, "<leader>oc", function()
                require("opencode").command("session.new")
            end, { desc = "New opencode session" })

            vim.keymap.set({ "n", "x" }, "<leader>ol", function()
                require("opencode").command("session.list")
            end, { desc = "List opencode sessions" })

            vim.keymap.set({ "n", "x" }, "<leader>o;", function()
                require("opencode").command("agent.cycle")
            end, { desc = "Clear opencode session" })

            vim.keymap.set({ "n", "x" }, "go", function()
                return require("opencode").operator("@this ")
            end, { expr = true, desc = "Add range to opencode" })

            vim.keymap.set("n", "goo", function()
                return require("opencode").operator("@this ") .. "_"
            end, { expr = true, desc = "Add line to opencode" })

            vim.keymap.set("n", "<leader>ou", function()
                require("opencode").command("session.half.page.up")
            end, { desc = "opencode half page up" })

            vim.keymap.set("n", "<leader>od", function()
                require("opencode").command("session.half.page.down")
            end, { desc = "opencode half page down" })
        end,
    },
}
