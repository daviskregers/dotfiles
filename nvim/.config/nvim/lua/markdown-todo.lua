-- Markdown Todo Toggle Plugin
-- Provides interactive todo status management for markdown files

local M = {}

-- Todo states configuration
local TODO_STATES = {
    pending = {
        markdown = "[ ]",
        display = "Pending",
        description = "Task not started"
    },
    in_progress = {
        markdown = "[~]",
        display = "In Progress", 
        description = "Task in progress"
    },
    cancelled = {
        markdown = "[-]",
        display = "Cancelled",
        description = "Task cancelled"
    },
    done = {
        markdown = "[x]",
        display = "Done",
        description = "Task completed"
    }
}

-- Regex patterns for detecting todo items
local TODO_PATTERNS = {
    -- Standard markdown todo patterns
    "%- %[%s*%]%s*",      -- - [ ]
    "%- %[x%]%s*",        -- - [x]
    "%- %[~%]%s*",        -- - [~]
    "%- %[-%]%s*",        -- - [-]
    -- Alternative patterns
    "%* %[%s*%]%s*",      -- * [ ]
    "%* %[x%]%s*",        -- * [x]
    "%* %[~%]%s*",        -- * [~]
    "%* %[-%]%s*",        -- * [-]
}

-- Get current line content
local function get_current_line()
    local line_num = vim.api.nvim_win_get_cursor(0)[1]
    return vim.api.nvim_buf_get_lines(0, line_num - 1, line_num, false)[1] or ""
end

-- Check if current line is a markdown todo item
local function is_todo_line(line)
    if not line then
        line = get_current_line()
    end
    
    for _, pattern in ipairs(TODO_PATTERNS) do
        if line:match(pattern) then
            return true
        end
    end
    return false
end

-- Extract current todo state from line
local function get_current_todo_state(line)
    if not line then
        line = get_current_line()
    end
    
    if line:match("%[%s*%]") then
        return "pending"
    elseif line:match("%[x%]") then
        return "done"
    elseif line:match("%[~%]") then
        return "in_progress"
    elseif line:match("%[-%]") then
        return "cancelled"
    end
    
    return nil
end

-- Generate timestamp string
local function get_timestamp()
    return os.date("!%Y-%m-%dT%H:%M:%SZ")
end

-- Create telescope picker for todo states
local function create_todo_picker()
    local actions = require("telescope.actions")
    local action_state = require("telescope.actions.state")
    local pickers = require("telescope.pickers")
    local finders = require("telescope.finders")
    local conf = require("telescope.config").values
    
    local current_line = get_current_line()
    local current_state = get_current_todo_state(current_line)
    
    -- Build options list
    local options = {}
    for state_key, state_data in pairs(TODO_STATES) do
        local is_current = (state_key == current_state)
        local prefix = is_current and "● " or "  "
        local suffix = is_current and " (current)" or ""
        
        table.insert(options, {
            value = state_key,
            display = prefix .. state_data.display .. suffix,
            description = state_data.description,
            is_current = is_current
        })
    end
    
    -- Sort options to put current state first
    table.sort(options, function(a, b)
        if a.is_current then return true end
        if b.is_current then return false end
        return a.value < b.value
    end)
    
    pickers.new({}, {
        prompt_title = "Select Todo Status",
        finder = finders.new_table({
            results = options,
            entry_maker = function(entry)
                return {
                    value = entry.value,
                    display = entry.display,
                    description = entry.description,
                    ordinal = entry.display,
                }
            end,
        }),
        sorter = conf.generic_sorter({}),
        attach_mappings = function(prompt_bufnr, map)
            actions.select_default:replace(function()
                local selection = action_state.get_selected_entry()
                actions.close(prompt_bufnr)
                
                if selection then
                    M.toggle_todo_status(selection.value)
                end
            end)
            return true
        end,
    }):find()
end

-- Toggle todo status
function M.toggle_todo_status(new_state)
    local line_num = vim.api.nvim_win_get_cursor(0)[1]
    local current_line = get_current_line()
    
    if not is_todo_line(current_line) then
        vim.notify("Current line is not a markdown todo item", vim.log.levels.WARN)
        return
    end
    
    local state_data = TODO_STATES[new_state]
    if not state_data then
        vim.notify("Invalid todo state: " .. tostring(new_state), vim.log.levels.ERROR)
        return
    end
    
    -- Replace the todo checkbox
    local new_line = current_line:gsub("%[[%sx~%-]%]", state_data.markdown)
    
    -- Add timestamp for non-pending states
    if new_state ~= "pending" then
        local timestamp = get_timestamp()
        -- Check if timestamp already exists and remove it
        new_line = new_line:gsub("%s*@%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%dZ", "")
        -- Add new timestamp
        new_line = new_line .. " @" .. timestamp
    else
        -- Remove timestamp when going back to pending
        new_line = new_line:gsub("%s*@%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%dZ", "")
    end
    
    -- Update the line
    vim.api.nvim_buf_set_lines(0, line_num - 1, line_num, false, { new_line })
    
    -- Show notification
    vim.notify("Todo status changed to: " .. state_data.display, vim.log.levels.INFO)
end

-- Main function to toggle todo
function M.toggle_todo()
    if vim.bo.filetype ~= "markdown" then
        vim.notify("This command only works in markdown files", vim.log.levels.WARN)
        return
    end
    
    local current_line = get_current_line()
    
    if not is_todo_line(current_line) then
        vim.notify("Current line is not a markdown todo item", vim.log.levels.WARN)
        return
    end
    
    create_todo_picker()
end

-- Setup function
function M.setup()
    -- Keymap for markdown files only
    vim.api.nvim_create_autocmd("FileType", {
        pattern = "markdown",
        callback = function()
            vim.keymap.set("n", "<leader>t", M.toggle_todo, {
                desc = "Toggle markdown todo status",
                buffer = true
            })
        end
    })
end

-- Initialize the plugin
M.setup()

return M