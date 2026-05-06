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
-- - Reference files with @
-- - Search -> quickfix or smth
-- - ask before running commands
-- - autocomplete commands?
-- - comment / review stuff
-- - apparently this supports multiple sessions.
-- - restore a previous convo
-- - actions
return {
    {
        "olimorris/codecompanion.nvim",
        version = "^19.0.0",
        opts = {
            -- Default adapter: "copilot", "claude_code", "opencode", "codex", "gemini_cli", etc.
            -- Switch at runtime: press `ga` in chat buffer
            interactions = {
                chat = {
                    adapter = "claude_code",
                    -- Keymaps reference:
                    --   <C-s>  (n/i) send message
                    --   ga     (n)   change adapter/model
                    --   q      (n)   close chat
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
        },
        keys = {
            { "<C-\\>", "<cmd>CodeCompanionChat Toggle<cr>", mode = { "n", "v" }, desc = "Toggle CodeCompanion Chat" },
            -- { "<C-\\>", ":CodeCompanion<CR>", mode = "n", desc = "Run CodeCompanion" },
            -- { "<C-\\>", ":CodeCompanion<CR>", mode = "v", desc = "Run CodeCompanion on selection" },
            -- { "<C-_>", ":CodeCompanionChat<CR>", mode = "n", desc = "Toggle CodeCompanion Chat" },
        },
        init = function()
            vim.api.nvim_create_autocmd("ColorScheme", {
                pattern = "*",
                callback = function()
                    vim.api.nvim_set_hl(0, "CodeCompanionChatHeader", { fg = "#7aa2f7", bold = true })
                    vim.api.nvim_set_hl(0, "CodeCompanionChatSeparator", { fg = "#3b4261" })
                    vim.api.nvim_set_hl(0, "CodeCompanionChatTokens", { fg = "#565f89", italic = true })
                end,
            })
            vim.cmd("doautocmd ColorScheme")
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
