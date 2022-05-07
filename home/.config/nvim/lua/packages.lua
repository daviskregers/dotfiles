local map = vim.api.nvim_set_keymap
local options = { silent = true, noremap = true }

-- NPM Packages

require('package-info').setup({
    colors = {
        up_to_date = "#3C4048", -- Text color for up to date package virtual text
        outdated = "#d19a66", -- Text color for outdated package virtual text
    },
    icons = {
        enable = true, -- Whether to display icons
        style = {
            up_to_date = "|  ", -- Icon for up to date packages
            outdated = "|  ", -- Icon for outdated packages
        },
    },
    autostart = true, -- Whether to autostart when `package.json` is opened
    hide_up_to_date = true, -- It hides up to date versions when displaying virtual text
    hide_unstable_versions = false, -- It hides unstable versions from version list e.g next-11.1.3-canary3
    -- Can be `npm`, `yarn`, or `pnpm`. Used for `delete`, `install` etc...
    -- The plugin will try to auto-detect the package manager based on
    -- `yarn.lock` or `package-lock.json`. If none are found it will use the
    -- provided one, if nothing is provided it will use `yarn`
    -- package_manager = "yarn"
})

-- Show package versions
map("n", "<leader>ns", ":lua require('package-info').show()<CR>", options)

-- Hide package versions
map("n", "<leader>nc", ":lua require('package-info').hide()<CR>", options)

-- Update package on line
map("n", "<leader>nu", ":lua require('package-info').update()<CR>", options)

-- Delete package on line
map("n", "<leader>nd", ":lua require('package-info').delete()<CR>", options)

-- Install a new package
map("n", "<leader>ni", ":lua require('package-info').install()<CR>", options)

-- Reinstall dependencies
map("n", "<leader>nr", ":lua require('package-info').reinstall()<CR>", options)

-- Install a different package version
map("n", "<leader>np", ":lua require('package-info').change_version()<CR>", options)

-- Rust Crates

require('crates').setup {
    smart_insert = true,
    insert_closing_quote = true,
    avoid_prerelease = true,
    autoload = true,
    autoupdate = true,
    loading_indicator = true,
    date_format = "%Y-%m-%d",
    notification_title = "Crates",
    disable_invalid_feature_diagnostic = false,
    text = {
        loading = "   Loading",
        version = "   %s",
        prerelease = "   %s",
        yanked = "   %s",
        nomatch = "   No match",
        upgrade = "   %s",
        error = "   Error fetching crate",
    },
    highlight = {
        loading = "CratesNvimLoading",
        version = "CratesNvimVersion",
        prerelease = "CratesNvimPreRelease",
        yanked = "CratesNvimYanked",
        nomatch = "CratesNvimNoMatch",
        upgrade = "CratesNvimUpgrade",
        error = "CratesNvimError",
    },
    popup = {
        autofocus = false,
        copy_register = '"',
        style = "minimal",
        border = "none",
        show_version_date = false,
        show_dependency_version = true,
        max_height = 30,
        min_width = 20,
        padding = 1,
        text = {
            title = " %s",
            pill_left = "",
            pill_right = "",
            description = "%s",
            created_label = " created        ",
            created = "%s",
            updated_label = " updated        ",
            updated = "%s",
            downloads_label = " downloads      ",
            downloads = "%s",
            homepage_label = " homepage       ",
            homepage = "%s",
            repository_label = " repository     ",
            repository = "%s",
            documentation_label = " documentation  ",
            documentation = "%s",
            crates_io_label = " crates.io      ",
            crates_io = "%s",
            categories_label = " categories     ",
            keywords_label = " keywords       ",
            version = "  %s",
            prerelease = " %s",
            yanked = " %s",
            version_date = "  %s",
            feature = "  %s",
            enabled = " %s",
            transitive = " %s",
            dependency = "  %s",
            optional = " %s",
            dependency_version = "  %s",
            loading = " ",
        },
        highlight = {
            title = "CratesNvimPopupTitle",
            pill_text = "CratesNvimPopupPillText",
            pill_border = "CratesNvimPopupPillBorder",
            description = "CratesNvimPopupDescription",
            created_label = "CratesNvimPopupLabel",
            created = "CratesNvimPopupValue",
            updated_label = "CratesNvimPopupLabel",
            updated = "CratesNvimPopupValue",
            downloads_label = "CratesNvimPopupLabel",
            downloads = "CratesNvimPopupValue",
            homepage_label = "CratesNvimPopupLabel",
            homepage = "CratesNvimPopupUrl",
            repository_label = "CratesNvimPopupLabel",
            repository = "CratesNvimPopupUrl",
            documentation_label = "CratesNvimPopupLabel",
            documentation = "CratesNvimPopupUrl",
            crates_io_label = "CratesNvimPopupLabel",
            crates_io = "CratesNvimPopupUrl",
            categories_label = "CratesNvimPopupLabel",
            keywords_label = "CratesNvimPopupLabel",
            version = "CratesNvimPopupVersion",
            prerelease = "CratesNvimPopupPreRelease",
            yanked = "CratesNvimPopupYanked",
            version_date = "CratesNvimPopupVersionDate",
            feature = "CratesNvimPopupFeature",
            enabled = "CratesNvimPopupEnabled",
            transitive = "CratesNvimPopupTransitive",
            dependency = "CratesNvimPopupDependency",
            optional = "CratesNvimPopupOptional",
            dependency_version = "CratesNvimPopupDependencyVersion",
            loading = "CratesNvimPopupLoading",
        },
        keys = {
            hide = { "q", "<esc>" },
            open_url = { "<cr>" },
            select = { "<cr>" },
            select_alt = { "s" },
            toggle_feature = { "<cr>" },
            copy_value = { "yy" },
            goto_item = { "gd", "K", "<C-LeftMouse>" },
            jump_forward = { "<c-i>" },
            jump_back = { "<c-o>", "<C-RightMouse>" },
        },
    },
    src = {
        insert_closing_quote = true,
        text = {
            prerelease = "  pre-release ",
            yanked = "  yanked ",
        },
        coq = {
            enabled = false,
            name = "Crates",
        },
    },
    null_ls = {
        enabled = true,
        name = "Crates",
    },
}

-- TODO: add mappings. toml only?
-- nnoremap <silent> <leader>ct :lua require('crates').toggle()<cr>
-- nnoremap <silent> <leader>cr :lua require('crates').reload()<cr>
--
-- nnoremap <silent> <leader>cv :lua require('crates').show_versions_popup()<cr>
-- nnoremap <silent> <leader>cf :lua require('crates').show_features_popup()<cr>
--
-- nnoremap <silent> <leader>cu :lua require('crates').update_crate()<cr>
-- vnoremap <silent> <leader>cu :lua require('crates').update_crates()<cr>
-- nnoremap <silent> <leader>ca :lua require('crates').update_all_crates()<cr>
-- nnoremap <silent> <leader>cU :lua require('crates').upgrade_crate()<cr>
-- vnoremap <silent> <leader>cU :lua require('crates').upgrade_crates()<cr>
-- nnoremap <silent> <leader>cA :lua require('crates').upgrade_all_crates()<cr>
--
-- nnoremap <silent> <leader>cH :lua require('crates').open_homepage()<cr>
-- nnoremap <silent> <leader>cR :lua require('crates').open_repository()<cr>
-- nnoremap <silent> <leader>cD :lua require('crates').open_documentation()<cr>
-- nnoremap <silent> <leader>cC :lua require('crates').open_crates_io()<cr>

-- TODO: is there anything for composer, nuget, python, mix?
