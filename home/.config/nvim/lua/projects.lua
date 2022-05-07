-- current directory is /home/abcde/projects/awesome/. you open vim in awesome directory.
-- It will load a config file from ~/.config/nvim/projects/awesome.lua or ~/.config/nvim/projects/awesome.vim
-- this config save outside of your git repo and you don't need to check security on that file. It work perfect if you are working on monorepo.

require('nvim-projectconfig').setup({
    -- project_dir = "~/.config/projects-config/",
    -- project_config = {
    --     {
    --         -- full path of your project or a lua regex string
    --         path = "projectconfig",
    --         -- use a function or a path to config file
    --         config = function()
    --             print("abcde")
    --         end
    --     },
    -- },
    silent = false,
    autocmd = true
})

-- TODO: open a new tmux window with the project config in nvim
