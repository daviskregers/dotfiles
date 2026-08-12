local M = {}

-- The +/- lines of a hunk, in order (context dropped). This is the unit both
-- the content key and the staged-status check are built from.
local function changed_lines(hunk)
	local out = {}
	for _, line in ipairs(hunk.lines) do
		local first = line:sub(1, 1)
		if first == "+" or first == "-" then
			out[#out + 1] = line
		end
	end
	return out
end

-- A hunk's identity is its file path plus the content it adds/removes. Line
-- numbers (the @@ header) and surrounding context are excluded on purpose: they
-- shift as edits land above, but the change itself is what we're reviewing. If
-- the +/- content changes, it's genuinely a different hunk.
function M.hunk_key(hunk)
	return hunk.file .. "\0" .. vim.fn.sha256(table.concat(changed_lines(hunk), "\n"))
end

-- The quickfix jump line: git's @@ header points at the start of the hunk,
-- which includes leading context lines (3 by default). Walk past that context
-- so the cursor lands on the first line that actually changed, not the context
-- above it.
local function first_changed_lnum(lines)
	local lnum = tonumber(lines[1]:match("^@@ %-%d+,?%d* %+(%d+)"))
	for i = 2, #lines do
		local mark = lines[i]:sub(1, 1)
		if mark == " " then
			lnum = lnum + 1
		else
			break -- first added/removed line
		end
	end
	return lnum
end

-- Split unified-diff text (`git diff HEAD`) into one object per hunk. Each hunk
-- carries its file path, the line of its first change (for the quickfix jump),
-- and the raw hunk lines including the @@ header.
function M.parse_diff(text)
	local hunks = {}
	local file = nil
	local is_new = false -- current file is a newly-added file (old side /dev/null)
	local current = nil

	for line in (text .. "\n"):gmatch("(.-)\n") do
		if line:match("^diff %-%-git ") then
			current = nil
			is_new = false
		elseif line:match("^%-%-%- /dev/null") then
			is_new = true
		elseif line:match("^%+%+%+ b/") then
			file = line:match("^%+%+%+ b/(.*)$")
		elseif line:match("^@@ ") then
			current = { file = file, is_new = is_new, lines = { line } }
			hunks[#hunks + 1] = current
		elseif current then
			current.lines[#current.lines + 1] = line
		end
	end

	for _, h in ipairs(hunks) do
		h.lnum = first_changed_lnum(h.lines)
	end

	return hunks
end

-- New files are keyed by path (like their untracked form) so `git add`-ing one
-- keeps its identity; every other hunk is keyed by content.
local function key_of(hunk)
	return hunk.is_new and hunk.file or M.hunk_key(hunk)
end

-- Turn raw git output into keyed, stage-tagged hunks.
--
-- The primary hunk set comes from `git diff HEAD` (working tree vs HEAD), whose
-- output is invariant under staging — so a hunk's key and position never change
-- when you stage it. Untracked files have no diff entry, so each becomes one
-- whole-file unstaged hunk keyed by its path.
--
-- Status is decided at LINE granularity, not by matching whole hunks: git
-- coalesces staged and unstaged edits into one big HEAD hunk whose content
-- matches no single --cached hunk, so a whole-hunk key can't tell them apart
-- (every partially-staged hunk would wrongly read U). Instead we count how many
-- of a hunk's changed lines also appear in the --cached diff: all -> S, none ->
-- U, some -> P. The staged lines form a multiset so a line staged once can't
-- match twice across hunks.
function M.collect(head_text, staged_text, untracked_paths)
	local staged_count = {}
	for _, h in ipairs(M.parse_diff(staged_text or "")) do
		for _, line in ipairs(changed_lines(h)) do
			local k = h.file .. "\0" .. line
			staged_count[k] = (staged_count[k] or 0) + 1
		end
	end

	local hunks = {}
	for _, h in ipairs(M.parse_diff(head_text or "")) do
		h.key = key_of(h)
		local lines = changed_lines(h)
		local matched = 0
		for _, line in ipairs(lines) do
			local k = h.file .. "\0" .. line
			if (staged_count[k] or 0) > 0 then
				staged_count[k] = staged_count[k] - 1
				matched = matched + 1
			end
		end
		if #lines > 0 and matched == #lines then
			h.status = "S"
		elseif matched == 0 then
			h.status = "U"
		else
			h.status = "P"
		end
		hunks[#hunks + 1] = h
	end

	for _, path in ipairs(untracked_paths or {}) do
		hunks[#hunks + 1] = {
			file = path,
			lnum = 1,
			lines = { "@@ new file @@" },
			key = path,
			status = "U",
		}
	end

	return hunks
end

-- Map hunks to quickfix entries. The preview is the first added/removed line so
-- the qflist reads like a change summary; falls back to the hunk header.
function M.to_qf_items(hunks)
	local items = {}
	for _, h in ipairs(hunks) do
		-- Prefer the first added line (what the agent wrote); else first removed;
		-- else the hunk header.
		local preview = h.lines[1]
		local first_removed = nil
		for _, line in ipairs(h.lines) do
			local mark = line:sub(1, 1)
			if mark == "+" then
				preview = line
				break
			elseif mark == "-" and first_removed == nil then
				first_removed = line
			end
		end
		if preview == h.lines[1] and first_removed ~= nil then
			preview = first_removed
		end
		items[#items + 1] = {
			filename = h.file,
			lnum = h.lnum,
			text = "[" .. (h.status or "?") .. "] " .. preview,
		}
	end
	return items
end

-- A registry stamps each hunk key with a monotonic sequence number the first
-- time it is seen, then orders the current hunks by that sequence. New hunks
-- always sort to the back; hunks that only slid (same key) keep their place.
function M.new_registry()
	local seq = 0
	local first_seen = {} -- key -> sequence number

	local reg = {}

	function reg:update(hunks)
		for _, h in ipairs(hunks) do
			if first_seen[h.key] == nil then
				seq = seq + 1
				first_seen[h.key] = seq
			end
		end

		local ordered = {}
		for _, h in ipairs(hunks) do
			ordered[#ordered + 1] = h
		end
		table.sort(ordered, function(a, b)
			return first_seen[a.key] < first_seen[b.key]
		end)
		return ordered
	end

	return reg
end

return M
