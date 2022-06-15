vim.cmd [[packadd packer.nvim]]

return require('packer').startup(function()
    local use = require('packer').use

    -- Packer can manage itself
    use 'wbthomason/packer.nvim'

    -- File explorer
    use {
        'kyazdani42/nvim-tree.lua',
        requires = {
            'kyazdani42/nvim-web-devicons', -- optional, for file icon
        }
    }

    -- helpers
    use "folke/which-key.nvim"
    -- tabs
    use {
        'romgrk/barbar.nvim',
        requires = { 'kyazdani42/nvim-web-devicons' }
    }
    use 'moll/vim-bbye' -- closing buffers without messing up layouts

    -- LSP
    use 'alexaandru/nvim-lspupdate'
    use {
        'neovim/nvim-lspconfig',
        'williamboman/nvim-lsp-installer', -- installs LSP servers locally
    }
    use 'ray-x/lsp_signature.nvim' -- shows function signatures while typing
    use 'folke/lsp-colors.nvim'
    use 'onsails/lspkind-nvim' -- vscode like pictograms for neovim built-in lsp
    use 'kosayoda/nvim-lightbulb' -- shows a lightbulb whenever a code action is available
    use 'tami5/lspsaga.nvim'
    use 'simrat39/symbols-outline.nvim'
    use 'jose-elias-alvarez/null-ls.nvim' -- linters

    -- treesitter
    use { 'nvim-treesitter/nvim-treesitter', run = ':TSUpdate' }
    use 'nvim-treesitter/playground'

    -- autocomplete
    use 'hrsh7th/cmp-buffer'
    use 'hrsh7th/cmp-cmdline'
    use 'hrsh7th/cmp-nvim-lsp'
    use 'hrsh7th/cmp-nvim-lua'
    use 'hrsh7th/cmp-path'
    use 'hrsh7th/nvim-cmp'
    use { 'tzachar/cmp-tabnine', run = './install.sh', requires = 'hrsh7th/nvim-cmp' }

    -- trouble
    use { -- displays linter errors
        "folke/trouble.nvim",
        requires = "kyazdani42/nvim-web-devicons"
    }


    -- todos
    use {
        "folke/todo-comments.nvim",
        requires = "nvim-lua/plenary.nvim"
    }

    -- colorscheme
    use 'yorik1984/newpaper.nvim'
    -- use 'tjdevries/colorbuddy.nvim'

    -- trailing whitespace
    use 'ntpeters/vim-better-whitespace'

    -- indent guides
    use "lukas-reineke/indent-blankline.nvim"

    -- toggle comments
    use 'terrortylor/nvim-comment'
    use 'JoosepAlviste/nvim-ts-context-commentstring'

    -- expand selection region
    use 'terryma/vim-expand-region'

    -- match brackets
    use 'p00f/nvim-ts-rainbow'

    -- match pairs
    use 'windwp/nvim-autopairs'

    -- telescope
    use 'nvim-telescope/telescope-fzy-native.nvim'
    use {
        'nvim-telescope/telescope.nvim',
        requires = { { 'nvim-lua/plenary.nvim' } }
    }

    -- status line
    use {
        'nvim-lualine/lualine.nvim',
        requires = { 'kyazdani42/nvim-web-devicons', opt = true }
    }

    -- editorconfig
    use 'gpanders/editorconfig.nvim'

    -- highlight words and lines on the cursor
    use 'yamatsum/nvim-cursorline'

    -- git
    use { 'tanvirtin/vgit.nvim', requires = { 'nvim-lua/plenary.nvim' } } -- visual git
    use 'akinsho/git-conflict.nvim' -- merge conflict
    use 'tpope/vim-fugitive'
    use 'tpope/vim-rhubarb'

    -- snippets
    -- For luasnip users.
    -- Plug 'L3MON4D3/LuaSnip'
    -- Plug 'saadparwaiz1/cmp_luasnip'

    -- For ultisnips users.
    -- Plug 'SirVer/ultisnips'
    -- Plug 'quangnguyen30192/cmp-nvim-ultisnips'

    -- For snippy users.
    use 'dcampos/cmp-snippy'
    use 'dcampos/nvim-snippy'
    use 'honza/vim-snippets'

    -- text align
    use 'RRethy/nvim-align'

    -- tags
    use 'ludovicchabant/vim-gutentags'

    -- refactoring
    use {
        "ThePrimeagen/refactoring.nvim",
        requires = {
            { "nvim-lua/plenary.nvim" },
            { "nvim-treesitter/nvim-treesitter" }
        }
    }

    -- marks
    use 'chentoast/marks.nvim'

    -- show latest package versions
    use({
        "vuki656/package-info.nvim",
        requires = "MunifTanjim/nui.nvim",
    })
    use {
        'saecki/crates.nvim',
        requires = { 'nvim-lua/plenary.nvim' },
    }

    -- preview goto line
    use 'nacro90/numb.nvim'

    -- markdown
    use 'lukas-reineke/headlines.nvim' -- highlight blocks

    -- testing
    use { "rcarriga/vim-ultest", requires = { "vim-test/vim-test" }, run = ":UpdateRemotePlugins" }

    -- projects
    use 'windwp/nvim-projectconfig'

    -- pretty quick fix
    use { 'https://gitlab.com/yorickpeterse/nvim-pqf.git', config = function()
        require('pqf').setup()
    end }

end)
