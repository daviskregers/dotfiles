vim.api.nvim_create_user_command("CopyLocation", function(opts)
    local file = vim.fn.expand("%:.")
    local loc
    if opts.range == 2 then
        local start_line = opts.line1
        local end_line = opts.line2
        if start_line == end_line then
            loc = string.format("%s:%d", file, start_line)
        else
            loc = string.format("%s:%d-%d", file, start_line, end_line)
        end
    else
        local line = vim.fn.line(".")
        loc = string.format("%s:%d", file, line)
    end
    vim.fn.setreg("+", loc)
    vim.notify(loc, vim.log.levels.INFO)
end, { range = true })

vim.keymap.set({ "n", "v" }, "<leader>c", function()
    local mode = vim.fn.mode()
    if mode == "v" or mode == "V" or mode == "\22" then
        vim.cmd('normal! "hy')
        local start_line = vim.fn.line("'<")
        local end_line = vim.fn.line("'>")
        vim.cmd(string.format("%d,%dCopyLocation", start_line, end_line))
    else
        vim.cmd("CopyLocation")
    end
end)
