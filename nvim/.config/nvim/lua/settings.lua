require('vim._core.ui2').enable()

-- leader
vim.g.mapleader        = " "
vim.g.maplocalleader   = "\\"

-- preserve chonker cursor in insert
vim.opt.guicursor      = ""

-- use relative line numbers
vim.opt.nu             = true
vim.opt.relativenumber = true

-- use 4 spaces
vim.opt.tabstop        = 4
vim.opt.softtabstop    = 4
vim.opt.shiftwidth     = 4
vim.opt.expandtab      = true

-- undo
vim.opt.swapfile       = false
vim.opt.backup         = false
vim.opt.undodir        = os.getenv("HOME") .. "/.vim/undodir"
vim.opt.undofile       = true

-- highlights
vim.opt.hlsearch       = true -- highlights search
vim.opt.incsearch      = true

-- scrolloff
vim.opt.scrolloff      = 8

-- enable sign column
vim.opt.signcolumn     = "yes"
vim.opt.isfname:append("@-@")

-- cursorline
vim.opt.cursorline = true

-- whitespace
vim.o.list         = true
vim.o.listchars    = 'tab:» ,lead:•,trail:•'
vim.api.nvim_set_hl(0, 'TrailingWhitespace', { bg = 'LightRed' })
vim.api.nvim_create_autocmd('BufEnter', {
    pattern = '*',
    command = [[
        syntax clear TrailingWhitespace |
        syntax match TrailingWhitespace "\_s\+$"
    ]]
}
)

vim.api.nvim_create_autocmd("BufWritePre", {
    pattern = "*",
    callback = function()
        vim.cmd([[%s/\s\+$//e]])
    end,
})

-- yanks
vim.keymap.set({ "n", "v" }, "<leader>y", [["+y]], { desc = "yank to clipboard" })
vim.api.nvim_create_autocmd("TextYankPost", {
    desc = "Highlight when yanking text",
    group = vim.api.nvim_create_augroup("highlight-yank", { clear = true }),
    callback = function()
        vim.highlight.on_yank()
    end,
})

-- disable arrows
vim.keymap.set({ "n", "v", "x" }, "<Down>", "<nop>")
vim.keymap.set({ "n", "v", "x" }, "<Left>", "<nop>")
vim.keymap.set({ "n", "v", "x" }, "<Right>", "<nop>")
vim.keymap.set({ "n", "v", "x" }, "<Up>", "<nop>")

-- move line
vim.keymap.set("n", "J", "mzJ`z", { desc = "Move the next line to the end of the current one" })
vim.keymap.set("v", "<", "<gv", { desc = "indent line left" })
vim.keymap.set("v", ">", ">gv", { desc = "indent line right" })
vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv", { desc = "Move line down" })
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv", { desc = "Move line up" })

-- Sort selection
vim.keymap.set("v", "gs", ":sort u<CR>", { desc = "Sort selected lines, remove duplicates" })

-- jumps & recenter
vim.keymap.set("n", "<C-d>", "<C-d>zz", { desc = "Jump half page down & recenter" })
vim.keymap.set("n", "<C-u>", "<C-u>zz", { desc = "Jump half page up & recenter" })
vim.keymap.set("n", "n", "nzzzv", { desc = "Next search occurrence & recenter" })
vim.keymap.set("n", "N", "Nzzzv", { desc = "Prev search occurrence & recenter" })

-- quickfix / location list nav
vim.keymap.set("n", "[q", "<cmd>cprev<CR>zz", { desc = "Prev quickfix item & recenter" })
vim.keymap.set("n", "]q", "<cmd>cnext<CR>zz", { desc = "Next quickfix item & recenter" })
vim.keymap.set("n", "<leader>j", "<cmd>lprev<CR>zz", { desc = "Prev location-list item & recenter" })
vim.keymap.set("n", "<leader>k", "<cmd>lnext<CR>zz", { desc = "Next location-list item & recenter" })

-- splits
vim.opt.splitbelow = true
vim.opt.splitright = true

-- search
vim.opt.ignorecase = true
vim.opt.smartcase = true

-- colors
vim.opt.termguicolors = true

-- colorcolumn
vim.opt.colorcolumn = "80"
vim.cmd("highlight ColorColumn ctermbg=0 guibg=#232323")

-- folding
-- treesitter-based folding; all folds open on open (foldlevelstart=99)
vim.opt.foldcolumn     = "1"
vim.opt.foldlevel      = 99
vim.opt.foldlevelstart = 99
vim.opt.foldenable     = true
vim.opt.foldmethod     = "expr"
vim.opt.foldexpr       = "v:lua.vim.treesitter.foldexpr()"


-- swap the word under the cursor with the next word: `int x` -> `x int`
-- (then add `:` for `x: int`). Cursor stays at its original location.
local function swap_word_forward()
    local row, col = unpack(vim.api.nvim_win_get_cursor(0)) -- col is 0-indexed byte
    local line = vim.api.nvim_get_current_line()
    local i = 1
    while true do
        local s, _, w1, sep, w2 = line:find("([%w_]+)([^%w_]+)([%w_]+)", i)
        if not s then return end
        local w1_start, w1_end = s - 1, s - 1 + #w1 - 1
        if col >= w1_start and col <= w1_end then
            vim.api.nvim_set_current_line(
                line:sub(1, s - 1) .. w2 .. sep .. w1 .. line:sub(s + #w1 + #sep + #w2)
            )
            vim.api.nvim_win_set_cursor(0, { row, col })
            return
        end
        i = s + 1
    end
end

vim.keymap.set("n", "<leader>sw", swap_word_forward, { desc = "Swap word with the next word" })

-- statusline: append the code-agents segment (background agent counts +
-- claude 5h usage) onto nvim's built-in default rather than replacing it —
-- nothing else in this config sets 'statusline'. Plain %{...} (not %{%...%})
-- so literal "%"/"(" in the returned text (e.g. "5h:42%(1h5m)") render as-is
-- instead of being re-scanned as statusline items.
vim.o.statusline = vim.o.statusline .. "%{v:lua.require('code-agents.statusline').get()} "
