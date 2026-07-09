local FZF_PLUGIN_NAME = 'telescope-fzf-native.nvim'

local function find_fzf_plugin_dir()
    local pack_root = vim.fn.stdpath('data') .. '/site/pack'
    for name, type in vim.fs.dir(pack_root) do
        if type == 'directory' then
            local candidate = pack_root .. '/' .. name .. '/opt/' .. FZF_PLUGIN_NAME
            if vim.fn.isdirectory(candidate) == 1 then
                return candidate
            end
        end
    end
    return pack_root .. '/core/opt/' .. FZF_PLUGIN_NAME
end

local FZF_PLUGIN_DIR = find_fzf_plugin_dir()
local FZF_LIB = FZF_PLUGIN_DIR .. '/build/libfzf.so'

local function build_fzf_native(path)
    path = path or FZF_PLUGIN_DIR
    local obj = vim.system({ 'make' }, { cwd = path }):wait()
    if obj.code ~= 0 then
        vim.notify(
            string.format('Failed to build %s in %s (exit %d):\n%s', FZF_PLUGIN_NAME, path, obj.code, obj.stderr or ''),
            vim.log.levels.ERROR
        )
        return false
    end
    return true
end

vim.api.nvim_create_autocmd('PackChanged', {
    callback = function(ev)
        local name, kind = ev.data.spec.name, ev.data.kind
        if name == FZF_PLUGIN_NAME and (kind == 'install' or kind == 'update') then
            build_fzf_native(ev.data.path)
        end
    end,
})

vim.api.nvim_create_user_command('BuildFzfNative', function()
    build_fzf_native()
end, { desc = 'Build telescope-fzf-native.nvim C extension' })

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

if vim.fn.filereadable(FZF_LIB) == 1 or build_fzf_native(FZF_PLUGIN_DIR) then
    telescope.load_extension('fzf')
else
    vim.notify(
        string.format('%s is missing (%s). Run :BuildFzfNative to rebuild it.', FZF_PLUGIN_NAME, FZF_LIB),
        vim.log.levels.WARN
    )
end

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
