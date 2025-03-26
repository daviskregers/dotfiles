local state = {
    scratch = {
        buf = -1,
        win = -1,
        job = -1,
    },
    floating = {
        buf = -1,
        win = -1,
        job = -1,
    },
    git = {
        buf = -1,
        win = -1,
        job = -1
    },
    test = {
        buf = -1,
        win = -1,
        job = -1
    }
}

local function create_floating_window(opts)
    opts = opts or {}
    local cols = vim.o.columns
    local rows = vim.o.lines

    local width = opts.width or math.floor(cols * 0.8)
    local height = opts.height or math.floor(rows * 0.8)

    local buf = nil
    if vim.api.nvim_buf_is_valid(opts.buf) then
        buf = opts.buf
    else
        buf = vim.api.nvim_create_buf(false, true)
    end

    local win_config = {
        width = width,
        height = height,
        style = "minimal",
    }

    if opts.floating then
        local col = math.floor((cols - width) / 2)
        local row = math.floor((rows - height) / 2)

        win_config["relative"] = "editor"
        win_config["col"] = col
        win_config["row"] = row
        win_config["border"] = "rounded"
    else
        win_config["split"] = 'right'
        win_config["win"] = vim.api.nvim_get_current_win()
    end

    local win = vim.api.nvim_open_win(buf, true, win_config)

    return { buf = buf, win = win }
end

vim.api.nvim_create_user_command("ToggleFloatingTerminal", function()
    if not vim.api.nvim_win_is_valid(state.floating.win) then
        state.floating = create_floating_window { buf = state.floating.buf, floating = true }
        if vim.bo[state.floating.buf].buftype ~= "terminal" then
            vim.cmd.term()
        end
    else
        vim.api.nvim_win_hide(state.floating.win)
    end
end, {})

vim.api.nvim_create_user_command("ToggleGitTerminal", function()
    if not vim.api.nvim_win_is_valid(state.git.win) then
        state.git = create_floating_window { buf = state.git.buf, floating = true }
        if vim.bo[state.git.buf].buftype ~= "terminal" then
            vim.cmd.term("lazygit")
            vim.api.nvim_command('startinsert')
        end
    else
        vim.api.nvim_win_hide(state.git.win)
    end
end, {})

local function toggle_scratch_terminal()
    if not vim.api.nvim_win_is_valid(state.scratch.win) then
        state.scratch = create_floating_window { buf = state.scratch.buf, floating = false, width = 80 }
        if vim.bo[state.scratch.buf].buftype ~= "terminal" then
            vim.cmd.term()
        end
    else
        vim.api.nvim_win_hide(state.scratch.win)
    end
    state.scratch.job_id = vim.bo[state.scratch.buf].channel
end

vim.api.nvim_create_user_command("ToggleScratchTerminal", toggle_scratch_terminal, {})

vim.api.nvim_create_user_command("RunScratchCommand", function(args)
    local command = args['fargs'][1]

    if not vim.api.nvim_win_is_valid(state.scratch.win) or state.scratch.job_id == nil then
        toggle_scratch_terminal()
    end

    vim.fn.chansend(state.scratch.job_id, { command, "" })
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
