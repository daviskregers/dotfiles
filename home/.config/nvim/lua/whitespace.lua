vim.cmd [[
    function TrimWhiteSpace()
        :s/\s*$//
        ''
    endfunction

    xnoremap gs :call TrimWhiteSpace()<CR>
]]
