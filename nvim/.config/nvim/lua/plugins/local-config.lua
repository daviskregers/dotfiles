vim.pack.add({
    'https://github.com/klen/nvim-config-local'
})

require('config-local').setup {
    config_files = { ".nvim.lua", ".nvimrc", ".exrc" },
    hashfile = vim.fn.stdpath("data") .. "/config-local",

    autocommands_create = true, -- Create autocommands (VimEnter, DirectoryChanged)
    commands_create = true,     -- Create commands (ConfigLocalSource, ConfigLocalEdit, ConfigLocalTrust, ConfigLocalIgnore)
    silent = false,             -- Disable default messages to use custom notifications
    lookup_parents = false,     -- Lookup config files in parent directories
}
