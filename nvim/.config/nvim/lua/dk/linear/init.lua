-- Telescope list of the Linear issues assigned to me, favourites first, then by
-- status. Enter opens the issue on the left and my notes for it on the right.
--
-- Needs $LINEAR_API_KEY (linear.app > Settings > Security & access > Personal
-- API keys). Everything worth testing lives in issues/client/notes; this file is
-- wiring.

local issues = require("dk.linear.issues")
local client = require("dk.linear.client")
local notes = require("dk.linear.notes")

local M = {}

local function issue_lines(bufnr, issue)
    vim.bo[bufnr].modifiable = true
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, issues.render(issue))
    vim.bo[bufnr].modifiable = false
    vim.bo[bufnr].filetype = "markdown"
end

--- New tab: issue read-only on the left, notes file on the right, cursor in the
--- notes so I can start typing straight away.
--- @param issue table
function M.open_issue(issue)
    local path = notes.ensure(notes.root(vim.fn.getcwd()), issue)

    vim.cmd("tabnew")
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.bo[bufnr].buftype = "nofile"
    vim.bo[bufnr].bufhidden = "wipe"
    pcall(vim.api.nvim_buf_set_name, bufnr, "linear://" .. issue.identifier)
    issue_lines(bufnr, issue)
    vim.api.nvim_win_set_buf(0, bufnr)

    -- `rightbelow` rather than a bare vsplit: without it the new window lands on
    -- whichever side 'splitright' says, and the notes could open on the left.
    vim.cmd("rightbelow vsplit " .. vim.fn.fnameescape(path))
end

--- Hand an issue's Linear URL to the OS browser.
--- @param issue table
function M.open_in_browser(issue)
    local url = issue and issue.url
    if not url or url == "" then
        vim.notify("No URL on " .. ((issue or {}).identifier or "issue"), vim.log.levels.WARN, { title = "Linear" })
        return
    end
    vim.ui.open(url)
end

local function picker(list)
    local pickers = require("telescope.pickers")
    local finders = require("telescope.finders")
    local previewers = require("telescope.previewers")
    local actions = require("telescope.actions")
    local action_state = require("telescope.actions.state")
    local conf = require("telescope.config").values
    local themes = require("telescope.themes")

    local rows = issues.rows(issues.sort(list))

    pickers.new(themes.get_ivy({}), {
        prompt_title = "Linear — assigned to me",
        finder = finders.new_table({
            results = rows,
            entry_maker = function(row)
                return {
                    value = row.issue,
                    issue = row.issue,
                    display = row.display,
                    ordinal = row.ordinal,
                }
            end,
        }),
        -- Only kicks in once I type; with an empty prompt telescope keeps the
        -- finder's order, which is the favourite/status order we just built.
        sorter = conf.generic_sorter({}),
        previewer = previewers.new_buffer_previewer({
            title = "Issue",
            define_preview = function(self, entry)
                issue_lines(self.state.bufnr, entry.issue)
            end,
        }),
        attach_mappings = function(prompt_bufnr, map)
            actions.select_default:replace(function()
                local entry = action_state.get_selected_entry()
                actions.close(prompt_bufnr)
                if entry then
                    M.open_issue(entry.issue)
                end
            end)
            -- Deliberately leaves the picker open: the browser takes focus
            -- anyway, and coming back to the list beats reopening it.
            map({ "i", "n" }, "<C-o>", function()
                local entry = action_state.get_selected_entry()
                if entry then
                    M.open_in_browser(entry.issue)
                end
            end)
            return true
        end,
    }):find()
end

--- Fetch and show the picker. Async — nvim stays usable while curl runs.
function M.open()
    client.fetch(function(nodes, err)
        if err then
            vim.notify(err, vim.log.levels.ERROR, { title = "Linear" })
            return
        end
        if #nodes == 0 then
            vim.notify("Nothing assigned to you.", vim.log.levels.INFO, { title = "Linear" })
            return
        end
        picker(issues.dedupe(vim.tbl_map(issues.normalize, nodes)))
    end)
end

vim.api.nvim_create_user_command("LinearIssues", M.open, { desc = "Linear issues assigned to me" })
vim.keymap.set("n", "<leader>li", M.open, { desc = "Linear issues assigned to me" })

return M
