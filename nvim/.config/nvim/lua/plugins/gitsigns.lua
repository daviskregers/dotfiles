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
    vim.api.nvim_set_hl(0, 'GitSignsAddLn', { bg = '#1c3322' })
    vim.api.nvim_set_hl(0, 'GitSignsChangeLn', { bg = '#33321c' })
    vim.api.nvim_set_hl(0, 'GitSignsDeleteLn', { bg = '#3a1c1c' })
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
    gs.toggle_deleted(true)  -- inline diff shows once buffers attach on open
    gs.toggle_word_diff(true)
    if vim.tbl_isempty(items) then
        vim.notify('No changes', vim.log.levels.INFO)
    else
        vim.cmd('copen')
        vim.cmd('cfirst')
    end
end, { desc = 'Hunks -> quickfix (all changes + untracked, inline diff)' })
