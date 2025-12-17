local M = {}

function M.is_terminal_buffer()
    return vim.bo.buftype == "terminal"
end

function M.do_in_non_terminal(action)
    local windows = vim.api.nvim_tabpage_list_wins(0)

    for _, win_id in ipairs(windows) do
        local win_buf_id = vim.api.nvim_win_get_buf(win_id)

        if not vim.api.nvim_get_option_value("buftype", { buf = win_buf_id }):match("terminal") then
            vim.api.nvim_set_current_win(win_id)
            action()
            return
        end
    end

    vim.cmd("topleft vsplit " .. vim.fn.expand("%:p"))
end

function M.open_file_under_cusror()
    local file = vim.fn.expand("<cfile>")

    if vim.fn.isdirectory(file) == 1 then
        M.do_in_non_terminal(function()
            require("oil").open(file)
        end)
        return
    end

    if vim.fn.filereadable(file) == 1 then
        M.do_in_non_terminal(function()
            vim.cmd("edit " .. file)
        end)
    else
        print("No readable file under cursor: " .. file)
    end
end

return M
