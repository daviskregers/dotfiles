local colorscheme = "tokyonight"
vim.g.tokyonight_stype = "night"

local status_ok, _ = pcall(vim.cmd, "colorscheme " .. colorscheme)
if not status_ok then
  vim.notify("colorscheme " .. colorscheme .. " not found!")
  return
end

vim.api.nvim_set_hl(0, 'Comment', {fg="#D33257"})
vim.api.nvim_set_hl(0, 'ExtraWhitespace', {bg="red"})
vim.api.nvim_set_hl(0, 'ColorColumn', {bg="#840000"})

