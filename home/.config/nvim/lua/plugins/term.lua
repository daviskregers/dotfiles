return {
    'akinsho/toggleterm.nvim',
    version = "*",
    config = function()
        require('toggleterm').setup({
            size = 20,
            open_mapping = [[<c-\>]],
            hide_numbers = true,
            shade_filetypes = {},
            shade_terminals = true,
            shading_factor = 2,
            start_in_insert = true,
            insert_mappings = true,
            persist_size = true,
            direction = "float",
            close_on_exit = true,
            shell = vim.o.shell,
            float_opts = {
                border = "curved",
                winblend = 0,
                highlights = {
                    border = "Normal",
                    background = "Normal",
                },
            },
        })

        local Terminal = require("toggleterm.terminal").Terminal
        local lazygit = Terminal:new({ cmd = "lazygit", hidden = true })

        vim.keymap.set("n", "<leader>gg", function() lazygit:toggle() end, { desc = 'git - toggle laztgit' })


        local defaultTestCommands = {
            typescript = {
                test = "pnpm test",
                lint = "pnpm lint",
                watch = "nodemon --exec 'clear && pnpm test' -e ts,js"
            },
            javascript = {
                test = "pnpm test",
                lint = "pnpm lint",
                watch = "nodemon --exec 'clear && pnpm test' -e ts,js"
            },
            php = {
                test = "composer test %"
            },
            dockerfile = {
                test = "docker build ."
            },
            go = {
                test = "go test",
                run = "go run .",
            }
        }

        -- vim.api.nvim_create_autocmd('User', {
        --     pattern = '*',
        --     callback = function(ev)
        --         print(string.format('event fired: %s', vim.inspect(ev)))
        --     end
        -- })
        local COMMAND_ARGS = {}

        vim.api.nvim_create_autocmd('User', {
            pattern = 'ConfigLocalFinished',
            callback = function()
                if CONFIG_TEST_COMMANDS ~= nil then
                    print('Overriding test commands')
                    print(vim.inspect(CONFIG_TEST_COMMANDS))
                    for filetype, commands in pairs(CONFIG_TEST_COMMANDS) do
                        print(string.format('Overriding test commands for %s', filetype))
                        print(vim.inspect(commands))
                        for command, value in pairs(commands) do
                            print(string.format('[%s] Overriding %s with %s', filetype, command, value))
                            if defaultTestCommands[filetype] == nil then
                                defaultTestCommands[filetype] = {}
                            end
                            defaultTestCommands[filetype][command] = value
                        end
                    end
                end

                -- print(vim.inspect(defaultTestCommands))

                local types = {
                    { "l", "test" },
                    { "g", "lint" },
                    { "w", "watch" },
                    { "r", "run" },
                }

                for filetype, commands in pairs(defaultTestCommands) do
                    for _, type in ipairs(types) do
                        local key, command = unpack(type)
                        vim.api.nvim_create_autocmd('FileType', {
                            pattern = filetype,
                            callback = function()
                                local argKey = filetype .. ':::' .. command
                                if COMMAND_ARGS[argKey] == nil then
                                    COMMAND_ARGS[argKey] = ''
                                end

                                vim.keymap.set("n", "<leader>t" .. key, function()
                                    if command[command] == nil then
                                        print(string.format('No command found for %s', command))
                                        return
                                    end
                                    vim.cmd('vsplit')
                                    vim.cmd(string.format('term %s %s', commands[command], COMMAND_ARGS[argKey]))
                                end)

                                vim.keymap.set("n", "<leader>t" .. string.upper(key), function()
                                    COMMAND_ARGS[argKey] = vim.fn.input('Enter additional args (' .. command .. '): ', COMMAND_ARGS[argKey])
                                end)
                            end
                        })
                    end
                end
            end
        })
    end
}
