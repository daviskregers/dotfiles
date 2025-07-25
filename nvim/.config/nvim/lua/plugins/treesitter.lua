-- :Inspect
-- :InspectTree + o to query edit
-- > (function_call) @fn

return {
    {
        "nvim-treesitter/nvim-treesitter",
        build = ":TSUpdate",
        config = function()
            require 'nvim-treesitter.configs'.setup {
                ensure_installed = { "c", "lua", "vim", "vimdoc", "query", "markdown", "markdown_inline", "python" },
                sync_install = false,
                ignore_install = {},
                auto_install = false,
                highlight = {
                    enable = true,
                    -- disable = { "c", "rust" },
                    disable = function(lang, buf)
                        local max_filesize = 100 * 1024 -- 100 KB
                        local ok, stats = pcall(vim.loop.fs_stat, vim.api.nvim_buf_get_name(buf))
                        if ok and stats and stats.size > max_filesize then
                            return true
                        end
                    end,
                    additional_vim_regex_highlighting = false,
                },
                incremental_selection = {
                    enable = true,
                    keymaps = {
                        init_selection = '<cr>',
                        node_incremental = '<cr>',
                        node_decremental = '<bs>',
                    },
                },
            }

            vim.cmd([[
              autocmd BufNewFile,BufRead Tiltfile set filetype=starlark
            ]])

            -- vim.cmd [[ hi @function.builtin.lua guifg=pink ]]
        end
    }
}
