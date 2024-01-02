vim.keymap.set("n", "<leader>pv", vim.cmd.Ex, { desc = "Open file explorer (Ex)" })

vim.keymap.set("n", "<leader>s", [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]],
    { desc = "search & replace work under cursor" })

vim.keymap.set({ "n", "v" }, "<leader>y", [["+y]], { desc = "yank to clipboard" })

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

-- disable keys
vim.keymap.set({ "n", "v", "x" }, "<Down>", "<nop>")
vim.keymap.set({ "n", "v", "x" }, "<Left>", "<nop>")
vim.keymap.set({ "n", "v", "x" }, "<Right>", "<nop>")
vim.keymap.set({ "n", "v", "x" }, "<Up>", "<nop>")

-- neogen
vim.keymap.set("n", "<Leader>nc", ":lua require('neogen').generate({ type = 'class' })<CR>", {desc = "generate class docs"})
vim.keymap.set("n", "<Leader>nf", ":lua require('neogen').generate({ type = 'func' })<CR>", {desc = "generate function docs"})
vim.keymap.set("n", "<Leader>nF", ":lua require('neogen').generate({ type = 'file' })<CR>", {desc = "generate file docs"})
vim.keymap.set("n", "<Leader>nt", ":lua require('neogen').generate({ type = 'type' })<CR>", {desc = "generate type docs"})
