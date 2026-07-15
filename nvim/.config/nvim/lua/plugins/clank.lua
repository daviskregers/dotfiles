-- Load clank.nvim from its separate repo (dev mode: live edits, no clone).
-- Standalone plugin — no reverse dependency from clank back into this config.
local dev = vim.fn.expand("~/projects/productivity/clank.nvim")
if vim.fn.isdirectory(dev) == 1 then
  vim.opt.runtimepath:prepend(dev)
  pcall(function() require("clank").setup({}) end) -- pcall: skeleton must never break startup
end
