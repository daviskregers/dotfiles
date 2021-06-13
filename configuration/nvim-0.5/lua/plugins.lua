vim.cmd 'packadd paq-nvim'         -- Load package
local paq = require'paq-nvim'.paq  -- Import module and bind `paq` function
paq{'savq/paq-nvim', opt=true}     -- Let Paq manage itself

-- treesitter
paq{'nvim-treesitter/nvim-treesitter', run=':TSUpdate'}
paq 'nvim-treesitter/playground'
paq 'p00f/nvim-ts-rainbow'

-- LSP
paq 'neovim/nvim-lspconfig'
paq 'kabouzeid/nvim-lspinstall'
paq 'kosayoda/nvim-lightbulb'
paq 'alexaandru/nvim-lspupdate'
paq 'onsails/lspkind-nvim'

-- autocomplete
paq 'hrsh7th/nvim-compe'
paq 'hrsh7th/vim-vsnip'

-- colorscheme
paq 'tjdevries/colorbuddy.vim'
paq 'tomasr/molokai'
paq 'RishabhRD/nvim-rdark'
paq 'DilanGMB/nightbuddy'
paq 'famiu/feline.nvim'
paq 'kyazdani42/nvim-web-devicons'

-- misc
paq 'nvim-lua/plenary.nvim'
paq 'famiu/nvim-reload'

-- file explorer
paq 'kyazdani42/nvim-web-devicons' -- for file icons
paq 'kyazdani42/nvim-tree.lua'

-- fuzzy file finder
paq 'nvim-lua/popup.nvim'
paq 'nvim-lua/plenary.nvim'
paq 'nvim-telescope/telescope.nvim'

-- tabline
paq 'kyazdani42/nvim-web-devicons'
paq 'romgrk/barbar.nvim'

-- indent guides
paq {'lukas-reineke/indent-blankline.nvim', branch = 'lua'}

-- blame line
paq 'tveskag/nvim-blame-line'

-- display trailing whitespace
paq 'ntpeters/vim-better-whitespace'

-- toggle comments
paq "terrortylor/nvim-comment"

-- text align
paq 'junegunn/vim-easy-align'

-- phpactor
paq {'phpactor/phpactor', branch = 'develop', run = 'composer install --no-dev -o'}

-- snippets
paq { 'honza/vim-snippets' }
paq { 'SirVer/ultisnips' }

-- tagbar
paq { 'preservim/tagbar' }