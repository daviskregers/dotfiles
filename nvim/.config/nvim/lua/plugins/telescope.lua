vim.api.nvim_create_autocmd('PackChanged', {
    callback = function(ev)
        local name, kind = ev.data.spec.name, ev.data.kind
        if name == 'telescope-fzf-native.nvim' and (kind == 'install' or kind == 'update') then
            vim.system({ 'cmake', '-S.', '-Bbuild', '-DCMAKE_BUILD_TYPE=Release' }, { cwd = ev.data.path }, function(obj)
                if obj.code ~= 0 then
                    vim.notify 'cmake --build failed for telescope-fzf-native.nvim'
                else
                    vim.system({ 'cmake', '--build', 'build', '--config', 'Release', '--target', 'install' },
                        { cwd = ev.data.path })
                end
            end)
        end
    end,
})

vim.pack.add({
    'https://github.com/nvim-telescope/telescope.nvim',
    'https://github.com/nvim-telescope/telescope-fzf-native.nvim'
})

local telescope = require('telescope')

telescope.setup {
    defaults = {
        file_ignore_patterns = {
            '.git/',
        },
    },
    pickers = {
        find_files = {
            theme = "ivy",
            hidden = true,
        },
        live_grep = {
            theme = "ivy",
            hidden = true,
        },
        help_tags = {
            theme = "ivy",
            hidden = true,
        }
    },
    extensions = {
        fzf = {}
    }
}

telescope.load_extension('fzf')

require('plugins.telescope-multigrep').setup {}

vim.keymap.set("n", "<C-p>", require('telescope.builtin').find_files, { desc = 'Telescope find files' })
vim.keymap.set('n', '<leader>ph', require('telescope.builtin').help_tags, { desc = 'Telescope help' })
vim.keymap.set("n", "<leader>pc", function()
    require('telescope.builtin').find_files {
        cwd = vim.fn.stdpath("config")
    }
end, { desc = 'Find config files' })

vim.keymap.set("n", "<leader>pa", function()
    local files = {}
    if vim.fn.isdirectory(".dk-notes") == 1 then
        for name, type in vim.fs.dir(".dk-notes", { depth = 10 }) do
            if type == "file" then
                local path = ".dk-notes/" .. name
                local stat = vim.uv.fs_stat(path)
                if stat then
                    table.insert(files, { path = path, mtime = stat.mtime.sec })
                end
            end
        end
    end
    if #files == 0 then
        vim.notify("No .dk-notes files found", vim.log.levels.INFO)
        return
    end
    table.sort(files, function(a, b) return a.mtime > b.mtime end)
    local paths = {}
    for _, f in ipairs(files) do
        table.insert(paths, f.path)
    end
    local pickers = require('telescope.pickers')
    local finders = require('telescope.finders')
    local conf = require('telescope.config').values
    local previewers = require('telescope.previewers')
    pickers.new(require('telescope.themes').get_ivy({}), {
        prompt_title = "AI artifacts / reviews (mtime desc)",
        finder = finders.new_table {
            results = paths,
            entry_maker = function(entry)
                return {
                    value = entry,
                    display = entry,
                    ordinal = entry,
                    path = entry,
                }
            end,
        },
        sorter = conf.generic_sorter({}),
        previewer = conf.file_previewer({}),
    }):find()
end, { desc = "Telescope ai artifacts/reviews" })
