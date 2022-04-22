require('nvim-projectconfig').setup({
    project_dir = '~/.config/nvim/projects/',
    project_config = {
        {
            -- full path to project or lua regex string
            path = 'projectconfig',
            -- function or path to config file
            config = function ()
                print('loaded!')
            end
        }
    },
    silent = false, -- display message after config loaded
})

vim.cmd('command! ProjectConfigs :e ~/.config/nvim/projects/')
vim.cmd('command! ProjectConfig :e ~/.config/nvim/lua/projects.lua')
