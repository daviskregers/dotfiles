local Float = require "plenary.window.float"

vim.cmd([[
    augroup LspPhpactor
      autocmd!
      autocmd Filetype php command! -nargs=0 LspPhpactorReindex lua vim.lsp.buf_notify(0, "phpactor/indexer/reindex",{})
      autocmd Filetype php command! -nargs=0 LspPhpactorConfig lua LspPhpactorDumpConfig()
      autocmd Filetype php command! -nargs=0 LspPhpactorStatus lua LspPhpactorStatus()
    augroup END
]])

local function showWindow(title, syntax, contents)
    local out = {};
    if contents ~= nil then
        for match in string.gmatch(contents, "[^\n]+") do
            table.insert(out, match);
        end
    end

    local float = Float.percentage_range_window(0.6, 0.4, { winblend = 0 }, {
        title = title,
        topleft = "┌",
        topright = "┐",
        top = "─",
        left = "│",
        right = "│",
        botleft = "└",
        botright = "┘",
        bot = "─",
    })

    vim.api.nvim_buf_set_option(float.bufnr, "filetype", syntax)
    vim.api.nvim_buf_set_lines(float.bufnr, 0, -1, false, out)
end

function LspPhpactorDumpConfig()
    local results, _ = vim.lsp.buf_request_sync(0, "phpactor/debug/config", {["return"]=true})
    for _, res in pairs(results or {}) do
        showWindow("Phpactor LSP Configuration", "json", res["result"])
    end
end
function LspPhpactorStatus()
    local results, _ = vim.lsp.buf_request_sync(0, "phpactor/status", {["return"]=true})
    for _, res in pairs(results or {}) do
        showWindow("Phpactor Status", "markdown", res["result"])
    end
end

return {
    filetypes = {"php"},
}
