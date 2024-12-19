-- Explorer
vim.keymap.set("n", "<leader>pv", "<cmd>Oil<CR>", { desc = "Open file explorer" })

-- Yank
vim.keymap.set({ "n", "v" }, "<leader>y", [["+y]], { desc = "yank to clipboard" })

-- Sort selection
vim.keymap.set("v", "gs", ":sort u<CR>", { desc = "Sort selected lines, remove duplicates" })

-- move line
vim.keymap.set("n", "J", "mzJ`z", { desc = "Move the next line to the end of the current one" })
vim.keymap.set("v", "<", "<gv", { desc = "indent line left" })
vim.keymap.set("v", ">", ">gv", { desc = "indent line right" })
vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv", { desc = "Move line down" })
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv", { desc = "Move line up" })

-- jumps
vim.keymap.set("n", "<C-[>", "<cmd>cprev<CR>zz", { desc = "Jump to prev item in quickfix list & recenter" })
vim.keymap.set("n", "<C-]>", "<cmd>cnext<CR>zz", { desc = "Jump to next item in quickfix list & recenter" })
vim.keymap.set("n", "<C-d>", "<C-d>zz", { desc = "Jump half page down & recenter" })
vim.keymap.set("n", "<C-u>", "<C-u>zz", { desc = "Jump half page up & recenter" })
vim.keymap.set("n", "<leader>j", "<cmd>lprev<CR>zz", { desc = "Jump to prev item in jumplist" })
vim.keymap.set("n", "<leader>k", "<cmd>lnext<CR>zz", { desc = "Jump to next item in jumplist" })
vim.keymap.set("n", "N", "Nzzzv", { desc = "prev search occurence & recenter" })
vim.keymap.set("n", "n", "nzzzv", { desc = "next search occurence & recenter" })

-- disable arrows
vim.keymap.set({ "n", "v", "x" }, "<Down>", "<nop>")
vim.keymap.set({ "n", "v", "x" }, "<Left>", "<nop>")
vim.keymap.set({ "n", "v", "x" }, "<Right>", "<nop>")
vim.keymap.set({ "n", "v", "x" }, "<Up>", "<nop>")

-- trouble
vim.keymap.set("n", "[t", ":lua require('trouble').previous({skip_groups = true, jump = true})<CR>",
    { desc = "Previous prev item" })
vim.keymap.set("n", "]t", ":lua require('trouble').next({skip_groups = true, jump = true})<CR>",
    { desc = "Next trouble item" })

-- terminals
local job_id = 0
vim.keymap.set("n", "<leader>ts", function()
    vim.cmd.vnew()
    vim.cmd.term()
    vim.cmd.wincmd("J")
    vim.api.nvim_win_set_height(0, 5)
    job_id = vim.bo.channel
end, { desc = "Scratch terminal" })

vim.keymap.set("n", "<leader>th", function()
    vim.fn.chansend(job_id, { "echo hi\r\n" })
end)
