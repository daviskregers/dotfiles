local augroup = vim.api.nvim_create_augroup("PhpImportRemove", { clear = true })

local function main()
    -- print("REMOVEING PHP IMPORTS")
    local bufnr = vim.api.nvim_get_current_buf()
    local issues = vim.diagnostic.get(bufnr)
    local empty_lines = {}
    local current_window = vim.api.nvim_get_current_win()
    local initial_cursor_pos = vim.api.nvim_win_get_cursor(current_window)
    -- print("Initial cursor pos: " .. vim.inspect(initial_cursor_pos))

    for _, issue in ipairs(issues) do
        if issue.code == nil then
            goto continue
        end

        -- print("Issue: " .. issue.code)
        if issue.code == "P1003" then
            print("Removing PHP import: " .. issue.message)
            -- print(vim.inspect(issue))
            -- function vim.api.nvim_buf_set_text(buffer: integer,
            --     start_row: integer,
            --     start_col: integer,
            --     end_row: integer,
            --     end_col: integer,
            --     replacement: string[])
            vim.api.nvim_buf_set_text(
                issue.bufnr,
                issue.lnum,
                issue.col,
                issue.end_lnum,
                issue.end_col,
                {}
            )

            empty_lines[issue.lnum] = true
        end
        ::continue::
    end

    local num_deleted = 0
    for line, _ in pairs(empty_lines) do
        line = line - num_deleted
        vim.api.nvim_win_set_cursor(current_window, {line - num_deleted, 0})

        local line_content = vim.api.nvim_get_current_line()
        if line_content ~= "" then
            -- print("Line is not empty" .. line_content)
            goto continue
        end

        -- print("Deleting line: " .. line)
        vim.api.nvim_del_current_line()
        num_deleted = num_deleted + 1
        ::continue::
    end

    vim.api.nvim_win_set_cursor(current_window, {
        initial_cursor_pos[1] - num_deleted,
        initial_cursor_pos[2]
    })
end

local function setup()
    local events = {"BufWritePre", "FileWritePre"}

    for _, event in ipairs(events) do
        vim.api.nvim_create_autocmd(event,
            {
                group = augroup,
                desc = "Remove unused PHP imports - " .. event,
                callback = main
            })
    end
end

return { setup = setup }
