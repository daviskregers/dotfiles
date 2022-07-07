local M = {}

vim.cmd [[ filetype indent on ]]
vim.opt.backup = false
vim.opt.termguicolors = true
vim.opt.writebackup = false
vim.wo.colorcolumn = "120"
vim.wo.number = true
vim.wo.relativenumber = true
vim.o.foldmethod = 'expr'
vim.o.foldexpr = 'nvim_treesitter#foldexpr()'
vim.o.foldlevel = 20

vim.cmd [[ command! BufOnly silent! execute "%bd|e#|bd#" ]]

M.cmp = {
  sources = {
      { name = "luasnip" },
      { name = "nvim_lsp" },
      { name = "buffer" },
      { name = "nvim_lua" },
      { name = "path" },
      { name = "tabnine"}
  }
}

M.ui = {
  theme = "gruvbox",
  theme_toggle = { "gruvbox", "gruvbox_light" },
  transparency = true,
  hl_override = {
    Error = { fg = "#f0000c" },
    Comment = { fg = "#f0000c" },
    TSComment = { fg = "#f0000c" },
    ColorColumn = { bg = "red" },
    GitSignsAdd = { bg = "green" },
    GitSignsChange = { bg = "yellow" },
    GitSignsDelete = { bg = "red" },
  }
}

M.plugins = {
  override = {
    ["nvim-treesitter/nvim-treesitter"] = require "custom.plugins.configs.treesitter"
  },
  options = {
    lspconfig = {
      setup_lspconf = "custom.plugins.configs.lsp"
    }
  },
  user = require("custom.plugins")
}

M.mappings = require("custom.mappings")

return M
