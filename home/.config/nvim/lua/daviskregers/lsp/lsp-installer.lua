local status_ok, lsp_installer = pcall(require, "nvim-lsp-installer")
if not status_ok then
    vim.notify("Error loading nvim-lsp-installer")
	return
end

-- Register a handler that will be called for all installed servers.
-- Alternatively, you may also register handlers on specific server instances instead (see example below).
lsp_installer.on_server_ready(function(server)
	local opts = {
		on_attach = require("daviskregers.lsp.handlers").on_attach,
		capabilities = require("daviskregers.lsp.handlers").capabilities,
	}

    local config_loaded, server_opts = pcall(require, "daviskregers.lsp.settings." .. server.name)
    if not config_loaded then
        -- vim.notify("Error loading LSP settings for " .. server.name)
        server_opts = {}
    end

    opts = vim.tbl_deep_extend("force", server_opts, opts)

	-- This setup() function is exactly the same as lspconfig's setup function.
	-- Refer to https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md
	server:setup(opts)
end)

