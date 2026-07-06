-- Headless test bootstrap for plenary.busted.
-- Run:  nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedDirectory tests/"
local data = vim.fn.stdpath("data")
vim.opt.rtp:append(data .. "/lazy/plenary.nvim")
vim.opt.rtp:append(data .. "/site/pack/core/opt/plenary.nvim")
vim.opt.rtp:append(vim.fn.getcwd()) -- so require("code-agents.*") resolves to ./lua
vim.cmd("runtime plugin/plenary.vim")
