return {
    {
        "greggh/claude-code.nvim",
        dependencies = {
            "nvim-lua/plenary.nvim", -- Required for git operations
        },
        config = function()
            require("claude-code").setup({
                -- Terminal window settings
                window = {
                    split_ratio = 0.3,      -- Percentage of screen for the terminal window (height for horizontal, width for vertical splits)
                    position = "botright",  -- Position of the window: "botright", "topleft", "vertical", "float", etc.
                    enter_insert = true,    -- Whether to enter insert mode when opening Claude Code
                    hide_numbers = true,    -- Hide line numbers in the terminal window
                    hide_signcolumn = true, -- Hide the sign column in the terminal window

                    -- Floating window configuration (only applies when position = "float")
                    float = {
                        width = "80%",       -- Width: number of columns or percentage string
                        height = "80%",      -- Height: number of rows or percentage string
                        row = "center",      -- Row position: number, "center", or percentage string
                        col = "center",      -- Column position: number, "center", or percentage string
                        relative = "editor", -- Relative to: "editor" or "cursor"
                        border = "rounded",  -- Border style: "none", "single", "double", "rounded", "solid", "shadow"
                    },
                },
                -- File refresh settings
                refresh = {
                    enable = true,             -- Enable file change detection
                    updatetime = 100,          -- updatetime when Claude Code is active (milliseconds)
                    timer_interval = 1000,     -- How often to check for file changes (milliseconds)
                    show_notifications = false, -- Use custom notifications instead
                },
                -- Git project settings
                git = {
                    use_git_root = true, -- Set CWD to git root when opening Claude Code (if in git project)
                },
                -- Shell-specific settings
                shell = {
                    separator = '&&',    -- Command separator used in shell commands
                    pushd_cmd = 'pushd', -- Command to push directory onto stack (e.g., 'pushd' for bash/zsh, 'enter' for nushell)
                    popd_cmd = 'popd',   -- Command to pop directory from stack (e.g., 'popd' for bash/zsh, 'exit' for nushell)
                },
                -- Command settings
                command = "claude", -- Command used to launch Claude Code
                -- Command variants
                command_variants = {
                    -- Conversation management
                    continue = "--continue", -- Resume the most recent conversation
                    resume = "--resume",     -- Display an interactive conversation picker

                    -- Output options
                    verbose = "--verbose", -- Enable verbose logging with full turn-by-turn output
                },
                -- Keymaps
                keymaps = {
                    toggle = {
                        normal = "<C-,>",            -- Normal mode keymap for toggling Claude Code, false to disable
                        terminal = "<C-,>",          -- Terminal mode keymap for toggling Claude Code, false to disable
                        variants = {
                            continue = "<leader>cC", -- Normal mode keymap for Claude Code with continue flag
                            verbose = "<leader>cV",  -- Normal mode keymap for Claude Code with verbose flag
                        },
                    },
                    window_navigation = true, -- Enable window navigation keymaps (<C-h/j/k/l>)
                    scrolling = true,         -- Enable scrolling keymaps (<C-f/b>) for page up/down
                }
            })

            vim.keymap.set('n', '<leader>cc', '<cmd>ClaudeCode<CR>', { desc = 'Toggle Claude Code' })
        end
    },
    {
        'NickvanDyke/opencode.nvim',
        dependencies = {
            -- Recommended for better prompt input, and required to use opencode.nvim's embedded terminal — otherwise optional
            { 'folke/snacks.nvim', opts = { input = { enabled = true } } },
        },
        ---@type opencode.Opts
        opts = {
            -- Your configuration, if any — see lua/opencode/config.lua
        },
        keys = {
            -- Recommended keymaps
            { '<leader>oA', function() require('opencode').ask() end,                                     desc = 'Ask opencode', },
            { '<leader>oa', function() require('opencode').ask('@cursor: ') end,                          desc = 'Ask opencode about this',      mode = 'n', },
            { '<leader>oa', function() require('opencode').ask('@selection: ') end,                       desc = 'Ask opencode about selection', mode = 'v', },
            { '<leader>ot', function() require('opencode').toggle() end,                                  desc = 'Toggle embedded opencode', },
            { '<leader>on', function() require('opencode').command('session_new') end,                    desc = 'New session', },
            { '<leader>oy', function() require('opencode').command('messages_copy') end,                  desc = 'Copy last message', },
            { '<S-C-u>',    function() require('opencode').command('messages_half_page_up') end,          desc = 'Scroll messages up', },
            { '<S-C-d>',    function() require('opencode').command('messages_half_page_down') end,        desc = 'Scroll messages down', },
            { '<leader>op', function() require('opencode').select_prompt() end,                           desc = 'Select prompt',                mode = { 'n', 'v', }, },
            -- Example: keymap for custom prompt
            { '<leader>oe', function() require('opencode').prompt("Explain @cursor and its context") end, desc = "Explain code near cursor", },
        },
    }
}
