
function dump(o)
    if type(o) == "table" then
        local s = "{ "
        for k, v in pairs(o) do
            if type(k) ~= "number" then
                k = '"' .. k .. '"'
            end
            s = s .. "[" .. k .. "] = " .. dump(v) .. ","
        end
        return s .. "} "
    else
        return tostring(o)
    end
end

local M = {}
M.init_coverage = function ()
end

vim.cmd(
[[
    augroup my_coverage_hooks
        au!
        autocmd BufEnter * call luaeval("require('coverage').init_coverage()")
    augroup END
]]
)

return M
