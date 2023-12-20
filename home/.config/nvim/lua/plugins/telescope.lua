return {
    'nvim-telescope/telescope.nvim',
    tag = '0.1.5',
    dependencies = { 'nvim-lua/plenary.nvim' },
    keys = function()
        local builtin = require("telescope.builtin")
        return {
            { '<leader>pf', builtin.find_files,                                                       desc = 'Find files' },
            { '<leader>pp', builtin.git_files,                                                        desc = 'Find git files' },
            { '<C-p>',      ':Telescope fd<CR>',                                                      desc = "Select file" },
            { '<leader>ps', function() builtin.grep_string({ search = vim.fn.input("Grep > ") }) end, desc = "Find in files" }
        }
    end
}
