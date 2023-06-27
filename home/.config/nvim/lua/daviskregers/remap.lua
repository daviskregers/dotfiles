local telescope = require('telescope')
vim.g.mapleader = " "
vim.keymap.set("n", "<leader>pv", vim.cmd.Ex)

-- MOVE LINES
vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv")
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv")

-- Move next line to the end of the current one
vim.keymap.set("n", "J", "mzJ`z")

-- Half page jump recenter
vim.keymap.set("n", "<C-d>", "<C-d>zz")
vim.keymap.set("n", "<C-u>", "<C-u>zz")

-- search jump recenter
vim.keymap.set("n", "n", "nzzzv")
vim.keymap.set("n", "N", "Nzzzv")

-- TODO: what does this do again?
vim.keymap.set("x", "<leader>p", [["_dP]])
vim.keymap.set({"n", "v"}, "<leader>y", [["+y]])
vim.keymap.set("n", "<leader>Y", [["+Y]])
vim.keymap.set({"n", "v"}, "<leader>d", [["_d]])

vim.keymap.set("i", "<C-c>", "<Esc>")

vim.keymap.set("n", "Q", "<nop>")
vim.keymap.set("n", "<leader>f", vim.lsp.buf.format)

-- jumplist
vim.keymap.set("n", "<C-k>", "<cmd>cnext<CR>zz")
vim.keymap.set("n", "<C-j>", "<cmd>cprev<CR>zz")
vim.keymap.set("n", "<leader>k", "<cmd>lnext<CR>zz")
vim.keymap.set("n", "<leader>j", "<cmd>lprev<CR>zz")

-- search & replace word under cusrsor
vim.keymap.set("n", "<leader>s", [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]])

-- disable arrow keys
vim.keymap.set({"n", "v", "x"}, "<Left>", "<nop>")
vim.keymap.set({"n", "v", "x"}, "<Right>", "<nop>")
vim.keymap.set({"n", "v", "x"}, "<Up>", "<nop>")
vim.keymap.set({"n", "v", "x"}, "<Down>", "<nop>")

-- indent
vim.keymap.set("v", "<", "<gv")
vim.keymap.set("v", ">", ">gv")

-- sort lines
vim.keymap.set("v", "gs", ":sort u<CR>")

-- align
vim.keymap.set("v", "<leader>=", ":'<,'>Align ")

-- show diagnostics popup
_G.LspDiagnosticsPopupHandler = function()
  print('called')
  local current_cursor = vim.api.nvim_win_get_cursor(0)
  local last_popup_cursor = vim.w.lsp_diagnostics_last_cursor or {nil, nil}

  -- Show the popup diagnostics window,
  -- but only once for the current cursor location (unless moved afterwards).
  if not (current_cursor[1] == last_popup_cursor[1] and current_cursor[2] == last_popup_cursor[2]) then
    vim.w.lsp_diagnostics_last_cursor = current_cursor
    vim.diagnostic.open_float(0, {scope="cursor"})
  end
end
vim.keymap.set("n", "<leader>k", _G.LspDiagnosticsPopupHandler)
vim.keymap.set("n", "<leader>w", ":Telescope pnpm workspace<CR>")
vim.keymap.set("n", "<leader>n", ":Telescope package_info<CR>")
