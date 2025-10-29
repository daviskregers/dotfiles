-- nvim-dbee: Interactive database client for Neovim
-- Supports MySQL, PostgreSQL, SQLite, and more
-- Connections are saved to ~/.local/share/nvim/dbee/persistence.json (outside dotfiles)
--
-- Usage:
--   <leader>db - Toggle database UI drawer
--   In UI:
--     - Use 'add' item to create new connections
--     - Select database to connect
--     - Execute queries in editor
--
-- Connection examples:
--   MySQL:    mysql://user:password@localhost:3306/database
--   With env: mysql://{{env "DB_USER"}}:{{env "DB_PASSWORD"}}@localhost/mydb
--   Postgres: postgres://user:password@localhost:5432/database
--   SQLite:   /absolute/path/to/database.db

return {
    "kndndrj/nvim-dbee",
    dependencies = {
        "MunifTanjim/nui.nvim",
    },
    build = function()
        -- Install the database client backend
        require("dbee").install()
    end,
    config = function()
        require("dbee").setup({
        })

        -- Keybinding to toggle database UI
        vim.keymap.set("n", "<leader>db", function()
            require("dbee").toggle()
        end, { desc = "Toggle Database UI" })
    end,
}
