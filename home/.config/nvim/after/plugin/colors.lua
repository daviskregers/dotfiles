function ApplyDaveColors(color)
    color = color or 'onedark_dark'

    vim.cmd.colorscheme(color)

    -- vim.api.nvim_set_hl(0, "Normal", {bg = "none"})
    -- vim.api.nvim_set_hl(0, "NormalNC", {bg = "none"})
    -- vim.api.nvim_set_hl(0, "NormalFloat", {bg = "none"})
    vim.api.nvim_set_hl(0, 'BlameLineNvim', {fg="#4c4c4c"})
    vim.api.nvim_set_hl(0, 'Comment', {fg="#D33257"})
    vim.api.nvim_set_hl(0, 'ExtraWhitespace', {bg="red"})
    vim.api.nvim_set_hl(0, 'ColorColumn', {bg="#380a09"})
end

ApplyDaveColors()