local g = vim.g
local v = vim.v
local b = vim.bo

g["test#preserve_screen"] = false
g.neomake_highlight = true
g.neomake_open_list = true
g.neomake_list_height = "60"

g.neomake_warning_sign = {
    text = "∙"
}
g.neomake_error_sign = {
    text = "∙"
}

if not g.disable_automake then
    vim.cmd("call neomake#configure#automake('w')")
end

-- HOOK FOR COLORING BACKGROUND BASED ON MAKER STATUS
-- Inspired from https://github.com/skbolton/titan/blob/6c23b9b70c2a56a027675ee9b6fc0772562694b0/nvim/nvim/lua/testing.lua

local M = {}
M.TESTING_STATUS = "init"
M.TESTING_RESULT = {}

M.neomake_on_job_started = function()
    M.TESTING_STATUS = "running"
end

M.neomake_on_job_ended = function()
    local context = g.neomake_hook_context
    M.TESTING_RESULT[context.jobinfo.maker.exe] = context.jobinfo.exit_code
    M.update_background()
end

M.update_background = function()
    if M.has_failing() and g.neomake_highlight then
        M.TESTING_STATUS = "failing"
        vim.cmd("hi! NonText ctermbg=NONE guibg=#560002")
        vim.cmd("hi! Normal ctermbg=NONE guibg=#560002")
    else
        M.TESTING_STATUS = "passing"
        vim.cmd("hi! NonText ctermbg=NONE guibg=NONE")
        vim.cmd("hi! Normal ctermbg=NONE guibg=NONE")
    end
end

M.has_failing = function()
    for k, v in pairs(M.TESTING_RESULT) do
        if v > 0 then
            return true
        end
    end
    return false
end

vim.cmd(
[[
    augroup my_neomake_hooks
    au!
    autocmd User NeomakeJobFinished call luaeval("require('make').neomake_on_job_ended()")
    autocmd User NeomakeJobStarted call luaeval("require('make').neomake_on_job_started()")
    augroup END
]]
)

return M
