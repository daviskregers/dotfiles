-- :Inspect
-- :InspectTree + o to query edit
-- > (function_call) @fn

local ensure_installed = {
    "c", "lua", "vim", "vimdoc", "query",
    "markdown", "markdown_inline", "python", "yaml",
}

local max_filesize = 100 * 1024 -- 100 KB

return {
    {
        "nvim-treesitter/nvim-treesitter",
        branch = "main",
        build = ":TSUpdate",
        config = function()
            local ts = require("nvim-treesitter")
            ts.setup()
            ts.install(ensure_installed)

            -- Tiltfile is Starlark (a Python dialect) -> highlight with python grammar
            vim.treesitter.language.register("python", "tiltfile")

            local function start(buf, lang)
                if not vim.api.nvim_buf_is_valid(buf) then return end
                pcall(vim.treesitter.start, buf, lang)
            end

            -- main-branch replacement for the old `highlight` module:
            -- enable treesitter highlighting per buffer, auto-installing missing parsers.
            vim.api.nvim_create_autocmd("FileType", {
                desc = "Start treesitter highlighting",
                callback = function(ev)
                    local lang = vim.treesitter.language.get_lang(vim.bo[ev.buf].filetype)
                    if not lang then return end

                    local ok, stats = pcall(vim.loop.fs_stat, vim.api.nvim_buf_get_name(ev.buf))
                    if ok and stats and stats.size > max_filesize then return end

                    if vim.tbl_contains(ts.get_installed(), lang) then
                        start(ev.buf, lang)
                    else
                        ts.install(lang):await(function(err)
                            if not err then
                                vim.schedule(function() start(ev.buf, lang) end)
                            end
                        end)
                    end
                end,
            })
        end,
    },
}
