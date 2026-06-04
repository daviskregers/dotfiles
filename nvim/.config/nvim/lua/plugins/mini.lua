return {
    {
        'echasnovski/mini.nvim',
        config = function()
            require('mini.diff').setup({
                view = { style = 'number' },
            })

            -- Clearer overlay colors: green = current buffer (added/new), red = reference (old/deleted).
            -- mini.diff re-links these to muted Diff* groups on every ColorScheme, so re-apply after it.
            local function set_diff_overlay_hl()
                local green, red, dim, base = '#a6e3a1', '#f38ba8', '#9399b2', '#1e1e2e'
                local add_bg, del_bg = '#2a3b30', '#3d2730'
                local ok, cp = pcall(function()
                    return require('catppuccin.palettes').get_palette('mocha')
                end)
                if ok and cp then
                    local blend = require('catppuccin.utils.colors').blend
                    green, red, dim, base = cp.green, cp.red, cp.overlay1, cp.base
                    add_bg = blend(green, base, 0.18)
                    del_bg = blend(red, base, 0.18)
                end
                local hi = function(name, opts) vim.api.nvim_set_hl(0, name, opts) end
                -- Buffer side (current/new text): bg only, so treesitter/syntax colors
                -- show through (overlay priority 199 > treesitter 100, so fg would flatten them).
                hi('MiniDiffOverAdd',        { bg = add_bg })
                hi('MiniDiffOverChangeBuf',  { bg = add_bg, bold = true })
                -- Reference side (old text, drawn as virtual lines): red, no syntax to preserve.
                hi('MiniDiffOverChange',     { bg = del_bg, fg = red, bold = true })
                hi('MiniDiffOverDelete',     { bg = del_bg, fg = red })
                hi('MiniDiffOverContext',    { fg = dim })
                hi('MiniDiffOverContextBuf', {})
            end
            vim.api.nvim_create_autocmd('ColorScheme', { callback = set_diff_overlay_hl })
            set_diff_overlay_hl()

            local function maybe_enable_overlay(buf)
                if not vim.g.review_mode then return end
                if not buf or not vim.api.nvim_buf_is_valid(buf) then return end
                if vim.bo[buf].buftype ~= '' then return end
                local ok, md = pcall(require, 'mini.diff')
                if not ok then return end
                local data = md.get_buf_data(buf)
                if data and not data.overlay then
                    pcall(md.toggle_overlay, buf)
                end
            end

            local function clear_overlay(buf)
                local ok, md = pcall(require, 'mini.diff')
                if not ok then return end
                local data = md.get_buf_data(buf)
                if data and data.overlay then
                    pcall(md.toggle_overlay, buf)
                end
            end

            -- Attach mini.diff when entering a buffer in review mode
            vim.api.nvim_create_autocmd('BufWinEnter', {
                callback = function(args)
                    if not vim.g.review_mode then return end
                    if vim.bo[args.buf].buftype ~= '' then return end
                    pcall(require('mini.diff').enable, args.buf)
                end,
            })

            -- Enforce overlay state once mini.diff has computed hunks (also fires on :w)
            vim.api.nvim_create_autocmd('User', {
                pattern = 'MiniDiffUpdated',
                callback = function(args)
                    local buf = (args.data and args.data.buf_id) or vim.api.nvim_get_current_buf()
                    if vim.g.review_mode then
                        maybe_enable_overlay(buf)
                    else
                        clear_overlay(buf)
                    end
                end,
            })

            vim.keymap.set('n', '<leader>gv', function()
                vim.g.review_mode = true
                require('gitsigns').setqflist('all', { open = false })

                vim.defer_fn(function()
                    if not vim.g.review_mode then return end
                    local untracked = vim.fn.systemlist({ 'git', 'ls-files', '--others', '--exclude-standard' })
                    local root = vim.fn.systemlist({ 'git', 'rev-parse', '--show-toplevel' })[1]

                    if vim.v.shell_error == 0 and root and root ~= '' and #untracked > 0 then
                        local items = {}
                        for _, rel in ipairs(untracked) do
                            table.insert(items, {
                                filename = root .. '/' .. rel,
                                lnum = 1,
                                col = 1,
                                text = '[untracked]',
                            })
                        end
                        vim.fn.setqflist({}, 'a', { items = items })
                    end

                    pcall(vim.cmd, 'copen')
                end, 200)

                for _, buf in ipairs(vim.api.nvim_list_bufs()) do
                    if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].buftype == '' then
                        pcall(require('mini.diff').enable, buf)
                        maybe_enable_overlay(buf)
                    end
                end
            end, { desc = 'Review mode: on (qflist + mini.diff overlay)' })

            vim.keymap.set('n', '<leader>gw', function()
                local md = require('mini.diff')
                md.config.options = md.config.options or {}
                local new_state = not md.config.options.ignore_whitespace
                md.config.options.ignore_whitespace = new_state

                local ok_gs_cfg, gs_cfg = pcall(require, 'gitsigns.config')
                if ok_gs_cfg then
                    gs_cfg.config.diff_opts = gs_cfg.config.diff_opts or {}
                    gs_cfg.config.diff_opts.ignore_whitespace = new_state
                end

                for _, buf in ipairs(vim.api.nvim_list_bufs()) do
                    if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].buftype == '' then
                        pcall(md.refresh, buf)
                    end
                end
                pcall(function() require('gitsigns').refresh() end)

                if vim.g.review_mode then
                    vim.defer_fn(function()
                        if not vim.g.review_mode then return end
                        pcall(function()
                            require('gitsigns').setqflist('all', { open = true })
                        end)
                    end, 200)
                end

                vim.notify('Ignore whitespace: ' .. tostring(new_state))
            end, { desc = 'Toggle whitespace-ignore in diff' })

            vim.keymap.set('n', '<leader>gq', function()
                vim.g.review_mode = false
                for _, buf in ipairs(vim.api.nvim_list_bufs()) do
                    if vim.api.nvim_buf_is_loaded(buf) then
                        clear_overlay(buf)
                    end
                end
                pcall(vim.cmd, 'cclose')
            end, { desc = 'Review mode: off' })

            local statusline = require 'mini.statusline'
            local agent_status = require 'custom.agent_statusline'
            agent_status.setup()
            local review_status = require 'custom.review_statusline'
            review_status.setup()

            statusline.setup {
                use_icons = true,
                content = {
                    active = function()
                        local mode, mode_hl = statusline.section_mode({ trunc_width = 120 })
                        local git           = statusline.section_git({ trunc_width = 40 })
                        local diff          = statusline.section_diff({ trunc_width = 75 })
                        local diagnostics   = statusline.section_diagnostics({ trunc_width = 75 })
                        local lsp           = statusline.section_lsp({ trunc_width = 75 })
                        local filename      = statusline.section_filename({ trunc_width = 140 })
                        local fileinfo      = statusline.section_fileinfo({ trunc_width = 120 })
                        local location      = statusline.section_location({ trunc_width = 75 })
                        local search        = statusline.section_searchcount({ trunc_width = 75 })
                        local cc            = agent_status.get()
                        local rev           = review_status.get()

                        return statusline.combine_groups({
                            { hl = mode_hl,                  strings = { mode } },
                            { hl = 'MiniStatuslineDevinfo',  strings = { git, diff, diagnostics, lsp } },
                            '%<',
                            { hl = 'MiniStatuslineFilename', strings = { filename } },
                            '%=',
                            { hl = 'MiniStatuslineDevinfo',  strings = { rev, cc } },
                            { hl = 'MiniStatuslineFileinfo', strings = { fileinfo } },
                            { hl = mode_hl,                  strings = { search, location } },
                        })
                    end,
                },
            }

            vim.api.nvim_set_hl(0, 'MiniStatuslineModeNormal', { link = 'DiffChange', default = true })
        end
    },
}
