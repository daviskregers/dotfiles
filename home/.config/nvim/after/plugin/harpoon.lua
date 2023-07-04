local ok_m, mark = pcall(require, 'harpoon.mark')
local ok_u, ui = pcall(require, 'harpoon.ui')

if not ok_m then
	print "Failed to load plugin 'harpoon.mark', skipping setup..."
	return
end

if not ok_u then
	print "Failed to load plugin 'harpoon.ui', skipping setup..."
	return
end

vim.keymap.set("n", "<leader>a", mark.add_file)
vim.keymap.set("n", "<C-e>", ui.toggle_quick_menu)

vim.keymap.set("n", "<C-h>", function () ui.nav_file(1) end)
vim.keymap.set("n", "<C-j>", function () ui.nav_file(2) end)
vim.keymap.set("n", "<C-k>", function () ui.nav_file(3) end)
vim.keymap.set("n", "<C-l>", function () ui.nav_file(4) end)
