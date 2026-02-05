return {
{
		"99",
		dir = "~/Projects/productivity/99",
		config = function()
			local _99 = require("99")
			_99.setup({
				md_files = {
					"AGENTS.md",
                    "CLAUDE.md",
				},
                model = "github-copilot/claude-sonnet-4.5",
			})

			vim.keymap.set("n", "<leader>[", function()
				_99.fill_in_function()
			end, { desc = "99 Fill in function" })

			vim.keymap.set("v", "<leader>[", function()
				_99.visual()
			end, { desc = "99 Visual prompt" })

			vim.keymap.set("n", "<leader>]", function()
				_99.fill_in_function_prompt()
			end, { desc = "99 Fill in function with prompt" })

			vim.keymap.set("v", "<leader>]", function()
				_99.visual_prompt()
			end, { desc = "99 Visual prompt with prompt" })

			-- vim.keymap.set("n", "<leader>9fd", function()
			-- 	_99.fill_in_function({
			-- 		additional_rules = {
			--                      _99:rule_from_path("~/.behaviors/debug.md"),
			-- 		},
			-- 	})
			-- end)
			vim.keymap.set("n", "<leader>9s", function()
				_99.stop_all_requests()
			end, { desc = "99 Stop all requests" })
			vim.keymap.set("n", "<leader>9i", function()
				_99.info()
			end, { desc = "99 Info" })
			vim.keymap.set("n", "<leader>9l", function()
				_99.view_logs()
			end, { desc = "99 View logs" })
			vim.keymap.set("n", "<leader>9n", function()
				_99.next_request_logs()
			end, { desc = "99 Next request logs" })
			vim.keymap.set("n", "<leader>9p", function()
				_99.prev_request_logs()
			end, { desc = "99 Previous request logs" })
		end,
	},
}
