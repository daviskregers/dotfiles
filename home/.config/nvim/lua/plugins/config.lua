return {
    {
        "klen/nvim-config-local",
        priority = 999999,
        config = function()
            require('config-local').setup {
                config_files = { ".nvim.lua", ".nvimrc", ".exrc" },
                hashfile = vim.fn.stdpath("data") .. "/config-local",

                autocommands_create = true, -- Create autocommands (VimEnter, DirectoryChanged)
                commands_create = true, -- Create commands (ConfigLocalSource, ConfigLocalEdit, ConfigLocalTrust, ConfigLocalIgnore)
                silent = false,       -- Disable plugin messages (Config loaded/ignored)
                lookup_parents = false, -- Lookup config files in parent directories
            }
        end
    }
}
