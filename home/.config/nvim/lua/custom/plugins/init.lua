return {
  ["folke/trouble.nvim"] = {
    requires = "kyazdani42/nvim-web-devicons",
    config = function()
      require("custom.plugins.configs.trouble-list")
    end
  },
  ["folke/todo-comments.nvim"] = {
    requires = "nvim-lua/plenary.nvim",
    config = function()
      require("custom.plugins.configs.todo-comments")
    end
  },
  ["tami5/lspsaga.nvim"] = {},
  ["jose-elias-alvarez/null-ls.nvim"] = {
    after = "nvim-lspconfig",
    config = function()
      require "custom.plugins.configs.null-ls"
    end,
  },
  ["RRethy/nvim-align"] = {},
  ["lewis6991/gitsigns.nvim"] = {
    config = function()
      require("custom.plugins.configs.gitsigns")
    end
  },
  ["lukas-reineke/indent-blankline.nvim"] = {},
  ["ntpeters/vim-better-whitespace"] = {},
  ["p00f/nvim-ts-rainbow"] = {},
  ["windwp/nvim-projectconfig"] = {},
  ["tpope/vim-sleuth"] = {},
  ["moll/vim-bbye"] = {},
  ["gpanders/editorconfig.nvim"] = {},
  ["yamatsum/nvim-cursorline"] = {},
  ["tzachar/cmp-tabnine"] = {
    run = './install.sh',
    requires = 'hrsh7th/nvim-cmp',
    after = 'hrsh7th/nvim-cmp',
  },
  ["vim-test/vim-test"] = {
    config = function()
      require('custom.plugins.configs.vim-test')
    end
  }

  -- TODO: markdown headlines, preview
}
