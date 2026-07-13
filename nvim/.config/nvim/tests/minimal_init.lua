-- Headless test bootstrap for plenary.busted.
-- Run:  make test  (see ../Makefile)
local data = vim.fn.stdpath("data")
vim.opt.rtp:append(data .. "/lazy/plenary.nvim")
vim.opt.rtp:append(data .. "/site/pack/core/opt/plenary.nvim")
vim.opt.rtp:append(vim.fn.getcwd()) -- so require("code-agents.*") resolves to ./lua
vim.cmd("runtime plugin/plenary.vim")
