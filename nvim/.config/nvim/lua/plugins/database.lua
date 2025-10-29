-- vim-dadbod: Database interface for Vim
-- Supports MySQL, PostgreSQL, SQLite, MongoDB, and more
-- Provides database interaction with UI, autocomplete, and query execution
--
-- Usage:
--   <leader>db - Toggle Dadbod UI
--   In UI:
--     - Add connections with environment variables
--     - Browse database schema
--     - Execute queries with results display
--
-- Connection examples (stored in ~/.local/share/nvim/dadbod_ui):
--   MySQL:    mysql://user:password@localhost:3306/database
--   With env: mysql://{{DB_USER}}:{{DB_PASSWORD}}@localhost/mydb
--   Postgres: postgres://user:password@localhost:5432/database
--   SQLite:   /absolute/path/to/database.db

return {
    -- vim-dadbod: Core database interface
    {
        "tpope/vim-dadbod",
    },

    -- vim-dadbod-ui: UI wrapper for vim-dadbod
    {
        "kristijanhusak/vim-dadbod-ui",
        dependencies = {
            { "tpope/vim-dadbod", lazy = true },
            { "kristijanhusak/vim-dadbod-completion", ft = { "sql", "mysql", "plsql" }, lazy = true },
        },
        cmd = {
            "DBUI",
            "DBUIToggle",
            "DBUIAddConnection",
            "DBUIFindBuffer",
        },
        init = function()
            -- Dadbod-ui configuration
            vim.g.db_ui_use_nerd_fonts = 1
            vim.g.db_ui_show_database_icon = 1
            vim.g.db_ui_force_echo_notifications = 1
            vim.g.db_ui_win_position = "right"
            vim.g.db_ui_winwidth = 40

            -- Save connection info in a separate file (not in dotfiles)
            vim.g.db_ui_save_location = vim.fn.stdpath("data") .. "/dadbod_ui"

            -- Keybinding to toggle dadbod UI
            vim.keymap.set("n", "<leader>db", "<cmd>DBUIToggle<cr>", { desc = "Toggle Dadbod UI" })
        end,
    },
}
