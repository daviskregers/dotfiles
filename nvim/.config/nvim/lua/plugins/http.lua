vim.pack.add({
    'https://github.com/mistweaverco/kulala.nvim',
})

local kulala = require('kulala')

-- Runs .http/.rest files. Needs curl (+ tree-sitter-cli for the http grammar).
-- contenttypes: this kulala build ships without a default `contenttypes` table, so
-- request-variable capture ({{name.response.body..jsonpath}}) crashes on nil. Supplying
-- it here restores JSON body resolution via jq (reference as {{login.response.body..token}}).
kulala.setup({
    contenttypes = {
        ["application/json"] = { ft = "json", pathresolver = { "jq", "-r", "{{path}}" } },
    },
})

vim.keymap.set("n", "<leader>er", kulala.run, { desc = "HTTP: run request under cursor" })
vim.keymap.set("n", "<leader>el", kulala.replay, { desc = "HTTP: replay last request" })
vim.keymap.set("n", "<leader>ev", kulala.set_selected_env, { desc = "HTTP: select env" })
vim.keymap.set("n", "<leader>et", kulala.toggle_view, { desc = "HTTP: toggle body/headers view" })
vim.keymap.set("n", "<leader>es", kulala.scratchpad, { desc = "HTTP: open scratchpad" })
