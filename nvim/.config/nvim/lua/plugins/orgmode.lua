vim.pack.add({
    'https://github.com/nvim-orgmode/orgmode',
    'https://github.com/nvim-orgmode/telescope-orgmode.nvim',
})

require('orgmode').setup({
    org_agenda_files = '~/Documents/Orgfiles/**/*',
    org_default_notes_file = '~/Documents/Orgfiles/Inbox.org',
})

vim.lsp.enable('org')

require("telescope").load_extension("orgmode")

local ext = require("telescope").extensions.orgmode
vim.keymap.set("n", "<leader>oh", ext.search_headings, { desc = "Org headlines" })
vim.keymap.set("n", "<leader>ot", ext.search_tags, { desc = "Org tags" })
vim.keymap.set("n", "<leader>or", ext.refile_heading, { desc = "Org refile" })
vim.keymap.set("n", "<leader>ol", ext.insert_link, { desc = "Org insert link" })
