return {
    {
      "rest-nvim/rest.nvim",
      dependencies = {
        "nvim-treesitter/nvim-treesitter",
        opts = function (_, opts)
          opts.ensure_installed = opts.ensure_installed or {}
          table.insert(opts.ensure_installed, "http")
        end,
        keys = {
            {"<leader>re", function ()
                vim.cmd(":Rest env set .env.http")
                vim.cmd(":Rest run")
            end, desc = "Execute REST request"},
            {"<leader>rl", "<cmd>:Rest last<cr>", desc = "Execute last REST request"},
            {"<leader>rf", "<cmd>:lua require('telescope').extensions.rest.select_env()<cr>", desc = "Select ENV"},
            {"<leader>rc", "<cmd>:e .env.http<cr>", desc = "Edit HTTP Config"},
        }
      }
    }
}
