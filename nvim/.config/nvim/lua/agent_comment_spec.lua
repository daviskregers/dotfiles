local agent_comment = require("agent_comment")

describe("agent_comment.format_payload", function()
	it("stacks file:range, a fenced code block of the selection, then the comment", function()
		local payload = agent_comment.format_payload(
			"lua/foo.lua",
			12,
			14,
			{ "local x = 1", "local y = 2", "return x + y" },
			"this could be a one-liner"
		)

		assert.are.equal(
			table.concat({
				"lua/foo.lua:12-14",
				"```",
				"local x = 1",
				"local y = 2",
				"return x + y",
				"```",
				"",
				"this could be a one-liner",
			}, "\n"),
			payload
		)
	end)

	it("collapses a single-line selection to file:line, not file:line-line", function()
		local payload = agent_comment.format_payload("lua/foo.lua", 12, 12, { "local x = 1" }, "rename x")

		assert.are.equal(
			table.concat({
				"lua/foo.lua:12",
				"```",
				"local x = 1",
				"```",
				"",
				"rename x",
			}, "\n"),
			payload
		)
	end)
end)

describe("agent_comment.paste_sequence", function()
	it("wraps the payload in bracketed-paste markers so a multi-line block lands as one message", function()
		local esc = string.char(27)
		assert.are.equal(
			esc .. "[200~" .. "line one\nline two" .. esc .. "[201~",
			agent_comment.paste_sequence("line one\nline two")
		)
	end)
end)
