return {
    "nvim-neotest/neotest",
    dependencies = {
        "nvim-lua/plenary.nvim",
        "antoinemadec/FixCursorHold.nvim",
        "nvim-treesitter/nvim-treesitter",
        "rouge8/neotest-rust",
        "nvim-neotest/nvim-nio",
    },
    config = function()
        local nt = require("neotest")
        nt.setup({
            adapters = {
                require("neotest-rust") {
                    args = { "--no-capture" },
                }
            }
        })

        vim.diagnostic.config({}, vim.api.nvim_create_namespace("neotest"))

        vim.keymap.set('n', '<leader>ts', function()
            nt.summary.toggle()
        end, { desc = "Test summary" })

        vim.keymap.set('n', '<leader>tf', function()
            nt.run.run(vim.fn.expand("%"))
        end, { desc = "Test current file" })

        vim.keymap.set('n', '<leader>tt', function()
            nt.run.run()
        end, { desc = "Test nearest" })

        vim.keymap.set('n', '<leader>tT', function()
            nt.run.run(vim.fn.getcwd())
        end, { desc = "Test all" })

        vim.keymap.set('n', '<leader>tx', function()
            nt.run.stop()
        end, { desc = "Stop nearest tests" })

        vim.keymap.set('n', '<leader>ta', function()
            nt.run.attach()
        end, { desc = "Attach nearest tests" })

        vim.keymap.set('n', '<leader>to', function()
            nt.output_panel.open()
        end, { desc = "Test output" })

        vim.keymap.set('n', '<leader>td', function()
            nt.diagnostic.open()
        end, { desc = "Test diagnostics" })
    end
}
