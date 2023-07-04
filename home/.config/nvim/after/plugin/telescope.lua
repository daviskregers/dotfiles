local ok_t, telescope = pcall(require, 'telescope')
if not ok_t then
	print "Failed to load plugin 'telescope', skipping setup"
	return
end

local ok_b, builtin = pcall(require, 'telescope.builtin')
if not ok_b then
	print "Failed to load plugin 'telescope.builtin', skipping setup"
	return
end

telescope.setup({
    extensions = {
        package_info = {
            -- Optional theme (the extension doesn't set a default theme)
            theme = "ivy",
        },
    },
})

vim.keymap.set('n', '<leader>pf', builtin.find_files, {})
vim.keymap.set('n', '<leader>pp', builtin.git_files, {})
vim.keymap.set('n', '<C-p>', ':Telescope fd<CR>', {})
vim.keymap.set('n', '<leader>ps', function()
    builtin.grep_string({ search = vim.fn.input("Grep > ")})
end)
