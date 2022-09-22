function PHPUNIT_COMMAND()
    print('RUNNING ', vim.g.PHPUNIT_CMD)
    return vim.g.PHPUNIT_CMD
end

require("neotest").setup({
    default_strategy = "integrated",
    diagnostic = {
        enabled = true
    },
    discovery = {
        enabled = true
    },
    floating = {
        border = "rounded",
        max_height = 0.6,
        max_width = 0.6,
        options = {}
    },
    highlights = {
        adapter_name = "NeotestAdapterName",
        border = "NeotestBorder",
        dir = "NeotestDir",
        expand_marker = "NeotestExpandMarker",
        failed = "NeotestFailed",
        file = "NeotestFile",
        focused = "NeotestFocused",
        indent = "NeotestIndent",
        marked = "NeotestMarked",
        namespace = "NeotestNamespace",
        passed = "NeotestPassed",
        running = "NeotestRunning",
        select_win = "NeotestWinSelect",
        skipped = "NeotestSkipped",
        target = "NeotestTarget",
        test = "NeotestTest",
        unknown = "NeotestUnknown"
    },
    icons = {
        child_indent = "│",
        child_prefix = "├",
        collapsed = "─",
        expanded = "╮",
        failed = "✖",
        final_child_indent = " ",
        final_child_prefix = "╰",
        non_collapsible = "─",
        passed = "✔",
        running = "🗘",
        skipped = "ﰸ",
        unknown = "?"
    },
    jump = {
        enabled = true
    },
    output = {
        enabled = true,
        open_on_run = "short"
    },
    run = {
        enabled = true
    },
    status = {
        enabled = true,
        signs = true,
        virtual_text = false
    },
    strategies = {
        integrated = {
            height = 40,
            width = 120
        }
    },
    summary = {
        enabled = true,
        expand_errors = true,
        follow = true,
        mappings = {
            attach = "a",
            clear_marked = "M",
            clear_target = "T",
            expand = { "<CR>", "<2-LeftMouse>" },
            expand_all = "e",
            jumpto = "i",
            mark = "m",
            output = "o",
            run = "r",
            run_marked = "R",
            short = "O",
            stop = "u",
            target = "t"
        }
    },
    adapters = {
        require("neotest-jest"),
        require("neotest-plenary"),
        require("neotest-rust"),
        require("neotest-phpunit") {
            phpunit_cmd = PHPUNIT_COMMAND,
            use_relative_path = true,
            output_dir = ".tmp/",
        },
        require("neotest-python"),
    }
})
