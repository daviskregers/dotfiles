local M = {}

-- Build the text handed to the agent for one review comment. It's a snapshot,
-- not a live anchor: `file:start-end` coordinates, the selected lines fenced as
-- a code block, then the user's comment. The agent gets unambiguous location
-- plus the exact code, so nothing has to survive later edits.
function M.format_payload(path, start_line, end_line, content_lines, comment)
	local range = start_line == end_line and tostring(start_line) or (start_line .. "-" .. end_line)
	local out = { path .. ":" .. range, "```" }
	for _, line in ipairs(content_lines) do
		out[#out + 1] = line
	end
	out[#out + 1] = "```"
	out[#out + 1] = ""
	out[#out + 1] = comment
	return table.concat(out, "\n")
end

-- Wrap the payload in bracketed-paste markers (ESC[200~ … ESC[201~) so a TUI
-- like claude's takes the whole multi-line block as one paste — literal
-- newlines, no per-line submit — instead of firing each line as its own Enter.
-- The submitting CR is sent separately by the IO shell, after this lands.
function M.paste_sequence(payload)
	local esc = string.char(27)
	return esc .. "[200~" .. payload .. esc .. "[201~"
end

return M
