-- Reload buffers whose file changed on disk (agents, git checkouts). autoread
-- alone only acts when nvim happens to check, so trigger the check on focus,
-- buffer switch and idle. Modified buffers are left to nvim's W12 prompt.
local M = {}

function M.setup()
	vim.o.autoread = true
	vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "CursorHold" }, {
		group = vim.api.nvim_create_augroup("DkDiskReload", { clear = true }),
		callback = function(args)
			-- checktime errors in the command-line window. A bare `checktime`
			-- inside an autocmd is postponed; with a buffer number it runs now.
			if vim.fn.getcmdwintype() == "" and vim.bo[args.buf].buftype == "" then
				vim.cmd.checktime(args.buf)
			end
		end,
	})
end

return M
