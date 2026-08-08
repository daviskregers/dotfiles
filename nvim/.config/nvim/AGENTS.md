# nvim config

Neovim configuration. Plugin manager is `vim.pack` (neovim built-in, no lazy/packer).

## Keymap rules

- Avoid keybinds that repeat the same key, e.g. `<leader>aa`, `<leader>bb`. They're slow and awkward to type — prefer distinct keys like `<leader>as`, `<leader>at`.