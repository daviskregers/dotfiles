-- CodeCompanion: read-only AI chat inside neovim.
-- Two agent groups: @{tutor} (Socratic, no answers) and @{assistant} (direct).
-- Both are read-only — no file-write tools. Writes happen via Sandcastle (Slice 3).
-- Adapter: ACP (opencode or claude_code), picked from .dk-notes/.agent or ~/.config/nvim/.agent.

vim.pack.add({
    { src = "https://github.com/olimorris/codecompanion.nvim", version = vim.version.range("^19.0.0") },
    "https://github.com/ravitemer/codecompanion-history.nvim",
})

-- Resolve which ACP adapter to use: project .dk-notes/.agent → global ~/.config/nvim/.agent → "opencode"
local function resolve_adapter()
    local function read_agent_file(path)
        local f = io.open(path, "r")
        if not f then return nil end
        local line = f:read("*l")
        f:close()
        return line and vim.trim(line) or nil
    end
    local project = vim.fs.find(".dk-notes", { upward = true, type = "directory" })[1]
    if project then
        local agent = read_agent_file(project .. "/.agent")
        if agent and agent ~= "" then return agent end
    end
    local global = read_agent_file(vim.fn.stdpath("config") .. "/.agent")
    if global and global ~= "" then return global end
    return "opencode"
end

local tutor_prompt =
[[Socratic buddy. The user owns the understanding; you only ask the questions that lead them to it — never hand the conclusion.

## Rules

- Lead with questions, not answers. Point at where to look, ask what they see, withhold your read until they've formed theirs. Bare "I don't know" → give a smaller sub-question, not the answer.
- Primary sources first, unbiased. Go to the artifact itself (code, doc) before anyone's summary. Skip others' answers until the user has their own.
- Ground every claim in evidence, not memory. Assert nothing you haven't shown from the source. Called out → go fetch it and prove it; don't defend from memory.
- Correct gently and precisely. Wrong answer → sharpen with the exact fact; don't seize back the reasoning.
- One step, then STOP. Ask, then WAIT. Don't chain questions or run ahead. Don't continue until they answer satisfactorily.
- Wrong turns are the lesson. Let a hunch run far enough to break, then ask what broke it.]]

local assistant_prompt = [[You are a coding assistant. Answer directly and concisely.
Use read_file and grep_search to explore the codebase when needed.
You cannot write or modify files — you are read-only.]]

require("dk.chat-container")
local container = require("dk.chat-container")

require("codecompanion").setup({
    interactions = {
        chat = {
            adapter = resolve_adapter(),
            title_generation_opts = {
                adapter = { name = "copilot" },
            },
            tools = {
                -- Assistant is loaded by default in every new chat.
                -- For tutor, <leader>at feeds @{tutor} into the chat buffer.
                opts = {
                    default_tools = { "assistant" },
                },
                groups = {
                    ["assistant"] = {
                        description = "Read-only assistant — direct answers, codebase-anchored",
                        system_prompt = assistant_prompt,
                        tools = { "read_file", "grep_search" },
                        opts = {
                            collapse_tools = true,
                            ignore_system_prompt = true,
                            ignore_tool_system_prompt = true,
                        },
                    },
                    ["tutor"] = {
                        description = "Socratic tutor — leads you to understanding via questions, never hands the answer",
                        system_prompt = tutor_prompt,
                        tools = { "read_file", "grep_search" },
                        opts = {
                            collapse_tools = true,
                            ignore_system_prompt = true,
                            ignore_tool_system_prompt = true,
                        },
                    },
                },
            },
        },
        slash_commands = {
            ["plan"] = {
                description = "Produce a plan (vertical slices, no code)",
                callback = function(chat)
                    vim.ui.input({ prompt = "Plan for: " }, function(desc)
                        if not desc or desc == "" then return end
                        chat:add_message({
                            role = "user",
                            content = "Produce a plan for: " .. desc
                                .. ". No code. If ambiguous, give 2 options with tradeoffs. "
                                .. "The plan must specify vertical slices (thin end-to-end), not horizontal layers.",
                        })
                    end)
                end,
                opts = { contains_code = false },
            },
            ["triage"] = {
                description = "Familiarity triage → recommended mode",
                callback = function()
                    require("dk.triage").run()
                end,
                opts = { contains_code = false },
            },
        },
    },

    -- Override ACP adapters: fix form_messages to include system-role messages.
    -- The default ACP helpers.form_messages filters to user-role only, silently
    -- dropping system prompts (tutor Socratic prompt, assistant read-only prompt).
    -- This override prepends system messages as text parts before user messages,
    -- so the ACP agent (opencode/claude_code) actually receives the system prompt.
    -- Also disables writeTextFile so the agent can't edit files.
    adapters = {
        acp = {
            opencode = function()
                return require("codecompanion.adapters").extend("opencode", {
                    commands = {
                        default = container.acp_command(),
                    },
                    parameters = {
                        clientCapabilities = {
                            fs = { readTextFile = true, writeTextFile = false },
                        },
                    },
                    handlers = {
                        form_messages = function(self, messages, capabilities)
                            local parts = {}
                            for _, msg in ipairs(messages) do
                                if msg._meta and msg._meta.sent then
                                    -- skip already-sent
                                elseif msg.role == "system" and msg.content and msg.content ~= "" then
                                    table.insert(parts, { type = "text", text = msg.content })
                                elseif msg.role == self.roles.user and msg.content and msg.content ~= "" then
                                    table.insert(parts, { type = "text", text = msg.content })
                                end
                            end
                            return parts
                        end,
                    },
                })
            end,
            claude_code = function()
                return require("codecompanion.adapters").extend("claude_code", {
                    commands = {
                        default = container.acp_command(),
                    },
                    parameters = {
                        clientCapabilities = {
                            fs = { readTextFile = true, writeTextFile = false },
                        },
                    },
                    handlers = {
                        form_messages = function(self, messages, capabilities)
                            local parts = {}
                            for _, msg in ipairs(messages) do
                                if msg._meta and msg._meta.sent then
                                    -- skip already-sent
                                elseif msg.role == "system" and msg.content and msg.content ~= "" then
                                    table.insert(parts, { type = "text", text = msg.content })
                                elseif msg.role == self.roles.user and msg.content and msg.content ~= "" then
                                    table.insert(parts, { type = "text", text = msg.content })
                                end
                            end
                            return parts
                        end,
                    },
                })
            end,
        },
    },

    mcp = {
        servers = {
            ["btca-local"] = { cmd = { "bunx", "btca", "mcp" } },
            ["context7"]   = { cmd = { "npx", "-y", "@upstash/context7-mcp" } },
        },
    },

    extensions = {
        history = {
            enabled = true,
            opts = {
                dir_to_save = vim.fn.stdpath("data") .. "/codecompanion-chats",
            },
        },
    },

    opts = {
        log_level = "DEBUG",
    },
})

-- Read visual selection. Returns formatted text with location header.
-- Exits visual mode; must be called from a visual-mode keymap.
local function read_selection_with_location()
    local sl = vim.fn.line("v")
    local el = vim.fn.line(".")
    if sl > el then sl, el = el, sl end
    vim.cmd("normal! \27")
    local lines = vim.api.nvim_buf_get_lines(0, sl - 1, el, false)
    local content = table.concat(lines, "\n")
    local fname = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":.")
    local ft = vim.bo[0].filetype
    return string.format("%s:%d-%d\n\n```%s\n%s\n```", fname, sl, el, ft, content)
end

-- <C-/>: toggle the chat buffer (open/hide). Opens with assistant pre-loaded (default_tools).
-- Bind both <C-/> and <C-_> — legacy terminals send <C-_> when <C-/> is pressed.
vim.keymap.set({ "n", "i", "x" }, "<C-/>", function()
    container.ensure_running()
    vim.cmd("CodeCompanionChat Toggle")
end, { desc = "Chat: toggle" })
vim.keymap.set({ "n", "i", "x" }, "<C-_>", function()
    container.ensure_running()
    vim.cmd("CodeCompanionChat Toggle")
end, { desc = "Chat: toggle" })

-- <leader>as: open a fresh chat with assistant pre-loaded.
-- <leader>at: open a fresh chat, then feed @{tutor} to swap to Socratic mode.
-- In the chat buffer: type your message, then <C-s> (insert) or <CR> (normal) to send.

-- Open a fresh chat, enter insert, then feed the given keys into the buffer.
local function open_chat(keys)
    container.ensure_running()
    vim.cmd("CodeCompanionChat")
    vim.defer_fn(function()
        vim.cmd("startinsert")
        vim.defer_fn(function()
            vim.api.nvim_feedkeys(keys, "n", false)
        end, 10)
    end, 50)
end

vim.keymap.set("n", "<leader>as", "<cmd>CodeCompanionChat<CR>", { desc = "Chat: assistant (read-only)" })

vim.keymap.set("v", "<leader>as", function()
    open_chat(read_selection_with_location() .. "\n\n")
end, { desc = "Chat: assistant + selection" })

vim.keymap.set("n", "<leader>at", function()
    open_chat("@{tutor} ")
end, { desc = "Chat: tutor (Socratic, read-only)" })

vim.keymap.set("v", "<leader>at", function()
    open_chat("@{tutor} " .. read_selection_with_location() .. "\n\n")
end, { desc = "Chat: tutor + selection" })

