vim.pack.add({
    'https://github.com/epwalsh/obsidian.nvim',
})

require("obsidian").setup({
    workspaces = {
        {
            name = "Clank",
            path = "~/Documents/Clank",
        },
        {
            name = "Graphene",
            path = "~/Documents/Graphene",
        },
    },
    -- Optional, set to true to force ':ObsidianOpen' to bring the app to the foreground.
    open_app_foreground = true,
    -- Optional, sort search results by "path", "modified", "accessed", or "created".
    -- The recommend value is "modified" and `true` for `sort_reversed`, which means, for example,
    -- that `:ObsidianQuickSwitch` will show the notes sorted by latest modified time
    sort_by = "modified",
    sort_reversed = true,
})

vim.keymap.set("n", "<leader>po", ":ObsidianSearch<CR>", { desc = "Obsidian Search" })
vim.keymap.set("n", "<leader>op", ":ObsidianOpen<CR>", { desc = "Open in Obsidian" })
vim.keymap.set("n", "<leader>on", ":ObsidianNew<CR>", { desc = "New obsidian note" })
vim.keymap.set("n", "<leader>ot", ":ObsidianToday<CR>", { desc = "Obsidian Today" })
vim.keymap.set("n", "<leader>ow", ":ObsidianWorkspace<CR>", { desc = "Obsidian Workspace" })
