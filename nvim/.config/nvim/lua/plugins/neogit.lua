vim.pack.add({ 'https://github.com/NeogitOrg/neogit' })

local neogit = require('neogit')

neogit.setup({ integrations = { diffview = true } })

vim.keymap.set('n', '<leader>gg', function() neogit.open() end, { desc = 'Open NeoGit' })
vim.keymap.set('n', '<leader>gc', '<cmd>Neogit branch<CR>', { desc = 'NeoGit Branch' })
