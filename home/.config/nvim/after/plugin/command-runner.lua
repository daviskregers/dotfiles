-- TODO: Persist commands for each project
-- TODO: Menu to show all saved commands & choosing them
local M = {
    cmds = {
        'echo "SETUP COMMAND 1"',
        'echo "SETUP COMMAND 2"',
        'echo "SETUP COMMAND 3"',
        'echo "SETUP COMMAND 4"',
    }
}

M.run_function = function (n)
    print('Executing: ' .. M.cmds[n])
    vim.cmd(':vsplit |terminal ' .. M.cmds[n])
end

M.input = function (n)
    local value
    vim.ui.input({prompt='Input something: ', default=M.cmds[n]},
                 function(str) value = str end)

    print(value)
    if value == nil or value == '' then
        print('Ignoring empty input...')
    else
        M.cmds[n] = value
    end
end

vim.keymap.set("n", "<leader>h", function()
    M.run_function(1)
end, { buffer = true, noremap = true, silent = true })

vim.keymap.set("n", "<leader>H", function()
    M.input(1)
end, { buffer = true, noremap = true, silent = true })

vim.keymap.set("n", "<leader>j", function()
    M.run_function(2)
end, { buffer = true, noremap = true, silent = true })

vim.keymap.set("n", "<leader>J", function()
    M.input(2)
end, { buffer = true, noremap = true, silent = true })

vim.keymap.set("n", "<leader>k", function()
    M.run_function(3)
end, { buffer = true, noremap = true, silent = true })

vim.keymap.set("n", "<leader>K", function()
    M.input(3)
end, { buffer = true, noremap = true, silent = true })

vim.keymap.set("n", "<leader>l", function()
    M.run_function(4)
end, { buffer = true, noremap = true, silent = true })

vim.keymap.set("n", "<leader>L", function()
    M.input(4)
end, { buffer = true, noremap = true, silent = true })
