require("telescope").load_extension("refactoring")
vim.api.nvim_set_keymap(
	"v",
	"gR",
	"<Esc><cmd>lua require('telescope').extensions.refactoring.refactors()<CR>",
	{ noremap = true }
)

require('refactoring').setup({})
