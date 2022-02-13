--vim.cmd 'packadd paq-nvim'         -- Load package
--local paq = require'paq-nvim'.paq  -- Import module and bind `paq` function
--paq{'savq/paq-nvim', opt=true}     -- Let Paq manage itself

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
    use 'SirVer/ultisnips' -- snippets
    use 'Yagua/nebulous.nvim' -- colorschemes
    use 'alexaandru/nvim-lspupdate' -- updates and auto installs LSP servers
    use 'editorconfig/editorconfig-vim' -- editorconfig
    use 'famiu/feline.nvim' -- neovim statusline
    use 'famiu/nvim-reload' -- allows to reload the whole neovim config completely
    use 'ferrine/md-img-paste.vim' -- markdown image pate
    use 'folke/which-key.nvim' -- which key
    use 'github/copilot.vim' -- copilot
    use 'honza/vim-snippets' -- snippets
    use 'hrsh7th/cmp-buffer' -- nvim-cmp source for buffer words
    use 'hrsh7th/cmp-nvim-lsp' -- nvim-cmp source for neovim builtin lsp client
    use 'hrsh7th/nvim-cmp' -- completion engin
    use 'jakelinnzy/autocmd-lua' -- neovim autocommands
    use 'junegunn/vim-easy-align' -- text align
    use 'kosayoda/nvim-lightbulb' -- shows a lightbulb whenever a code action is available
    use 'kyazdani42/nvim-tree.lua' -- lua file explorer
    use 'kyazdani42/nvim-web-devicons' -- icons
    use 'ludovicchabant/vim-gutentags' -- ctags generation
    use 'lukas-reineke/indent-blankline.nvim' -- indent guides
    use 'nanotee/sqls.nvim'
    use 'neovim/nvim-lspconfig'
    use 'ntpeters/vim-better-whitespace' -- display trailing whitespace
    use 'nvim-lua/plenary.nvim'
    use 'nvim-lua/popup.nvim'
    use 'nvim-telescope/telescope.nvim'
    use 'nvim-treesitter/playground'
    use 'onsails/lspkind-nvim' -- vscode like pictograms for neovim built-in lsp
    use 'p00f/nvim-ts-rainbow' -- rainbow paranthasis using tree-sitter
    use 'preservim/tagbar' -- tagbar
    use 'rafamadriz/neon' -- colorscheme
    use 'romgrk/barbar.nvim' -- tabline
    use 'sbdchd/neoformat' -- formatter
    use 'shime/vim-livedown' -- markdown live preview
    use 'terrortylor/nvim-comment' -- toggle comments
    use 'tjdevries/colorbuddy.vim' -- colorscheme helper
    use 'tveskag/nvim-blame-line' -- blame line
    use 'williamboman/nvim-lsp-installer' -- installs LSP servers locally
    use {'nvim-treesitter/nvim-treesitter', run=':TSUpdate'} -- configuration and abstraction layer for neovim treesitter
    use {'phpactor/phpactor', branch = 'develop', run = 'composer install --no-dev -o'}
    use 'terryma/vim-expand-region'
    use 'mg979/vim-visual-multi'
    use 'vim-scripts/keepcase.vim'
    use 'vim-scripts/Shortcut-functions-for-KeepCase-script-'
    use {
      's1n7ax/nvim-terminal',
      config = function()
          vim.o.hidden = true
          require('nvim-terminal').setup()
      end,
    }
    use 'joonty/vim-phpqa'
    use {
      'janko/vim-test',
        requires = { 'tpope/vim-dispatch', 'neomake/neomake', 'preservim/vimux' }
    }
    use 'windwp/nvim-projectconfig'

	if packer_bootstrap then
		require('packer').sync()
	end
end)
