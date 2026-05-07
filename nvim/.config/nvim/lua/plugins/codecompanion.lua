-- ACP adapter binaries (install per machine):
--   claude_code  -> npm i -g @agentclientprotocol/claude-agent-acp
--   opencode     -> bundled with `opencode` CLI (`opencode acp`)
--   copilot_acp  -> bundled with GitHub Copilot CLI (`copilot --acp --stdio`)
--   codex        -> bundled with `codex` CLI
--   gemini_cli   -> bundled with `gemini` CLI
--
-- Treesitter requirement:
--   yaml parser must be installed (`:TSInstall yaml`) — frontmatter parsing
--   for /-slash prompt library needs it. Without it: spurious
--   "[Prompt Library] Missing frontmatter, name or interaction in ..." warnings.
--
-- TODO:
-- - I don't like how it looks
-- - autocomplete commands?
-- - comment / review stuff
-- - actions

-- Route a prompt (+ optional visual selection) to a fresh chat and submit.
-- Used to avoid the inline strategy, which doesn't work with ACP adapters.
local function send_to_chat(opts)
    opts = opts or {}
    local with_selection = opts.with_selection
    local default_prompt = opts.default_prompt or ""

    return function()
        local bufnr = vim.api.nvim_get_current_buf()
        local ft = vim.bo[bufnr].filetype
        local filename = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ":.")

        local code, s_line, e_line
        if with_selection then
            s_line = vim.fn.line("'<")
            e_line = vim.fn.line("'>")
            local lines = vim.api.nvim_buf_get_lines(bufnr, s_line - 1, e_line, false)
            code = table.concat(lines, "\n")
        end

        vim.ui.input({ prompt = "Prompt: ", default = default_prompt }, function(input)
            if not input or input == "" then
                return
            end
            local Chat = require("codecompanion.interactions.chat")
            local content = input
            if code then
                content = string.format(
                    "%s\n\n```%s\n-- %s:%d-%d\n%s\n```",
                    input, ft, filename, s_line, e_line, code
                )
            end
            local chat = Chat.new({ adapter = "claude_code" })
            chat:add_message({ role = "user", content = content })
            chat:submit()
        end)
    end
end

return {
    {
        "olimorris/codecompanion.nvim",
        version = "^19.0.0",
        opts = {
            -- Default adapter: "copilot", "claude_code", "opencode", "codex", "gemini_cli", etc.
            -- Switch at runtime: press `ga` in chat buffer
            interactions = {
                inline = {
                    -- Inline strategy avoided — ACP adapters (claude_code, opencode, etc.)
                    -- don't support it. <leader>ni / <leader>nt route to chat instead.
                    adapter = "claude_code",
                },
                chat = {
                    adapter = "claude_code",
                    -- Keymaps reference:
                    --   <C-s>      (n/i) send message
                    --   ga         (n)   change adapter/model
                    --   <C-c>      (n/i) close chat
                    --   q          (n)   stop current request
                    --   <leader>r  (n)   rename chat
                    --   gz         (n)   fold all codeblocks (gf reserved for open-file)
                    -- Completion (type trigger in INSERT mode):
                    --   /          slash commands — /file → Telescope to pick any file from disk
                    --   #          editor context (open buffers)
                    --   @          tools (AI agents)
                    keymaps = {
                        fold_code = { modes = { n = "gz" }, description = "Fold all codeblocks" },
                    },
                },
            },
            display = {
                chat = {
                    window = {
                        layout = "vertical",
                        position = "right",
                    },
                    -- Compact display: fold context blocks, no header separator
                    fold_context = true,
                    show_header_separator = false,
                },
            },
        },
        dependencies = {
            "nvim-lua/plenary.nvim",
            "nvim-treesitter/nvim-treesitter",
            "nvim-telescope/telescope.nvim",
        },
        keys = {
            { "<C-\\>", "<cmd>CodeCompanionChat Toggle<cr>", mode = { "n", "v" }, desc = "Toggle CodeCompanion Chat" },
            { "<leader>nc", "<cmd>CodeCompanionChat<cr>", mode = { "n", "v" }, desc = "New CodeCompanion Chat" },
            -- Prompt → chat (replaces inline strategy, which ACP can't drive)
            { "<leader>ni", send_to_chat(), mode = "n", desc = "Prompt → chat" },
            { "<leader>ni", send_to_chat({ with_selection = true }), mode = "v", desc = "Selection + prompt → chat" },
            -- Slash prompts (built-in library): /fix, /explain → chat
            { "<leader>nf", ":CodeCompanion /fix<CR>",     mode = "v", desc = "Fix selection (chat)" },
            { "<leader>ne", ":CodeCompanion /explain<CR>", mode = "v", desc = "Explain selection (chat)" },
            {
                "<leader>nt",
                send_to_chat({ with_selection = true, default_prompt = "Generate unit tests for this selection" }),
                mode = "v",
                desc = "Tests for selection → chat",
            },
            {
                "<leader>ns",
                function()
                    vim.ui.input({ prompt = "LLM Search: " }, function(query)
                        if not query or query == "" then
                            return
                        end
                        vim.api.nvim_echo({ { "  Searching: " .. query .. "…", "DiagnosticInfo" } }, false, {})
                        local Chat = require("codecompanion.interactions.chat")
                        local prompt = string.format(
                            "Search the codebase for: %s\n\n"
                                .. "Use your tools to find relevant code. Mark each result with:\n"
                                .. "RESULT: filepath:line_number:description\n\n"
                                .. "You may include explanatory text too.",
                            query
                        )
                        local chat = Chat.new({
                            hidden = true,
                            adapter = "claude_code",
                            callbacks = {
                                on_ready = function(c)
                                    local items = {}
                                    for _, msg in ipairs(c.messages) do
                                        if msg.role == "llm" then
                                            for line in (msg.content or ""):gmatch("[^\n]+") do
                                                local file, lnum, text = line:match("^RESULT: ([^:]+):(%d+):(.+)$")
                                                if file and lnum then
                                                    table.insert(items, {
                                                        filename = vim.trim(file),
                                                        lnum = tonumber(lnum),
                                                        col = 1,
                                                        text = vim.trim(text or ""),
                                                    })
                                                end
                                            end
                                        end
                                    end
                                    vim.api.nvim_echo({ { "" } }, false, {})
                                    if #items > 0 then
                                        vim.fn.setqflist({}, "r", { title = "Search: " .. query, items = items })
                                        vim.cmd("copen")
                                    else
                                        vim.notify("No results for: " .. query, vim.log.levels.WARN)
                                    end
                                end,
                            },
                        })
                        chat:add_message({ role = "user", content = prompt })
                        chat:submit()
                    end)
                end,
                mode = "n",
                desc = "LLM search → quickfix",
            },
            {
                "<leader>\\",
                function()
                    local pickers = require("telescope.pickers")
                    local finders = require("telescope.finders")
                    local conf = require("telescope.config").values
                    local actions = require("telescope.actions")
                    local action_state = require("telescope.actions.state")
                    local Chat = require("codecompanion.interactions.chat")
                    local entries = Chat.buf_get_chat()
                    if vim.tbl_isempty(entries) then
                        return vim.notify("No open CodeCompanion chats", vim.log.levels.INFO)
                    end
                    pickers
                        .new({}, {
                            prompt_title = "CodeCompanion Chats",
                            finder = finders.new_table({
                                results = entries,
                                entry_maker = function(e)
                                    local display = e.title or e.name or ("Chat " .. e.chat.bufnr)
                                    return { value = e, display = display, ordinal = display }
                                end,
                            }),
                            sorter = conf.generic_sorter({}),
                            attach_mappings = function(prompt_bufnr)
                                actions.select_default:replace(function()
                                    actions.close(prompt_bufnr)
                                    local sel = action_state.get_selected_entry()
                                    sel.value.chat.ui:open()
                                end)
                                return true
                            end,
                        })
                        :find()
                end,
                mode = "n",
                desc = "Pick CodeCompanion Chat",
            },
        },
        init = function()
            vim.api.nvim_create_autocmd("FileType", {
                pattern = "codecompanion",
                callback = function(ev)
                    vim.keymap.set("n", "gf", function()
                        local path = vim.fn.expand("<cfile>:p")
                        if path == "" or vim.fn.filereadable(path) == 0 then
                            vim.notify("File not found: " .. vim.fn.expand("<cfile>"), vim.log.levels.WARN)
                            return
                        end
                        vim.cmd("vsplit " .. vim.fn.fnameescape(path))
                    end, { buffer = ev.buf, desc = "Open file under cursor in vsplit" })
                    vim.keymap.set("n", "<leader>r", function()
                        local Chat = require("codecompanion.interactions.chat")
                        local chat = Chat.buf_get_chat(ev.buf)
                        if not chat then
                            return
                        end
                        vim.ui.input({ prompt = "Chat name: ", default = chat.title or "" }, function(name)
                            if name and name ~= "" then
                                chat:set_title(name)
                            end
                        end)
                    end, { buffer = ev.buf, desc = "Rename chat" })
                end,
            })
            vim.api.nvim_create_autocmd("ColorScheme", {
                pattern = "*",
                callback = function()
                    vim.api.nvim_set_hl(0, "CodeCompanionChatHeader", { fg = "#7aa2f7", bold = true })
                    vim.api.nvim_set_hl(0, "CodeCompanionChatSeparator", { fg = "#3b4261" })
                    vim.api.nvim_set_hl(0, "CodeCompanionChatTokens", { fg = "#565f89", italic = true })
                end,
            })
            vim.cmd("doautocmd ColorScheme")
            vim.api.nvim_create_autocmd("User", {
                pattern = "CodeCompanionToolApprovalRequested",
                callback = function()
                    vim.fn.jobstart({ "afplay", "/System/Library/Sounds/Glass.aiff" })
                end,
            })
        end,
    },
    {
        "MeanderingProgrammer/render-markdown.nvim",
        ft = { "markdown", "codecompanion" },
        dependencies = { "nvim-treesitter/nvim-treesitter" },
        opts = {
            file_types = { "markdown", "codecompanion" },
            heading = { sign = false, icons = {} },
            code = { sign = false, width = "block", right_pad = 1 },
        },
    },
}
