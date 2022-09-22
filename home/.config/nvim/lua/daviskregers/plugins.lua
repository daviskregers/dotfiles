local fn = vim.fn

-- Automatically install packer
local install_path = fn.stdpath "data" .. "/site/pack/packer/start/packer.nvim"
if fn.empty(fn.glob(install_path)) > 0 then
    PACKER_BOOTSTRAP = fn.system {
        "git",
        "clone",
        "--depth",
        "1",
        "https://github.com/wbthomason/packer.nvim",
        install_path,
    }
    print "Installing packer close and reopen Neovim..."
    vim.cmd [[packadd packer.nvim]]
end

-- Autocommand that reloads neovim whenever you save the plugins.lua file
vim.cmd [[
  augroup packer_user_config
    autocmd!
    autocmd BufWritePost plugins.lua source <afile> | PackerSync
  augroup end
]]

local status_ok, packer = pcall(require, "packer")
if not status_ok then
    vim.notify("ERROR: Could not load packer.nvim!")
    return
end

packer.init {
    display = {
        open_fn = function()
            return require("packer.util").float { border = "rounded" }
        end,
    },
}

return packer.startup(function(use)
    use "wbthomason/packer.nvim" -- Have packer manage itself
    use "nvim-lua/popup.nvim" -- An implementation of the Popup API from vim in Neovim
    use "nvim-lua/plenary.nvim" -- Useful lua functions used ny lots of plugins
    use "windwp/nvim-autopairs" -- Autopairs, integrates with both cmp and treesitter
    use "numToStr/Comment.nvim" -- Easily comment stuff
    use "kyazdani42/nvim-web-devicons"
    use "kyazdani42/nvim-tree.lua"
    use "akinsho/bufferline.nvim"
    use "moll/vim-bbye"
    use "nvim-lualine/lualine.nvim"
    use "akinsho/toggleterm.nvim"
    use "ahmedkhalf/project.nvim"
    use "lewis6991/impatient.nvim"
    use "lukas-reineke/indent-blankline.nvim"
    use "goolord/alpha-nvim" -- starting dashboard
    use "antoinemadec/FixCursorHold.nvim" -- This is needed to fix lsp doc highlight
    use "folke/which-key.nvim"
    use "xiyaowong/nvim-whitespace" -- provides with a trailing whitespace highlight, command to clean them
    use "gpanders/editorconfig.nvim"
    use {
        "folke/todo-comments.nvim",
        requires = "nvim-lua/plenary.nvim",
    }
    use "chentoast/marks.nvim"
    use {
        's1n7ax/nvim-search-and-replace',
        config = function() require 'nvim-search-and-replace'.setup() end,
    }
    use "windwp/nvim-projectconfig"
    use {
      "jiaoshijie/undotree",
      requires = {
        "nvim-lua/plenary.nvim",
      },
    }

    -- colorscheme
    use "folke/tokyonight.nvim"

    -- completion
    use "hrsh7th/nvim-cmp" -- The completion plugin
    use "hrsh7th/cmp-buffer" -- buffer completions
    use "hrsh7th/cmp-path" -- path completions
    use "hrsh7th/cmp-cmdline" -- cmdline completions
    use "saadparwaiz1/cmp_luasnip" -- snippet completions
    use "hrsh7th/cmp-nvim-lsp-signature-help" -- function signatures
    use "hrsh7th/cmp-nvim-lsp" -- LSP source.
    use "hrsh7th/cmp-emoji"
    use "hrsh7th/cmp-calc"
    use "hrsh7th/cmp-nvim-lsp-document-symbol"
    use "hrsh7th/cmp-nvim-lua"
 	use {'tzachar/cmp-tabnine', run='./install.sh', requires = 'hrsh7th/nvim-cmp'}
    use "pierreglaser/folding-nvim"

    -- snippets
    use "L3MON4D3/LuaSnip" --snippet engine
    use "rafamadriz/friendly-snippets" -- a bunch of snippets to use
    use "honza/vim-snippets"

    -- LSP
    use {
        "williamboman/mason.nvim",
        "williamboman/mason-lspconfig.nvim",
        "neovim/nvim-lspconfig",
    }
    use "williamboman/nvim-lsp-installer" -- simple to use language server installer
    use "jose-elias-alvarez/null-ls.nvim" -- for formatters and linters

    -- Telescope
    use "nvim-telescope/telescope.nvim"
    use "nvim-telescope/telescope-media-files.nvim"
    use {
        "folke/lsp-trouble.nvim",
        requires = "kyazdani42/nvim-web-devicons",
    }

    -- dap
    use { "rcarriga/nvim-dap-ui", requires = {"mfussenegger/nvim-dap"} }

    -- Treesitter
    use {
        "nvim-treesitter/nvim-treesitter",
        run = ":TSUpdate",
    }
    use "p00f/nvim-ts-rainbow"
    use "nvim-treesitter/playground"
    use "JoosepAlviste/nvim-ts-context-commentstring"
    use {
      "nvim-neotest/neotest",
      requires = {
        "antoinemadec/FixCursorHold.nvim",
        "haydenmeade/neotest-jest",
        "nvim-lua/plenary.nvim",
        "nvim-neotest/neotest-plenary",
        "nvim-neotest/neotest-python",
        "nvim-treesitter/nvim-treesitter",
        "olimorris/neotest-phpunit",
        "rouge8/neotest-rust",
      }
    }
    use "nvim-treesitter/nvim-treesitter-context"

    -- Git
    use "lewis6991/gitsigns.nvim"

    -- hard mode
    use "takac/vim-hardtime"

    if PACKER_BOOTSTRAP then
        require("packer").sync()
    end
end)
