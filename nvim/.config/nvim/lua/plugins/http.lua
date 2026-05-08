return {
    {
      "rest-nvim/rest.nvim",
      dependencies = {
        "nvim-treesitter/nvim-treesitter",
        "nvim-treesitter/nvim-treesitter-textobjects",
      },
      config = function()
        require("rest-nvim").setup()
      end,
      keys = {
          {"<leader>he", function ()
              vim.cmd(":Rest env set .env.http")
              vim.cmd(":Rest run")
          end, desc = "HTTP: execute REST request"},
          {"<leader>hl", "<cmd>:Rest last<cr>", desc = "HTTP: execute last REST request"},
          {"<leader>hf", "<cmd>:lua require('telescope').extensions.rest.select_env()<cr>", desc = "HTTP: select env"},
          {"<leader>hc", "<cmd>:e .env.http<cr>", desc = "HTTP: edit config"},
      }
    }
}
