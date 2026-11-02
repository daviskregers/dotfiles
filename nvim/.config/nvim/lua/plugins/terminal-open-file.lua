local M = {}

-- Runs `action` in the first normal editor window of this tab, so files opened
-- from a terminal don't replace the terminal itself. Floats (notifications,
-- pickers) aren't editor windows, so they're skipped.
function M.do_in_non_terminal(action)
    for _, win_id in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        local buf = vim.api.nvim_win_get_buf(win_id)
        local is_float = vim.api.nvim_win_get_config(win_id).relative ~= ""

        if not is_float and vim.bo[buf].buftype ~= "terminal" then
            vim.api.nvim_set_current_win(win_id)
            action()
            return
        end
    end

    vim.cmd("topleft vsplit")
    action()
end

-- Agents print locations like `src/gen/settings.go:88:12`, often wrapped in
-- backticks or followed by punctuation. Returns path, line, col (line and col
-- may be nil).
function M.parse_location(word)
    word = word:gsub("^[`'\"(%[<]+", ""):gsub("[`'\",.;:)%]>]+$", "")

    local path, line, col = word:match("^(.-):(%d+):?(%d*)")
    if not path then
        return word, nil, nil
    end
    return path, tonumber(line), tonumber(col)
end

function M.open_location_under_cursor()
    local path, line, col = M.parse_location(vim.fn.expand("<cWORD>"))

    if vim.fn.isdirectory(path) == 1 then
        M.do_in_non_terminal(function()
            require("oil").open(path)
        end)
        return
    end

    if vim.fn.filereadable(path) == 0 then
        vim.notify("No readable file under cursor: " .. path, vim.log.levels.WARN)
        return
    end

    M.do_in_non_terminal(function()
        vim.cmd.edit(vim.fn.fnameescape(path))
        if line then
            line = math.min(line, vim.api.nvim_buf_line_count(0))
            vim.api.nvim_win_set_cursor(0, { line, math.max((col or 1) - 1, 0) })
            vim.cmd("normal! zz")
        end
    end)
end

return M
