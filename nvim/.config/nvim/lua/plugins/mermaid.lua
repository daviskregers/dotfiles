-- Mermaid browser fallback (<leader>mb). Inline-in-buffer rendering is handled by
-- snacks.image (capped at window size — useless for big, dense diagrams). This writes
-- a tiny HTML page that renders the block client-side via mermaid.js and opens it in
-- the browser: faithful, zoom/pan for free, and NO mmdc/chromium (which crashes).

local function block_at_cursor()
    if vim.bo.filetype == "mermaid" then
        return vim.api.nvim_buf_get_lines(0, 0, -1, false)
    end
    local cur = vim.api.nvim_win_get_cursor(0)[1]
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    local open_i, lang = nil, nil
    for i, line in ipairs(lines) do
        local info = line:match("^%s*```+%s*(%S*)")
        if info ~= nil then
            if open_i == nil then
                open_i, lang = i, info
            else
                if lang == "mermaid" and cur >= open_i and cur <= i then
                    return vim.list_slice(lines, open_i + 1, i - 1)
                end
                open_i, lang = nil, nil
            end
        end
    end
    return nil
end

local function preview_browser()
    local block = block_at_cursor()
    if not block or #block == 0 then
        vim.notify("No ```mermaid block under cursor", vim.log.levels.WARN)
        return
    end
    -- Escape so any <, >, & in the source survive HTML parsing; the browser decodes
    -- them back to literals in textContent before mermaid.js reads the diagram.
    local src = table.concat(block, "\n"):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
    local theme = vim.o.background == "dark" and "dark" or "default"
    local html = ([[<!DOCTYPE html>
<html><head><meta charset="utf-8">
<script type="module">
import mermaid from 'https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.esm.min.mjs';
mermaid.initialize({ startOnLoad: true, theme: '%s' });
</script>
<style>html,body{margin:0;height:100%%;background:#1e1e1e}.mermaid{display:flex;justify-content:center;padding:1rem}</style>
</head><body><pre class="mermaid">
%s
</pre></body></html>]]):format(theme, src)

    local path = vim.fn.tempname() .. ".html"
    vim.fn.writefile(vim.split(html, "\n"), path)
    vim.ui.open(path)
end

vim.keymap.set("n", "<leader>mb", preview_browser, { desc = "Mermaid: open block in browser (mermaid.js, zoomable)" })
