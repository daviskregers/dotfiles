return {
    'github/copilot.vim',
    dependencies = {
    },
    config = function()
        vim.keymap.set("i", "<C-j>", "copilot#Next()", {expr=true, silent=true})
        vim.keymap.set("i", "<C-k>", "copilot#Previous()", {expr=true, silent=true})
    end
}
