return {
    "akinsho/git-conflict.nvim",
    dependencies = {
        "yorickpeterse/nvim-pqf",
    },
    version = "*",
    enabled = true,
    lazy = false,
    -- config = function ()
    --     local c = require('git-conflict')
    --     c.setup()
    --
    --     vim.api.nvim_create_autocmd({ 'User' }, {
    --         pattern = 'VeryLazy',
    --         callback = function()
    --             print('checking conflicts')
    --             local cmds = vim.inspect(vim.api.nvim_get_commands({}))
    --             local lines = {}
    --             for s in cmds:gmatch("[^\r\n]+") do
    --                 table.insert(lines, s)
    --             end
    --
    --             local buf = vim.api.nvim_create_buf(true, false)
    --             vim.api.nvim_buf_set_lines(buf, 0, -1, true, lines)
    --             vim.api.nvim_buf_set_option(buf, 'modifiable', false)
    --             vim.api.nvim_buf_set_name(buf, 'commands')
    --
    --             vim.cmd(':b ' .. buf)
    --
    --             -- print(cmds)
    --             -- vim.cmd { cmd = 'GitConflictListQf', args = {}, bang = false }
    --         end,
    --     })
    -- end,
    opts = {
        default_mappings = false,   -- disable buffer local mapping created by this plugin
        default_commands = true,   -- disable commands created by this plugin
        disable_diagnostics = false, -- This will disable the diagnostics in a buffer whilst it is conflicted
        list_opener = 'copen',     -- command or function to open the conflicts list
        highlights = {             -- They must have background color, otherwise the default color will be used
            incoming = 'DiffAdd',
            current = 'DiffText',
        }
    },
    keys = {
        { '<leader>gcl', ":GitConflictListQf<cr>", mode = { 'n', 'x' }, desc = 'List Git Conflicts' },
        { '<leader>gco', ":GitConflictChooseOurs<cr>", mode = { 'n', 'x' }, desc = 'Choose Our Git Conflict' },
        { '<leader>gct', ":GitConflictChooseTheirs<cr>", mode = { 'n', 'x' }, desc = 'Choose Their Git Conflict' },
        { '<leader>gcb', ":GitConflictChooseBoth<cr>", mode = { 'n', 'x' }, desc = 'Choose Both Git Conflicts' },
        { '<leader>gcn', ":GitConflictChooseNone<cr>", mode = { 'n', 'x' }, desc = 'Choose None Git Conflicts' },
    }
}
