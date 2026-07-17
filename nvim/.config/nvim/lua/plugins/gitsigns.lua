vim.pack.add({ 'https://github.com/lewis6991/gitsigns.nvim' })

require('gitsigns').setup({
    signcolumn = true,
    linehl = true,
    current_line_blame = true,
})

-- full-line background for hunks (additions stand out, not just the gutter sign).
-- bg-only so treesitter keeps coloring the text; re-applied on ColorScheme because
-- the colorscheme loads after this file and would otherwise wipe these overrides.
local function set_hunk_hl()
    -- Reuse the theme's own diff-mode line backgrounds (bg-only, so treesitter
    -- keeps the fg). They're palette-matched and already tuned to read on oled's
    -- pure-black Normal without washing out the muted fg — the balance a hand-
    -- picked hex kept missing: #0e1c13 was too dark to see on blank/sparse lines
    -- (near-zero luminance delta from #000000), #1c3322 washed the fg. Deriving
    -- from Diff* also auto-tracks a variant/colorscheme change.
    local function diff_bg(name) return vim.api.nvim_get_hl(0, { name = name }).bg end
    vim.api.nvim_set_hl(0, 'GitSignsAddLn', { bg = diff_bg('DiffAdd') })
    vim.api.nvim_set_hl(0, 'GitSignsChangeLn', { bg = diff_bg('DiffChange') })
    vim.api.nvim_set_hl(0, 'GitSignsDeleteLn', { bg = diff_bg('DiffDelete') })
    -- Staged *Ln groups: gitsigns derives these from the *Ln above with a 0.5
    -- fg_factor, but at setup() time GitSignsAddLn still links to DiffAdd (fg+bg),
    -- so staged lines end up with dimmed-green *text* (treesitter lost). Pin them
    -- bg-only too. Same bg as unstaged — the sign column still marks staged/unstaged.
    vim.api.nvim_set_hl(0, 'GitSignsStagedAddLn', { bg = diff_bg('DiffAdd') })
    vim.api.nvim_set_hl(0, 'GitSignsStagedChangeLn', { bg = diff_bg('DiffChange') })
    vim.api.nvim_set_hl(0, 'GitSignsStagedDeleteLn', { bg = diff_bg('DiffDelete') })
    -- inline word-diff (opt-in via <leader>hd): one step lighter than the line
    -- bg so changed words stand out within a changed line; still bg-only.
    vim.api.nvim_set_hl(0, 'GitSignsAddInline', { bg = '#17321f' })
    vim.api.nvim_set_hl(0, 'GitSignsChangeInline', { bg = '#323016' })
    vim.api.nvim_set_hl(0, 'GitSignsDeleteInline', { bg = '#3a1818' })
end
set_hunk_hl()
vim.api.nvim_create_autocmd('ColorScheme', { callback = set_hunk_hl })

local gs = require('gitsigns')

vim.keymap.set('n', ']h', function() gs.nav_hunk('next') end, { desc = 'Next hunk' })
vim.keymap.set('n', '[h', function() gs.nav_hunk('prev') end, { desc = 'Prev hunk' })
vim.keymap.set('n', '<leader>gp', gs.preview_hunk, { desc = 'Preview hunk' })

-- single-hunk staging (on the working-tree buffer)
vim.keymap.set('n', '<leader>hs', gs.stage_hunk, { desc = 'Stage hunk' })
vim.keymap.set('n', '<leader>hu', gs.undo_stage_hunk, { desc = 'Undo stage hunk' })
vim.keymap.set('n', '<leader>hr', gs.reset_hunk, { desc = 'Reset hunk' })
-- line-range staging
vim.keymap.set('v', '<leader>hs', function() gs.stage_hunk({ vim.fn.line('.'), vim.fn.line('v') }) end, { desc = 'Stage selected lines' })
vim.keymap.set('v', '<leader>hr', function() gs.reset_hunk({ vim.fn.line('.'), vim.fn.line('v') }) end, { desc = 'Reset selected lines' })

-- inline diff display
vim.keymap.set('n', '<leader>hi', gs.preview_hunk_inline, { desc = 'Inline diff: this hunk' })
vim.keymap.set('n', '<leader>hd', function()
    gs.toggle_deleted()
    gs.toggle_word_diff()
end, { desc = 'Toggle inline diff (whole buffer)' })

-- quickfix list of every hunk in the repo (vs HEAD), independent of open buffers.
-- Built straight from `git diff` because gitsigns' setqflist('all') only covers
-- *attached* buffers (empty on a fresh session). Untracked files are marked
-- intent-to-add (git add -N) so new files show up as additions. Reversible: `git reset`.
vim.keymap.set('n', '<leader>hq', function()
    local root = vim.fn.systemlist('git rev-parse --show-toplevel')[1]
    if not root or vim.v.shell_error ~= 0 then
        vim.notify('Not in a git repo', vim.log.levels.WARN)
        return
    end
    local gitc = 'git -C ' .. vim.fn.shellescape(root) .. ' '

    -- intent-to-add untracked files so they appear in the diff as additions
    local untracked = vim.fn.systemlist(gitc .. 'ls-files --others --exclude-standard')
    if not vim.tbl_isempty(untracked) then
        vim.fn.system(gitc .. 'add -N -- ' .. table.concat(vim.tbl_map(vim.fn.shellescape, untracked), ' '))
    end

    -- one quickfix entry per hunk header, parsed from the unified diff vs HEAD
    local items, file = {}, nil
    for _, line in ipairs(vim.fn.systemlist(gitc .. 'diff HEAD -U0 --no-color')) do
        if line:match('^%+%+%+ ') then
            file = line:match('^%+%+%+ b/(.*)$') -- nil for /dev/null (deletions)
        else
            local lnum = line:match('^@@ %-%d+[,%d]* %+(%d+)')
            if lnum and file then
                table.insert(items, { filename = root .. '/' .. file, lnum = tonumber(lnum), col = 1, text = 'hunk' })
            end
        end
    end

    vim.fn.setqflist(items, 'r')
    gs.toggle_deleted(true)  -- deleted lines show once buffers attach on open
    -- NB: no toggle_word_diff here — near-useless on fully-added files and it
    -- greens the whole buffer. Use <leader>hd to opt in per session.
    if vim.tbl_isempty(items) then
        vim.notify('No changes', vim.log.levels.INFO)
    else
        vim.cmd('copen')
        vim.cmd('cfirst')
    end
end, { desc = 'Hunks -> quickfix (all changes + untracked, inline diff)' })
