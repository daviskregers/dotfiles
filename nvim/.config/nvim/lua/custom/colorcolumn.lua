local WIDTH   = 80
local LENGTH  = vim.api.nvim_win_get_width(0)

local M       = {}
M.textwidth   = WIDTH
M.range       = function(from, to)
    local result = {}
    for var = from, to do
        table.insert(result, var)
    end
    return result
end
M.colorcolumn = table.concat(M.range(WIDTH, LENGTH), ",")

return M
