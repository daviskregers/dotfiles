-- This file can be loaded by calling `lua require('plugins')` from your init.vim

-- Only required if you have packer configured as `opt`
vim.cmd [[packadd packer.nvim]]

return require('packer').startup(function(use)
    use 'wbthomason/packer.nvim'

    -- Telescope
    use {
        "nvim-telescope/telescope.nvim",
        requires = {
            {"nvim-lua/plenary.nvim"}
        }
    }

    -- colorscheme
    -- https://github.com/nvim-treesitter/nvim-treesitter/wiki/Colorschemes
    use 'olimorris/onedarkpro.nvim'

    -- treesitter
    use({
        'nvim-treesitter/nvim-treesitter',
        run = ':TSUpdate'
    })
    use 'nvim-treesitter/playground'


    -- LSP
    use {
      'VonHeikemen/lsp-zero.nvim',
      requires = {
        -- LSP Support
        {'neovim/nvim-lspconfig'},
        {'williamboman/mason.nvim'},
        {'williamboman/mason-lspconfig.nvim'},
        {'jose-elias-alvarez/null-ls.nvim'},
        {'jayp0521/mason-null-ls.nvim'},

        -- Autocompletion
        {'hrsh7th/nvim-cmp'},
        {'hrsh7th/cmp-buffer'},
        {'hrsh7th/cmp-path'},
        {'saadparwaiz1/cmp_luasnip'},
        {'hrsh7th/cmp-nvim-lsp'},
        {'hrsh7th/cmp-nvim-lua'},

        -- Snippets
        {'L3MON4D3/LuaSnip'},
        {'rafamadriz/friendly-snippets'},
      }
    }

    use 'theprimeagen/harpoon'                -- jump between files
    use 'mbbill/undotree'                     -- revert changes
    use 'folke/which-key.nvim'                -- helps with finding keybindings
    use 'terrortylor/nvim-comment'            -- toggle comments
    use 'xiyaowong/nvim-whitespace'           -- provides with a trailing whitespace highlight, command to clean them
    use 'akinsho/toggleterm.nvim'             -- toggle terminal windows
    use 'gpanders/editorconfig.nvim'          -- apply editorconfig settings
    use 'lukas-reineke/indent-blankline.nvim' -- indents
    use 'RRethy/nvim-align'                   -- align text
    use 'folke/todo-comments.nvim'            -- highlight todo comments
    use 'braxtons12/blame_line.nvim'          -- git blame virtual text
    use 'takac/vim-hardtime'                  -- disallow spamming jk or arrows
end)
