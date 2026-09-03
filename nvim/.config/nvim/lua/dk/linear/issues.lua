-- Pure shaping for the assigned-issue list: raw GraphQL nodes in, sorted and
-- rendered picker rows out. No network, no telescope, no buffers — so the
-- ordering rules can be tested without a Linear API key.

local M = {}

-- Active work first, then the things waiting on a decision, then the queue.
-- Linear's own progression (triage -> backlog -> todo -> in progress) is the
-- wrong way round for "what am I on right now".
-- completed/canceled are filtered out of the assigned query, but a favorited
-- issue is included whatever its state, so they need a rank of their own rather
-- than falling through to UNKNOWN.
local STATE_RANK = {
    started = 1,
    triage = 2,
    unstarted = 3,
    backlog = 4,
    completed = 5,
    canceled = 6,
}
local UNKNOWN_STATE_RANK = 99

local STAR = "★"
local GAP = "  "

local function unnil(value)
    if value == nil or value == vim.NIL then
        return nil
    end
    return value
end

--- Flatten one Linear GraphQL issue node into the record the picker uses.
--- JSON nulls arrive as vim.NIL, which is truthy in Lua — collapse them here so
--- nothing downstream has to remember that.
--- @param node table
--- @return table
function M.normalize(node)
    local state = node.state or {}
    return {
        id = node.id,
        identifier = node.identifier,
        title = node.title,
        url = node.url,
        branch = unnil(node.branchName),
        description = unnil(node.description),
        favorite = unnil(node.favorite) ~= nil,
        state_name = state.name,
        state_type = state.type,
        state_position = state.position,
    }
end

-- "ENG-45" sorts before "ENG-123": compare the team prefix as text and the
-- issue number as a number, not the identifier as one string.
local function identifier_lt(a, b)
    local a_team, a_num = tostring(a):match("^(.-)%-(%d+)$")
    local b_team, b_num = tostring(b):match("^(.-)%-(%d+)$")
    if not a_team or not b_team then
        return tostring(a) < tostring(b)
    end
    if a_team ~= b_team then
        return a_team < b_team
    end
    return tonumber(a_num) < tonumber(b_num)
end

--- Merge the assigned and favorited lists into one, keyed on issue id. An issue
--- that is both appears once, and the copy that knows it is favorited wins —
--- order of arrival must not decide whether it sorts to the top.
--- @param list table[]
--- @return table[]
function M.dedupe(list)
    local seen, out = {}, {}
    for _, issue in ipairs(list) do
        local at = seen[issue.id]
        if not at then
            out[#out + 1] = issue
            seen[issue.id] = #out
        elseif issue.favorite and not out[at].favorite then
            out[at] = issue
        end
    end
    return out
end

--- Sort a copy: favorites first, then state type, then the team's own state
--- order, then identifier so the list never reshuffles between refreshes.
--- @param list table[]
--- @return table[]
function M.sort(list)
    local sorted = vim.deepcopy(list)
    table.sort(sorted, function(a, b)
        if a.favorite ~= b.favorite then
            return a.favorite
        end
        local a_rank = STATE_RANK[a.state_type] or UNKNOWN_STATE_RANK
        local b_rank = STATE_RANK[b.state_type] or UNKNOWN_STATE_RANK
        if a_rank ~= b_rank then
            return a_rank < b_rank
        end
        if a.state_position ~= b.state_position then
            return (a.state_position or 0) < (b.state_position or 0)
        end
        return identifier_lt(a.identifier, b.identifier)
    end)
    return sorted
end

local function pad(text, width)
    return text .. string.rep(" ", width - vim.fn.strdisplaywidth(text))
end

--- Render picker rows with identifier and state padded to the widest in the
--- list, so titles start at the same column on every line.
--- @param list table[]
--- @return table[] rows { issue, display, ordinal }
function M.rows(list)
    local id_width, state_width = 0, 0
    for _, issue in ipairs(list) do
        id_width = math.max(id_width, vim.fn.strdisplaywidth(issue.identifier or ""))
        state_width = math.max(state_width, vim.fn.strdisplaywidth(issue.state_name or ""))
    end

    local rows = {}
    for _, issue in ipairs(list) do
        local mark = issue.favorite and STAR or " "
        rows[#rows + 1] = {
            issue = issue,
            display = mark .. " " .. table.concat({
                pad(issue.identifier or "", id_width),
                pad(issue.state_name or "", state_width),
                issue.title or "",
            }, GAP):gsub("%s+$", ""),
            ordinal = table.concat({ issue.identifier or "", issue.state_name or "", issue.title or "" }, " "),
        }
    end
    return rows
end

--- Render one issue as markdown lines for the left-hand buffer. Returns lines,
--- never a blob: nvim_buf_set_lines rejects strings containing newlines, and a
--- Linear description is always multi-line.
--- @param issue table
--- @return string[]
function M.render(issue)
    local lines = {
        "# " .. (issue.identifier or "") .. " " .. (issue.title or ""),
        "",
        "Status:  " .. (issue.state_name or "unknown"),
        "Branch:  " .. (issue.branch or "-"),
        "Link:    " .. (issue.url or "-"),
        "",
        "---",
        "",
    }
    if issue.description and vim.trim(issue.description) ~= "" then
        vim.list_extend(lines, vim.split(issue.description, "\r?\n"))
    else
        lines[#lines + 1] = "_No description._"
    end
    return lines
end

--- The slug Linear already made for us. `branchName` is
--- `<user>/<team>-<n>-<slugified-title>` and is never null, so we reuse their
--- slugification instead of reinventing it over the raw title.
--- @param branch string
--- @param identifier string
--- @return string
function M.slug(branch, identifier)
    local tail = tostring(branch or ""):match("[^/]*$") or ""
    local id = tostring(identifier or ""):lower()
    -- A titleless issue's branch is just the identifier, with no trailing dash
    -- for the prefix strip below to find.
    if tail:lower() == id then
        return ""
    end
    local prefix = id .. "-"
    if tail:sub(1, #prefix):lower() == prefix then
        tail = tail:sub(#prefix + 1)
    end
    return tail
end

--- Directory name for an issue's notes: the identifier as Linear shows it,
--- plus their slug.
--- @param identifier string
--- @param branch string
--- @return string
function M.notes_dirname(identifier, branch)
    local slug = M.slug(branch, identifier)
    if slug == "" then
        return identifier
    end
    return identifier .. "-" .. slug
end

-- Everything below the `# <identifier>` heading. Predictions are the point:
-- claims committed to before an agent touches the file, so the score afterwards
-- measures the map rather than the agent's answer.
local NOTES_BODY = [[
## Unknowns
-

## Predictions

Three answers, written before any agent reads this file.
Rule: if I can't check my answer myself, it isn't an answer.

1. **What happens now?**
   Pick one specific input. Say what you'd see if you ran it.
   e.g. "Submitting an expired code returns 401 with key `x.incorrect`."
   - [ ] Ran it and read the output myself. No agent — an agent describing
         what an endpoint returns is guessing at something you can observe.

2. **Who else touches this?**
   What other code calls this, or uses what it hands back.
   e.g. "Three callers: the import command, the reset service, the web form.
   The Vue page reads the error key to pick a message."
   - [ ] Found the callers myself, with grep or LSP references.
   - [ ] Fresh agent as a second pass — cross-component callers are where
         those tools genuinely stop.

3. **What could this change break?**
   e.g. "If the error key changes, the Vue page falls through to a generic
   message and support loses the ability to tell the two cases apart."
   - [ ] Fresh agent in the repo. Needs a reader holding the whole picture,
         and running it proves nothing here.

## Score

Agent refutes each claim against the code, citing locations. Then:

- **All right** → the map is good enough. Hand over a large slice.
- **1–2 wrong** → one more round, on the wrong claims only.
- **3+ wrong** → no model. Read the code myself on those specific gaps first.
]]

--- Starting contents of a fresh notes file. Written once, at creation — never
--- reapplied, so editing or deleting these lines sticks.
--- @param identifier string
--- @return string[]
function M.notes_template(identifier)
    local lines = { "# " .. identifier }
    vim.list_extend(lines, vim.split(vim.trim(NOTES_BODY), "\n"))
    return lines
end

--- Where an issue's notes live inside the notes root.
--- @param root string
--- @param dirname string
--- @return string
function M.notes_path(root, dirname)
    return root .. "/" .. dirname .. "/notes.md"
end

return M
