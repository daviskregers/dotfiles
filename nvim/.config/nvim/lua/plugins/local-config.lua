return {
    {
        "klen/nvim-config-local",
        priority = 999999,
        config = function()
            require('config-local').setup {
                config_files = { ".nvim.lua", ".nvimrc", ".exrc" },
                hashfile = vim.fn.stdpath("data") .. "/config-local",

                autocommands_create = true, -- Create autocommands (VimEnter, DirectoryChanged)
                commands_create = true,     -- Create commands (ConfigLocalSource, ConfigLocalEdit, ConfigLocalTrust, ConfigLocalIgnore)
                silent = true,              -- Disable default messages to use custom notifications
                lookup_parents = false,     -- Lookup config files in parent directories
            }
            
            -- Set up custom non-blocking notifications for config changes
            vim.api.nvim_create_autocmd("User", {
                pattern = "ConfigLocalLoaded",
                callback = function()
                    if _G.notify_config_loaded then
                        _G.notify_config_loaded("Local config loaded successfully")
                    else
                        vim.notify("Local config loaded successfully", vim.log.levels.INFO, {
                            title = "Config",
                            timeout = 2000,
                        })
                    end
                end
            })
            
            vim.api.nvim_create_autocmd("User", {
                pattern = "ConfigLocalChanged", 
                callback = function()
                    if _G.notify_config_change then
                        _G.notify_config_change("Config change detected and reloaded")
                    else
                        vim.notify("Config change detected and reloaded", vim.log.levels.INFO, {
                            title = "Config Change",
                            timeout = 2000,
                        })
                    end
                end
            })
        end
    }
}