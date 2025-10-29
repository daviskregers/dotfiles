-- Tmux integration utilities for Neovim
-- Provides functions to interact with tmux toggle panes

local M = {}

-- Check if we're running inside tmux
function M.is_tmux()
    return vim.env.TMUX ~= nil
end

-- Get current tmux context (session and window numbers)
local function get_tmux_context()
    if not M.is_tmux() then
        return nil
    end

    local session_id = vim.fn.system("tmux display-message -p '#{session_id}'"):gsub("%s+", "")
    local window_id = vim.fn.system("tmux display-message -p '#{window_id}'"):gsub("%s+", "")

    -- Strip special characters ($@%)
    local session_num = session_id:gsub("[%$@%%]", "")
    local window_num = window_id:gsub("[%$@%%]", "")

    return session_num, window_num
end

-- Construct toggle marker name
local function get_toggle_marker(toggle_id)
    local session_num, window_num = get_tmux_context()
    if not session_num or not window_num then
        return nil
    end
    return string.format("toggle_%s_%s_%d", session_num, window_num, toggle_id)
end

-- Check if a toggle pane exists (is visible)
local function toggle_exists(toggle_id)
    if not M.is_tmux() then
        return false
    end

    local marker = get_toggle_marker(toggle_id)
    if not marker then
        return false
    end

    -- Check if any visible pane has this marker
    local panes = vim.fn.system('tmux list-panes -F "#{pane_id}"'):gsub("%s+$", "")
    for pane_id in panes:gmatch("[^\r\n]+") do
        local pane_marker = vim.fn.system(string.format("tmux show-option -pqv -t %s @toggle_marker 2>/dev/null", pane_id)):gsub("%s+", "")
        if pane_marker == marker then
            return true, pane_id
        end
    end

    return false
end

-- Create or show a toggle pane
function M.create_toggle(toggle_id, init_command)
    if not M.is_tmux() then
        print("Not running in tmux - cannot create toggle")
        return false
    end

    local cmd = string.format("tmux-toggle %d", toggle_id)
    if init_command and init_command ~= "" then
        local escaped = init_command:gsub("'", "'\"'\"'")
        cmd = string.format("tmux-toggle %d '%s'", toggle_id, escaped)
    end

    local result = vim.fn.system(cmd)
    if vim.v.shell_error ~= 0 then
        print("Failed to create toggle: " .. result)
        return false
    end

    return true
end

-- Send command to toggle pane (with Enter)
function M.send_to_toggle(toggle_id, command)
    if not M.is_tmux() then
        print("Not running in tmux - cannot send to toggle")
        return false
    end

    -- Escape command for shell
    local escaped = command:gsub("'", "'\"'\"'")
    local cmd = string.format("tmux-send-to-toggle %d '%s'", toggle_id, escaped)

    local result = vim.fn.system(cmd)
    if vim.v.shell_error ~= 0 then
        print("Failed to send command to toggle: " .. result)
        return false
    end

    return true
end

-- Send text to toggle pane without Enter (for AI input)
function M.send_text_to_toggle(toggle_id, text)
    if not M.is_tmux() then
        print("Not running in tmux - cannot send text to toggle")
        return false
    end

    local exists, pane_id = toggle_exists(toggle_id)
    if not exists then
        -- Create the toggle if it doesn't exist
        M.create_toggle(toggle_id)
        -- Wait a bit for it to be created
        vim.fn.system("sleep 0.1")
        exists, pane_id = toggle_exists(toggle_id)
        if not exists then
            print(string.format("Failed to create toggle %d", toggle_id))
            return false
        end
    end

    -- Send text without Enter
    local escaped = text:gsub("'", "'\"'\"'")
    local cmd = string.format("tmux send-keys -t %s '%s'", pane_id, escaped)

    local result = vim.fn.system(cmd)
    if vim.v.shell_error ~= 0 then
        print("Failed to send text to toggle: " .. result)
        return false
    end

    return true
end

-- Convenience wrappers for specific toggles
function M.send_to_ai_pane(command)
    return M.send_to_toggle(3, command)
end

function M.send_text_to_ai_pane(text)
    return M.send_text_to_toggle(3, text)
end

function M.send_to_test_pane(command)
    return M.send_to_toggle(1, command)
end

return M