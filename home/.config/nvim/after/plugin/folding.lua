local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities.textDocument.foldingRange = {
    dynamicRegistration = false,
    lineFoldingOnly = true
}

local ok, lspconfig = pcall(require, 'lspconfig')
if not ok then
	print "Failed to load plugin 'lspconfig', skipping setup..."
else
	local language_servers = lspconfig.util.available_servers() -- or list servers manually like {'gopls', 'clangd'}
	for _, ls in ipairs(language_servers) do
	    require('lspconfig')[ls].setup({
		capabilities = capabilities
		-- you can add other fields for setting up lsp server in this table
	    })
	end
end


local ok, ufo = pcall(require, 'ufo')

if not ok then
	print "Failed to load plugin 'ufo', skipping setup..."
else
	ufo.setup()
end
