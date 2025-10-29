-- Import tmux utilities
local tmux = require("tmux")

-- Toggle 4: Git terminal (lazygit)
vim.api.nvim_create_user_command("ToggleGitTerminal", function()
    tmux.create_toggle(4, "lazygit")
end, {})

-- Toggle 2: Scratch terminal
vim.api.nvim_create_user_command("ToggleScratchTerminal", function()
    tmux.create_toggle(2)
end, {})

-- Toggle 1: Test terminal (for test/lint/build commands)
vim.api.nvim_create_user_command("RunScratchCommand", function(args)
    local command = args['fargs'][1]

    if tmux.is_tmux() then
        tmux.send_to_toggle(1, command)
    else
        print("Not running in tmux - RunScratchCommand requires tmux")
    end
end, {
    nargs = 1,
})


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
    },
    ['*'] = {
        test = "echo command test not set",
        lint = "echo command lint not set",
        watch = "echo command watch not set",
        run = "echo command run not set",
        build = "echo command build not set",
        clean = "echo command clean not set",
    }
}

local COMMAND_ARGS = {}

vim.api.nvim_create_autocmd('User', {
    pattern = 'ConfigLocalFinished',
    callback = function()
        if CONFIG_TEST_COMMANDS ~= nil then
            -- print('Overriding test commands')
            -- print(vim.inspect(CONFIG_TEST_COMMANDS))
            for filetype, commands in pairs(CONFIG_TEST_COMMANDS) do
                -- print(string.format('Overriding test commands for %s', filetype))
                -- print(vim.inspect(commands))
                for command, value in pairs(commands) do
                    -- print(string.format('[%s] Overriding %s with %s', filetype, command, value))
                    if defaultTestCommands[filetype] == nil then
                        defaultTestCommands[filetype] = {}
                    end
                    defaultTestCommands[filetype][command] = value
                end
            end
        end

        local types = {
            { "b", "build" },
            { "c", "clean" },
            { "e", "test" },
            { "f", "format" },
            { "l", "lint" },
            { "r", "run" },
            { "w", "watch" },
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
                            local cmd = commands[command]
                            print(string.format('Running %s', cmd))
                            if cmd == nil then
                                local fallback = CONFIG_TEST_COMMANDS['*'][command]
                                if fallback == nil then
                                    print(string.format('No command found for %s', command))
                                    return
                                end
                                cmd = fallback
                            end
                            vim.cmd(string.format('RunScratchCommand %s %s', cmd, COMMAND_ARGS[argKey]))
                        end)

                        vim.keymap.set("n", "<leader>t" .. string.upper(key), function()
                            COMMAND_ARGS[argKey] = vim.fn.input('Enter additional args (' .. command .. '): ',
                                COMMAND_ARGS[argKey])
                        end)
                    end
                })
            end
        end
    end
})

