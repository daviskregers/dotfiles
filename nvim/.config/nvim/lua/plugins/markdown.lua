-- Prettify markdown in the buffer: pipe tables get box-drawing borders with padded
-- cells (source widths don't have to line up), headings get bars, code blocks get a
-- language label. Decoration only — the line under the cursor un-renders to raw text,
-- so editing still happens on the real markdown.

vim.pack.add({
    'https://github.com/MeanderingProgrammer/render-markdown.nvim',
})

require("render-markdown").setup({
    completions = { blink = { enabled = true } },
    code = {
        border = "thin",   -- don't fake a background block; just delimit the fence
        width = "block",
        min_width = 40,
    },
    pipe_table = {
        preset = "round",  -- rounded box-drawing borders instead of raw pipes
        cell = "trimmed",  -- pad to the widest CONTENT, not the widest source cell
        alignment_indicator = "┅",
    },
})
