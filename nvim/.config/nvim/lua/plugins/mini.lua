vim.pack.add({ 'https://github.com/nvim-mini/mini.icons' })

require("mini.icons").setup()
-- satisfy plugins that expect nvim-web-devicons (e.g. diffview)
MiniIcons.mock_nvim_web_devicons()
