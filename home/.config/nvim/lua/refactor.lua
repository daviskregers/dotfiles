require('refactoring').setup({})

-- Remaps for the refactoring operations currently offered by the plugin
vim.api.nvim_set_keymap("v", "<leader>re", [[ <Esc><Cmd>lua require('refactoring').refactor('Extract Function')<CR>]], {noremap = true, silent = true, expr = false})
vim.api.nvim_set_keymap("v", "<leader>rf", [[ <Esc><Cmd>lua require('refactoring').refactor('Extract Function To File')<CR>]], {noremap = true, silent = true, expr = false})
vim.api.nvim_set_keymap("v", "<leader>rv", [[ <Esc><Cmd>lua require('refactoring').refactor('Extract Variable')<CR>]], {noremap = true, silent = true, expr = false})
vim.api.nvim_set_keymap("v", "<leader>ri", [[ <Esc><Cmd>lua require('refactoring').refactor('Inline Variable')<CR>]], {noremap = true, silent = true, expr = false})

-- Extract block doesn't need visual mode
vim.api.nvim_set_keymap("n", "<leader>rb", [[ <Cmd>lua require('refactoring').refactor('Extract Block')<CR>]], {noremap = true, silent = true, expr = false})
vim.api.nvim_set_keymap("n", "<leader>rbf", [[ <Cmd>lua require('refactoring').refactor('Extract Block To File')<CR>]], {noremap = true, silent = true, expr = false})

-- Inline variable can also pick up the identifier currently under the cursor without visual mode
vim.api.nvim_set_keymap("n", "<leader>ri", [[ <Cmd>lua require('refactoring').refactor('Inline Variable')<CR>]], {noremap = true, silent = true, expr = false})

-- -- prompt for a refactor to apply when the remap is triggered
-- vim.api.nvim_set_keymap(
--     "v",
--     "<leader>rr",
--     ":lua require('refactoring').select_refactor()<CR>",
--     { noremap = true, silent = true, expr = false }
-- )

-- load refactoring Telescope extension
require("telescope").load_extension("refactoring")

-- remap to open the Telescope refactoring menu in visual mode
vim.api.nvim_set_keymap(
	"v",
	"<leader>rr",
	"<Esc><cmd>lua require('telescope').extensions.refactoring.refactors()<CR>",
	{ noremap = true }
)

--- php-refactoring-toolbox.vim

vim.api.nvim_set_keymap('n', '<leader>rpc', ':call PhpCreateProperty()<CR>', { noremap = true, silent = true, expr = false })
vim.api.nvim_set_keymap('n', '<leader>rpd', ':call PhpDocAll()<CR>', { noremap = true, silent = true, expr = false })
vim.api.nvim_set_keymap('n', '<leader>rpe', ':call PhpExtractUse()<CR>', { noremap = true, silent = true, expr = false })
vim.api.nvim_set_keymap('n', '<leader>rpg', ':call PhpCreateSettersAndGetters()<CR>', { noremap = true, silent = true, expr = false })
vim.api.nvim_set_keymap('n', '<leader>rpl', ':call PhpRenameLocalVariable()<CR>', { noremap = true, silent = true, expr = false })
vim.api.nvim_set_keymap('n', '<leader>rpp', ':call PhpExtractClassProperty()<CR>', { noremap = true, silent = true, expr = false })
vim.api.nvim_set_keymap('n', '<leader>rpr', ':call PhpRenameMethod()<CR>', { noremap = true, silent = true, expr = false })
vim.api.nvim_set_keymap('n', '<leader>rpu', ':call PhpDetectUnusedUseStatements()<CR>', { noremap = true, silent = true, expr = false })
vim.api.nvim_set_keymap('n', '<leader>rpv', ':call PhpRenameClassVariable()<CR>', { noremap = true, silent = true, expr = false })
vim.api.nvim_set_keymap('v', '<leader>rp=', ':call PhpAlignAssigns()<CR>', { noremap = true, silent = true, expr = false })
vim.api.nvim_set_keymap('v', '<leader>rpc', ':call PhpExtractConst()<CR>', { noremap = true, silent = true, expr = false })
vim.api.nvim_set_keymap('v', '<leader>rpm', ':call PhpExtractMethod()<CR>', { noremap = true, silent = true, expr = false })
