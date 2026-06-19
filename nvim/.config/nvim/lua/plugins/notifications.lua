vim.pack.add({
    'https://github.com/rcarriga/nvim-notify',
})

local notify = require("notify")

notify.setup({
    stages = "fade_in_slide_out",
    timeout = 3000,
    max_height = function() return math.floor(vim.o.lines * 0.75) end,
    max_width = function() return math.floor(vim.o.columns * 0.75) end,
    background_colour = "Normal",
    minimum_width = 50,
    icons = {
        ERROR = "",
        WARN = "",
        INFO = "",
        DEBUG = "",
        TRACE = "✎",
    },
    render = "default",
    top_down = true,
    fps = 30,
})

vim.notify = notify

vim.keymap.set("n", "<leader>nc", function() notify.dismiss() end, { desc = "Clear notifications" })
