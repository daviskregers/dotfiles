vim.pack.add({ 'https://github.com/NeogitOrg/neogit' })

local neogit = require('neogit')

neogit.setup({ integrations = { diffview = true } })

vim.keymap.set('n', '<leader>gg', function() neogit.open() end, { desc = 'Open NeoGit' })
vim.keymap.set('n', '<leader>gc', '<cmd>Neogit branch<CR>', { desc = 'NeoGit Branch' })

-- Agents edit working-tree files on disk; Neogit's filewatcher only watches
-- .git, so re-entering the status buffer won't reflect them. Force a refresh
-- (NeogitStatusRefreshed also runs `set autoread | checktime`, reloading open
-- file buffers).
vim.api.nvim_create_autocmd({ 'BufEnter', 'FocusGained', 'CursorHold' }, {
  group = vim.api.nvim_create_augroup('NeogitAutoRefresh', { clear = true }),
  callback = function(args)
    if vim.bo[args.buf].filetype == 'NeogitStatus' then
      require('neogit').dispatch_refresh()
    end
  end,
})
