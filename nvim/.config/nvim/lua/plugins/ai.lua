return {
    {
        "zbirenbaum/copilot.lua",
        lazy = false,
        cmd = "Copilot",
        event = "InsertEnter",
        dependencies = {
            "copilotlsp-nvim/copilot-lsp", -- (optional) for NES functionality
        },
        config = function()
            require("copilot").setup({
                filetypes = {
                    -- markdown = true,   -- overrides default
                    -- terraform = false, -- disallow specific filetype
                    sh = function()
                        if string.match(vim.fs.basename(vim.api.nvim_buf_get_name(0)), '^%.env.*') then
                            -- disable for .env files
                            return false
                        end
                        return true
                    end,
                },
                should_attach = function(_, bufname)
                    if string.match(bufname, "env") then
                        return false
                    end

                    return true
                end,
                suggestion = {
                    enabled = true,
                    auto_trigger = false,
                    hide_during_completion = true,
                    debounce = 75,
                    trigger_on_accept = true,
                    keymap = {
                        accept = false,
                        accept_word = false,
                        accept_line = false,
                        next = false,
                        prev = false,
                        dismiss = false,
                    },
                },
                nes = {
                    enabled = false, -- requires copilot-lsp as a dependency
                    auto_trigger = false,
                    keymap = {
                        accept_and_goto = false,
                        accept = false,
                        dismiss = false,
                    },
                },
            })

            vim.api.nvim_create_autocmd("User", {
                pattern = "BlinkCmpMenuOpen",
                callback = function()
                    vim.b.copilot_suggestion_hidden = true
                end,
            })

            vim.api.nvim_create_autocmd("User", {
                pattern = "BlinkCmpMenuClose",
                callback = function()
                    vim.b.copilot_suggestion_hidden = false
                end,
            })

            vim.keymap.set('n', '<leader>ct', function()
                local suggest = require("copilot.suggestion")

                suggest.toggle_auto_trigger()


                if vim.b.autopilot_suggestion_auto_trigger then
                    vim.notify('Enabled copilot suggestions')
                else
                    vim.notify('Disabled copilot suggestions')
                end
            end, { desc = 'Toggle Copilot Suggestions' })

            -- Copilot suggestion keymaps with notifications
            vim.keymap.set('i', '<C-l>', function()
                local suggest = require("copilot.suggestion")
                if suggest.is_visible() then
                    suggest.accept_line()
                    vim.notify('Accepted copilot suggestion line')
                end
            end, { desc = 'Accept Copilot suggestion line' })

            vim.keymap.set('i', '<C-j>', function()
                local suggest = require("copilot.suggestion")
                if suggest.is_visible() then
                    suggest.next()
                    vim.notify('Next copilot suggestion')
                end
            end, { desc = 'Next Copilot suggestion' })

            vim.keymap.set('i', '<C-k>', function()
                local suggest = require("copilot.suggestion")
                if suggest.is_visible() then
                    suggest.prev()
                    vim.notify('Previous copilot suggestion')
                end
            end, { desc = 'Previous Copilot suggestion' })

            vim.keymap.set('i', '<C-h>', function()
                local suggest = require("copilot.suggestion")
                if suggest.is_visible() then
                    suggest.dismiss()
                    vim.notify('Dismissed copilot suggestion')
                end
            end, { desc = 'Dismiss Copilot suggestion' })
        end,
    }
}
