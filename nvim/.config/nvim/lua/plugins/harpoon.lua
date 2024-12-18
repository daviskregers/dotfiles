return {
    "ThePrimeagen/harpoon",
    branch = "harpoon2",
    dependencies = { { "nvim-lua/plenary.nvim" } },
    config = function()
        local harpoon = require("harpoon")
        harpoon:setup()

        vim.keymap.set("n", "<leader>a", function() harpoon:list():add() end, { desc = "Add file to harpoon list" })
        vim.keymap.set("n", "<C-e>", function() harpoon.ui:toggle_quick_menu(harpoon:list()) end,
            { desc = "Toggle harpoon list" })

        vim.keymap.set("n", "<C-h>", function() harpoon:list():select(1) end,
            { desc = "Switch to 1st slot in harpoon list" })
        vim.keymap.set("n", "<C-j>", function() harpoon:list():select(2) end,
            { desc = "Switch to 2nd slot in harpoon list" })
        vim.keymap.set("n", "<C-k>", function() harpoon:list():select(3) end,
            { desc = "Switch to 3rd slot in harpoon list" })
        vim.keymap.set("n", "<C-l>", function() harpoon:list():select(4) end,
            { desc = "Switch to 4th slot in harpoon list" })
    end,
}
