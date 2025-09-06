-- Notification system using nvim-notify
-- Provides beautiful, non-blocking notifications in the top-right corner

return {
    {
        "rcarriga/nvim-notify",
        priority = 1000, -- Load before other plugins that might use notifications
        config = function()
            local notify = require("notify")
            
            -- Configure notification settings
            notify.setup({
                -- Animation style
                stages = "fade_in_slide_out",
                
                -- Timeout for notifications (in milliseconds)
                timeout = 3000,
                
                -- Maximum number of notifications to show
                max_height = function()
                    return math.floor(vim.o.lines * 0.75)
                end,
                max_width = function()
                    return math.floor(vim.o.columns * 0.75)
                end,
                
                -- Background color
                background_colour = "Normal",
                
                -- Minimum width for notifications
                minimum_width = 50,
                
                -- Icons for different log levels
                icons = {
                    ERROR = "",
                    WARN = "",
                    INFO = "",
                    DEBUG = "",
                    TRACE = "✎",
                },
                
                -- Render function for custom styling
                render = "default",
                
                -- Top-down or bottom-up
                top_down = false,
                
                -- FPS for animations
                fps = 30,
                
                -- Function to run when notification is dismissed
                on_open = nil,
                on_close = nil,
                
                -- Function to run when notification is dismissed
                on_dismiss = nil,
            })
            
            -- Override vim.notify to use nvim-notify
            vim.notify = notify
            
            -- Set up some custom notification functions
            local function notify_config_change(message)
                notify(message, "info", {
                    title = "Config Change Detected",
                    timeout = 2000,
                    render = "compact",
                })
            end
            
            local function notify_config_loaded(message)
                notify(message, "info", {
                    title = "Config Loaded",
                    timeout = 1500,
                    render = "compact",
                })
            end
            
            -- Make these functions globally available
            _G.notify_config_change = notify_config_change
            _G.notify_config_loaded = notify_config_loaded
            
            -- Keymap to test notifications (optional)
            vim.keymap.set("n", "<leader>nn", function()
                notify("This is a test notification!", "info", {
                    title = "Test Notification",
                    timeout = 2000,
                })
            end, { desc = "Test notification" })
            
            -- Keymap to clear all notifications
            vim.keymap.set("n", "<leader>nc", function()
                notify.dismiss()
            end, { desc = "Clear notifications" })
        end
    }
}