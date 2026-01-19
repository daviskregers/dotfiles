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
            {"<leader>re", "<cmd>:Rest run<cr>", desc = "Execute REST request"},
            {"<leader>rl", "<cmd>:Rest last<cr>", desc = "Execute last REST request"},
            {"<leader>rf", "<cmd>:lua require('telescope').extensions.rest.select_env()<cr>", desc = "Select ENV"},
        }
      }
    }
}
