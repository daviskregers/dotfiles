local M = {}

M.todo = {
  n = {
    ["<leader>td"] = { ":TodoTelescope<CR>", "Open TODO in Telescope" },
    ["<leader>tq"] = { ":TodoQuickFix<CR>", "Open TODO in QuickFix" },
    ["<leader>tl"] = { ":TodoLocList<CR>", "Open TODO in LocList" },
  }
}

M.buffer = {
  n = {
    ['<A-,>'] = { ':Tbufprev<CR>', 'previous tab' },
    ['<A-.>'] = { ':Tbufnext<CR>', 'next tab' },
    ['<A-Left>'] = { ':Tbufprev<CR>', 'previous tab' },
    ['<A-Right>'] = { ':Tbufnext<CR>', 'next tab' },
    ['<leader>q'] = { ':Tbufclose<CR>', 'close tab' },
    ['<leader>Q'] = { ':BufOnly<CR>', 'close all tabs except current'}
  }
}

M.lineoperations = {
  n = {
    ['<A-Down>'] = { ':m .+1<CR>==', 'move line down' },
    ['<A-Up>'] = { ':m .-2<CR>==', 'move line up' },
    ['<A-j>'] = { ':m .+1<CR>==', 'move line down' },
    ['<A-k>'] = { ':m .-2<CR>==', 'move line up' },
  },
  i = {
    ['<A-Down>'] = { '<Esc>:m .+1<CR>==gi', 'moveline down' },
    ['<A-Up>'] = { '<Esc>:m .-2<CR>==gi', 'move line up' },
    ['<A-j>'] = { '<Esc>:m .+1<CR>==gi', 'move line down' },
    ['<A-k>'] = { '<Esc>:m .-2<CR>==gi', 'move line up' },
  },
  v = {
    ['<'] = { '<gv', 'indent left' },
    ['<A-Down>'] = { ':m \'>+1<CR>gv=gv', 'move line down' },
    ['<A-Up>'] = { ':m \'<-2<CR>gv=gv', 'move line up' },
    ['<A-j>'] = { ':m \'>+1<CR>gv=gv', 'move line down' },
    ['<A-k>'] = { ':m \'<-2<CR>gv=gv', 'move line up' },
    ['<leader>s'] = { ':sort u<CR>', 'sort lines & filter by unique' },
    ['>'] = { '>gv', 'indent right' },
  },
}

return M
