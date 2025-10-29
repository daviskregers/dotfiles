return {
    {
        "folke/which-key.nvim",
        event = "VeryLazy",
        config = function()
            local wk = require("which-key")

            wk.setup({
                preset = "modern",
                delay = 500, -- delay before showing the popup (ms)
                plugins = {
                    marks = true,
                    registers = true,
                    spelling = {
                        enabled = true,
                        suggestions = 20,
                    },
                },
                win = {
                    border = "rounded",
                },
                -- Disable by default - won't show automatically
                triggers = {},
            })

            -- Add group labels for better organization
            wk.add({
                { "<leader>p", group = "Project/Telescope" },
                { "<leader>t", group = "Terminal/Test" },
                { "<leader>z", group = "AI" },
                { "<leader>d", group = "Diagnostics" },
                { "g", group = "Go to" },
                { "]", group = "Next" },
                { "[", group = "Previous" },
            })

            -- Create commands to enable/disable which-key
            vim.api.nvim_create_user_command("WhichKeyEnable", function()
                wk.setup({
                    triggers = {
                        { "<auto>", mode = "nxso" },
                    }
                })
                vim.notify("Which-Key enabled", vim.log.levels.INFO)
            end, { desc = "Enable Which-Key automatic popups" })

            vim.api.nvim_create_user_command("WhichKeyDisable", function()
                wk.setup({
                    triggers = {},
                })
                vim.notify("Which-Key disabled", vim.log.levels.INFO)
            end, { desc = "Disable Which-Key automatic popups" })

            vim.api.nvim_create_user_command("WhichKeyToggle", function()
                -- Simple toggle by checking if triggers exist
                local config = require("which-key.config")
                if #config.options.triggers > 0 then
                    vim.cmd("WhichKeyDisable")
                else
                    vim.cmd("WhichKeyEnable")
                end
            end, { desc = "Toggle Which-Key automatic popups" })

            -- Keybinding to show which-key on demand (works even when disabled)
            vim.keymap.set("n", "<leader>?", function()
                vim.cmd("WhichKey")
            end, { desc = "Show Which-Key" })
        end,
    }
}
