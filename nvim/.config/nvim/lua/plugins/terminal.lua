local state = {
    scratch = {
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

local function create_window(opts)
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

    win_config["split"] = 'right'
    win_config["win"] = vim.api.nvim_get_current_win()

    local win = vim.api.nvim_open_win(buf, true, win_config)

    return { buf = buf, win = win }
end

local function toggle_scratch_terminal()
    if not vim.api.nvim_win_is_valid(state.scratch.win) then
        state.scratch = create_window { buf = state.scratch.buf, width = 80 }
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
                        end, {
                            desc = string.format('Terminal - %s', command)
                        })

                        vim.keymap.set("n", "<leader>t" .. string.upper(key), function()
                            COMMAND_ARGS[argKey] = vim.fn.input('Enter additional args (' .. command .. '): ',
                                COMMAND_ARGS[argKey])
                        end, {
                            desc = string.format('Terminal Config - %s', command)
                        })
                    end
                })
            end
        end
    end
})

vim.keymap.set("t", "<C-q>", "<c-\\><c-n>")
vim.keymap.set({ "n", "i", "x" }, "<C-t>", function()
    toggle_scratch_terminal()
end, { desc = "Scratch terminal" })

-- ============================================================================
-- Hunk review: poll `git diff HEAD` on a timer and stream each changed hunk
-- into the quickfix list in stable first-seen order, so an agent's edits can be
-- reviewed as they land instead of waiting for it to finish. Pure logic (parse,
-- key, order) lives in the `hunk_review` module; this is just the IO shell.
-- ============================================================================
local hunk_review = require("hunk_review")

local review = {
    timer = nil,
    registry = nil,
    running = false, -- guards against overlapping async ticks
    signature = nil, -- last published key list; skip setqflist when unchanged
}

local function git_root()
    local out = vim.fn.systemlist({ "git", "rev-parse", "--show-toplevel" })
    if vim.v.shell_error ~= 0 or not out[1] or out[1] == "" then
        return nil
    end
    return out[1]
end

local function publish(root)
    if review.running then
        return
    end
    review.running = true

    -- `git diff HEAD` (working tree vs HEAD) is the primary hunk set: its output
    -- is invariant under staging, so hunks never move when staged. `git diff
    -- --cached` (index vs HEAD) is used only to label each hunk staged/unstaged.
    vim.system({ "git", "-C", root, "diff", "HEAD" }, { text = true }, function(head_res)
        vim.system({ "git", "-C", root, "diff", "--cached" }, { text = true }, function(staged_res)
            vim.system(
                { "git", "-C", root, "ls-files", "--others", "--exclude-standard" },
                { text = true },
                function(others_res)
                    vim.schedule(function()
                        review.running = false

                        if head_res.code ~= 0 then
                            vim.notify(
                                "hunk-review: git diff failed\n" .. (head_res.stderr or ""),
                                vim.log.levels.ERROR
                            )
                            return
                        end

                        local head = head_res.stdout or ""
                        local staged = staged_res.stdout or ""
                        local others_raw = others_res.stdout or ""

                        -- Cheap early-out: if the raw git output is byte-identical
                        -- to last tick, nothing changed — skip parse/order/setqflist
                        -- and leave the user's quickfix cursor untouched. Hashing
                        -- here is ~100x cheaper than the git calls that already ran.
                        local sig = vim.fn.sha256(head .. "\0" .. staged .. "\0" .. others_raw)
                        if sig == review.signature then
                            return
                        end
                        review.signature = sig

                        local others = vim.split(others_raw, "\n", { trimempty = true })
                        local hunks = hunk_review.collect(head, staged, others)
                        local ordered = review.registry:update(hunks)

                        -- Preserve the native quickfix cursor across the rebuild;
                        -- stable ordering means the same index still points at
                        -- the same hunk.
                        local saved = vim.fn.getqflist({ idx = 0 }).idx
                        local items = hunk_review.to_qf_items(ordered)
                        vim.fn.setqflist({}, "r", { title = "hunk-review", items = items })
                        if saved and saved > 0 and saved <= #items then
                            vim.fn.setqflist({}, "r", { idx = saved })
                        end
                    end)
                end
            )
        end)
    end)
end

local function start_hunk_review()
    if review.timer then
        return
    end

    local root = git_root()
    if not root then
        vim.notify("hunk-review: not inside a git repo", vim.log.levels.WARN)
        return
    end

    review.registry = hunk_review.new_registry()
    review.signature = nil
    review.timer = vim.uv.new_timer()
    review.timer:start(0, 1000, vim.schedule_wrap(function()
        publish(root)
    end))

    vim.cmd("copen")
    vim.notify("hunk-review: watching " .. root)
end

local function stop_hunk_review()
    if not review.timer then
        return
    end
    review.timer:stop()
    review.timer:close()
    review.timer = nil
    review.running = false
    vim.notify("hunk-review: stopped")
end

local function toggle_hunk_review()
    if review.timer then
        stop_hunk_review()
    else
        start_hunk_review()
    end
end

vim.api.nvim_create_user_command("HunkReviewStart", start_hunk_review, {})
vim.api.nvim_create_user_command("HunkReviewStop", stop_hunk_review, {})
vim.api.nvim_create_user_command("HunkReviewToggle", toggle_hunk_review, {})
vim.keymap.set("n", "<leader>hw", toggle_hunk_review, { desc = "Hunk watch — toggle live diff qflist" })

-- ============================================================================
-- Agent comment: select code, jot a note, paste it into the running agent as a
-- review comment. The note is a snapshot (file:range + fenced code + text), not
-- a live anchor — so nothing breaks when the agent edits the code it describes.
-- Pure formatting lives in `agent_comment`; this is the marks/buffer/IO shell.
-- ============================================================================
local agent_comment = require("agent_comment")

-- Buffers awaiting submission: comment-buffer handle -> captured selection.
local pending_comments = {}

-- The scratch terminal's job channel, or nil if there's no live terminal to
-- send to. Present-vs-absent only — it can't tell a claude TUI from a bare
-- shell, which is the accepted limit of the guard.
local function scratch_terminal_channel()
    local buf = state.scratch.buf
    if buf and vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buftype == "terminal" then
        local ch = vim.bo[buf].channel
        if ch and ch > 0 then
            return ch
        end
    end
    return nil
end

-- Push the payload into the agent as one bracketed-paste block, then submit it
-- with a lone CR. The CR is deferred so the TUI finishes ingesting the paste
-- before the Enter lands (verified against claude's TUI).
local function send_to_agent(ch, payload)
    vim.fn.chansend(ch, agent_comment.paste_sequence(payload))
    vim.defer_fn(function()
        vim.fn.chansend(ch, "\r")
    end, 150)
end

local function submit_comment(buf)
    local ctx = pending_comments[buf]
    if not ctx then
        return
    end

    local ch = scratch_terminal_channel()
    if not ch then
        -- Fail loud and keep the buffer: the note isn't lost, retry :w once the
        -- terminal is up.
        vim.notify("agent-comment: no scratch terminal — open the agent with <C-t> first", vim.log.levels.WARN)
        return
    end

    local comment = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
    local payload = agent_comment.format_payload(ctx.path, ctx.start_line, ctx.end_line, ctx.lines, comment)
    send_to_agent(ch, payload)

    pending_comments[buf] = nil
    vim.api.nvim_buf_delete(buf, { force = true })
end

local function comment_on_selection()
    -- A function map fires while still IN visual mode, so '<'/'> aren't committed
    -- yet (they read 0 on a first selection). Read the live endpoints instead:
    -- getpos("v") is the selection anchor, getpos(".") the cursor.
    local anchor = vim.fn.getpos("v")[2]
    local cursor = vim.fn.getpos(".")[2]
    local ctx = {
        path = vim.fn.expand("%:."),
        start_line = math.min(anchor, cursor),
        end_line = math.max(anchor, cursor),
    }
    ctx.lines = vim.api.nvim_buf_get_lines(0, ctx.start_line - 1, ctx.end_line, false)

    local buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].filetype = "markdown"
    -- acwrite (plus a name) routes :w through the BufWriteCmd below; a plain
    -- scratch buffer is buftype=nofile, which rejects :w with E382 before any
    -- autocmd runs.
    vim.bo[buf].buftype = "acwrite"
    vim.api.nvim_buf_set_name(buf, "agent-comment://" .. buf)
    pending_comments[buf] = ctx

    vim.cmd("botright split")
    local win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(win, buf)
    vim.api.nvim_win_set_height(win, 10)

    -- :w submits (no real file is written).
    vim.api.nvim_create_autocmd("BufWriteCmd", {
        buffer = buf,
        callback = function()
            submit_comment(buf)
        end,
    })

    vim.cmd("startinsert")
end

vim.keymap.set("x", "<leader>ar", comment_on_selection, { desc = "Agent review — comment on selection" })
