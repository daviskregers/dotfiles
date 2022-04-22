local fn = vim.fn
local install_path = fn.stdpath('data')..'/site/pack/packer/start/packer.nvim'
if fn.empty(fn.glob(install_path)) > 0 then
  packer_bootstrap = fn.system({'git', 'clone', '--depth', '1', 'https://github.com/wbthomason/packer.nvim', install_path})
end

vim.cmd([[
  augroup packer_user_config
    autocmd!
    autocmd BufWritePost plugins.lua source <afile> | PackerCompile
  augroup end
]])

return require('packer').startup(function(use)
    -- appearance
    use 'famiu/feline.nvim'                                 -- neovim statusline
    use 'folke/lsp-colors.nvim'                             -- Diagnostics highlight groups for colorschemes
    use 'folke/tokyonight.nvim'                             -- colorscheme
    use 'kosayoda/nvim-lightbulb'                           -- shows a lightbulb whenever a code action is available
    use 'kyazdani42/nvim-tree.lua'                          -- lua file explorer
    use 'kyazdani42/nvim-web-devicons'                      -- icons
    use 'lukas-reineke/indent-blankline.nvim'               -- indent guides
    use 'ntpeters/vim-better-whitespace'                    -- display trailing whitespace
    use 'onsails/lspkind-nvim'                              -- vscode like pictograms for neovim built-in lsp
    use 'p00f/nvim-ts-rainbow'                              -- rainbow paranthasis using tree-sitter
    use 'romgrk/barbar.nvim'                                -- tabline
    use 'simrat39/symbols-outline.nvim'                     -- panel for symbol navigation
    use 'tjdevries/colorbuddy.vim'                          -- colorscheme helper
    use 'tveskag/nvim-blame-line'                           -- blame line

    -- Configuration
    use 'editorconfig/editorconfig-vim'                     -- editorconfig
    use 'famiu/nvim-reload'                                 -- allows to reload the whole neovim config completely
    use 'windwp/nvim-projectconfig'                         -- config for each project

    -- helpers
    use 'folke/which-key.nvim'                              -- which key - shows information about key binds
    use 'github/copilot.vim'                                -- github copilot
    use 'jakelinnzy/autocmd-lua'                            -- neovim autocommands
    use 'ludovicchabant/vim-gutentags'                      -- ctags generation
    use 'nvim-lua/plenary.nvim'                             -- helper for using neovim functions in lua
    use 'nvim-lua/popup.nvim'                               -- popup API

    -- autocomplete
    use 'hrsh7th/cmp-buffer'                                -- nvim-cmp source for buffer words
    use 'hrsh7th/cmp-nvim-lsp'                              -- nvim-cmp source for neovim builtin lsp client
    use 'hrsh7th/nvim-cmp'                                  -- completion engine
    use 'nvim-telescope/telescope.nvim'                     -- fuzzy finder

    -- markdown
    use 'ferrine/md-img-paste.vim'                          -- markdown image pate
    use 'shime/vim-livedown'                                -- markdown live preview

    -- text
    use 'RRethy/nvim-align'                                 -- :'<,'>Align =
    use 'junegunn/vim-easy-align'                           -- text align gA keybind
    use 'mg979/vim-visual-multi'                            -- multiple cursors CTRL-N or CTRL-Down/Up
    use 'sbdchd/neoformat'                                  -- formatter
    use 'terrortylor/nvim-comment'                          -- toggle comments
    use 'terryma/vim-expand-region'                         -- increase selection region with + and _ keys
    use 'vim-scripts/Shortcut-functions-for-KeepCase-script-' -- shortcuts for keepcase :'<,'>call S('building','campus')
    use 'vim-scripts/keepcase.vim'                          -- search & replace with case

    -- syntax
    use 'nvim-treesitter/playground'
    use {'nvim-treesitter/nvim-treesitter', run=':TSUpdate'} -- configuration and abstraction layer for neovim treesitter

    -- LSP
    use 'alexaandru/nvim-lspupdate'                         -- updates and auto installs LSP servers
    use {
        'neovim/nvim-lspconfig',
        'williamboman/nvim-lsp-installer',                  -- installs LSP servers locally
    }
    use 'nanotee/sqls.nvim'
    use {'phpactor/phpactor', branch = 'develop', run = 'composer install --no-dev -o'}
    use 'jose-elias-alvarez/null-ls.nvim'                   -- linters on LSP
    use {                                                   -- displays linter errors
      "folke/trouble.nvim",
      requires = "kyazdani42/nvim-web-devicons",
      config = function()
        require("trouble").setup(require('trouble-config'))      end
    }
    use 'ray-x/lsp_signature.nvim'                          -- shows function signatures while typing
    use 'tami5/lspsaga.nvim'

    -- refactoring
    use {                                                   -- refactoring tools
        "ThePrimeagen/refactoring.nvim",
        requires = {
            {"nvim-lua/plenary.nvim"},
            {"nvim-treesitter/nvim-treesitter"}
        }
    }

    -- php
    use 'adoy/vim-php-refactoring-toolbox'                  -- php refactoring tools
    use 'tobyS/pdv'                                         -- phpdoc

    -- git
    use {'tanvirtin/vgit.nvim', requires = {'nvim-lua/plenary.nvim'}} -- visual git

    -- snippets
    use 'hrsh7th/vim-vsnip'
    use 'hrsh7th/vim-vsnip-integ'
    use "rafamadriz/friendly-snippets"

	if packer_bootstrap then
		require('packer').sync()
	end
end)
