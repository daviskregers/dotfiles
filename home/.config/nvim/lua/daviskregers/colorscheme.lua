local colorscheme = "tokyonight"
vim.g.tokyonight_stype = "night"

local status_ok, _ = pcall(vim.cmd, "colorscheme " .. colorscheme)
if not status_ok then
  vim.notify("colorscheme " .. colorscheme .. " not found!")
  return
end

vim.highlight.create('Comment', {guifg="#D33257"}, false)
vim.highlight.create('ExtraWhitespace', {guibg="red"}, false)

