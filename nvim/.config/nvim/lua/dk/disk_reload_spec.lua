local disk_reload = require("dk.disk_reload")

-- Rewrites the file the way an agent would: a different size, so nvim's
-- mtime+size check sees the change even within the same second.
local function rewrite(path, lines)
	local f = assert(io.open(path, "w"))
	f:write(table.concat(lines, "\n") .. "\n")
	f:close()
end

describe("dk.disk_reload", function()
	local path

	before_each(function()
		path = vim.fn.tempname() .. ".txt"
		rewrite(path, { "original" })
		vim.cmd.edit(path)
		disk_reload.setup()
	end)

	after_each(function()
		vim.cmd("bwipeout!")
		os.remove(path)
	end)

	for _, event in ipairs({ "FocusGained", "BufEnter", "CursorHold" }) do
		it("reloads an unmodified buffer changed on disk on " .. event, function()
			rewrite(path, { "rewritten by agent", "second line" })

			vim.api.nvim_exec_autocmds(event, { buffer = 0 })

			assert.are.same({ "rewritten by agent", "second line" }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
		end)
	end
end)
