return {
    'akinsho/toggleterm.nvim',
    version = "*",
    config = function()
        require('toggleterm').setup({
            size = 20,
            open_mapping = [[<c-\>]],
            hide_numbers = true,
            shade_filetypes = {},
            shade_terminals = true,
            shading_factor = 2,
            start_in_insert = true,
            insert_mappings = true,
            persist_size = true,
            direction = "float",
            close_on_exit = true,
            shell = vim.o.shell,
            float_opts = {
                border = "curved",
                winblend = 0,
                highlights = {
                    border = "Normal",
                    background = "Normal",
                },
            },
        })

        local Terminal = require("toggleterm.terminal").Terminal
        local lazygit = Terminal:new({ cmd = "lazygit", hidden = true })

        vim.keymap.set("n", "<leader>gg", function() lazygit:toggle() end, { desc = 'git - toggle laztgit' })

        -- typescript
        vim.api.nvim_create_augroup('tests', { clear = true })
        vim.api.nvim_create_autocmd('FileType', {
            group = 'tests',
            pattern = 'typescript',
            command = 'nnoremap <buffer><silent><leader>tl :vsplit term://pnpm test<cr>'
        })
        vim.api.nvim_create_autocmd('FileType', {
            group = 'tests',
            pattern = 'typescript',
            command = 'nnoremap <buffer><silent><leader>tk :split term://pnpm test<cr>'
        })
        vim.api.nvim_create_autocmd('FileType', {
            group = 'tests',
            pattern = 'typescript',
            command = 'nnoremap <buffer><silent><leader>tg :vsplit term://pnpm lint<cr>'
        })
        vim.api.nvim_create_autocmd('FileType', {
            group = 'tests',
            pattern = 'typescript',
            command = "nnoremap <buffer><silent><leader>tw :vsplit term://nodemon --exec 'clear && pnpm test' -e ts,js<cr>"
        })
        -- javascript
        vim.api.nvim_create_autocmd('FileType', {
            group = 'tests',
            pattern = 'javascript',
            command = 'nnoremap <buffer><silent><leader>tl :vsplit term://pnpm test<cr>'
        })
        vim.api.nvim_create_autocmd('FileType', {
            group = 'tests',
            pattern = 'javascript',
            command = 'nnoremap <buffer><silent><leader>tl :split term://pnpm test<cr>'
        })
        vim.api.nvim_create_autocmd('FileType', {
            group = 'tests',
            pattern = 'javascript',
            command = 'nnoremap <buffer><silent><leader>tg :vsplit term://pnpm lint<cr>'
        })
        vim.api.nvim_create_autocmd('FileType', {
            group = 'tests',
            pattern = 'javascript',
            command = "nnoremap <buffer><silent><leader>tw :vsplit term://nodemon --exec 'clear && pnpm test' -e ts,js<cr>"
        })
        -- php
        vim.api.nvim_create_autocmd('FileType', {
            group = 'tests',
            pattern = 'php',
            command = 'nnoremap <buffer><silent><leader>tl :vsplit term://composer test %<cr>'
        })
        vim.api.nvim_create_autocmd('FileType', {
            group = 'tests',
            pattern = 'php',
            command = 'nnoremap <buffer><silent><leader>tk :split term://composer test %<cr>'
        })
        -- php
        vim.api.nvim_create_autocmd('FileType', {
            group = 'tests',
            pattern = 'dockerfile',
            command = 'nnoremap <buffer><silent><leader>tl :vsplit term://docker build .<cr>'
        })
        vim.api.nvim_create_autocmd('FileType', {
            group = 'tests',
            pattern = 'dockerfile',
            command = 'nnoremap <buffer><silent><leader>tk :split term://docker build .<cr>'
        })
        -- golang
        vim.api.nvim_create_autocmd('FileType', {
            group = 'tests',
            pattern = 'go',
            command = 'nnoremap <buffer><silent><leader>tr :vsplit term://go run .<cr>'
        })
        vim.api.nvim_create_autocmd('FileType', {
            group = 'tests',
            pattern = 'go',
            command = 'nnoremap <buffer><silent><leader>tl :vsplit term://go test<cr>'
        })
        vim.api.nvim_create_autocmd('FileType', {
            group = 'tests',
            pattern = 'go',
            command = 'nnoremap <buffer><silent><leader>tk :split term://go test<cr>'
        })
    end
}
