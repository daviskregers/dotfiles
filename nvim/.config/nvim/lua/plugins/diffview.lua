vim.pack.add({ 'https://github.com/sindrets/diffview.nvim' })

require('diffview').setup({
    -- show new files that git treats as untracked
    show_untracked = true,
    file_panel = {
        listing_style = 'tree',
        win_config = { width = 40 },
    },
    view = {
        -- full-file context, not just hunks
        default = { layout = 'diff2_horizontal' },
        merge_tool = { layout = 'diff3_horizontal' },
    },
})

-- review whole working tree (changed + staged + untracked)
vim.keymap.set('n', '<leader>gd', '<cmd>DiffviewOpen<CR>', { desc = 'Diffview: working tree' })
-- review an entire branch/PR vs main (this is the AI-review workhorse)
vim.keymap.set('n', '<leader>gr', function()
    vim.ui.input({ prompt = 'Diff range (e.g. main...HEAD): ', default = 'main...HEAD' }, function(r)
        if r then vim.cmd('DiffviewOpen ' .. r) end
    end)
end, { desc = 'Diffview: range/PR' })
vim.keymap.set('n', '<leader>gh', '<cmd>DiffviewFileHistory %<CR>', { desc = 'Diffview: file history' })
vim.keymap.set('n', '<leader>gq', '<cmd>DiffviewClose<CR>', { desc = 'Diffview: close' })
