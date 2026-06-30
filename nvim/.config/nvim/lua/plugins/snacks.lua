vim.pack.add({
    'https://github.com/folke/snacks.nvim',
})

-- Only the image module: render mermaid (and other) fenced blocks inline, in the
-- buffer, at the block's location. Needs ghostty/kitty (Kitty graphics + Unicode
-- placeholders — wezterm can't), ImageMagick, and mmdc for mermaid. tmux must have
-- allow-passthrough on (set in .tmux.conf; snacks also auto-enables it).
require('snacks').setup({
    image = {
        doc = {
            enabled = true,
            inline = true,    -- true inline-in-buffer (vs float) on supported terminals
            max_width = 150,  -- cells; defaults (80x40) shrink tall diagrams — height cap
            max_height = 300, -- is usually the binding constraint, so raise it most.
        },
    },
})
