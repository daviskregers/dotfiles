-- autocmd! remove all autocommands, if entered under a group it will clear that group
vim.cmd [[
    augroup _general_settings
        autocmd!
        autocmd FileType qf,help,man,lspinfo nnoremap <silent> <buffer> q :close<CR>
        autocmd TextYankPost * silent!lua require('vim.highlight').on_yank({higroup = 'Search', timeout = 200})
        autocmd BufWinEnter * :set formatoptions-=cro
        autocmd FileType qf set nobuflisted
    augroup end

    augroup _git
        autocmd!
        autocmd FileType gitcommit setlocal wrap
        autocmd FileType gitcommit setlocal spell
    augroup end

    augroup _markdown
        autocmd!
        autocmd FileType markdown setlocal wrap
        autocmd FileType markdown setlocal spell
    augroup end

    augroup _auto_resize
        autocmd!
        autocmd VimResized * tabdo wincmd =
    augroup end

    augroup _alpha
        autocmd!
        autocmd User AlphaReady set showtabline=0 | autocmd BufUnload <buffer> set showtabline=2
    augroup end

    function FoldConfig()
        set foldmethod=expr
        set foldexpr=nvim_treesitter#foldexpr()
        set foldlevel=20
    endfunction

    augroup _foldconfig
        autocmd!
        autocmd BufAdd,BufEnter,BufNew,BufNewFile,BufWinEnter * :call FoldConfig()
    augroup end

    augroup _hardmode
        autocmd!
        autocmd VimEnter,BufNewFile,BufReadPost * silent! call HardMode()
    augroup end
]]


vim.api.nvim_create_autocmd({ "BufWritePost" }, {
    pattern = { "*Test.php" },
    callback = function ()
        if not vim.g.TEST_RUNNER_ENABLED then return end
        file = vim.fn.expand('%')
        cmd = string.format("%s %s | less", vim.g.TEST_RUNNER, file)
        -- vim.cmd(string.format('98TermExec cmd="%s"', cmd))
    end
})
