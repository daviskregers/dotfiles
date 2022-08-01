local status_ok, _ = pcall(require, "lspconfig")
if not status_ok then
    vim.notify("Error loading lspconfig")
	return
end

require("daviskregers.lsp.lsp-installer")
require("daviskregers.lsp.handlers").setup()
require("daviskregers.lsp.null-ls")
