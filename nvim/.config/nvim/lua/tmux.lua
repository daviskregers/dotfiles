-- Tmux integration utilities for Neovim
-- Provides functions to send commands to specific tmux panes

local M = {}

-- Check if we're running inside tmux
function M.is_tmux()
    return vim.env.TMUX ~= nil
end

-- Send command to tmux pane by pane ID
function M.send_to_pane(pane_id, command)
    if not M.is_tmux() then
        print("Not running in tmux - cannot send to pane")
        return false
    end
    
    local tmux_cmd
    
    if command == "" then
        -- Send just Enter key for empty commands
        tmux_cmd = string.format('tmux send-keys -t %s Enter', pane_id)
    else
        -- Use single quotes to avoid shell interpretation issues
        -- Escape single quotes by ending the quote, adding escaped quote, and starting new quote
        local escaped_command = command:gsub("'", "'\"'\"'")
        
        -- Send command to specific pane using single quotes
        tmux_cmd = string.format("tmux send-keys -t %s '%s' Enter", pane_id, escaped_command)
    end
    
    local result = vim.fn.system(tmux_cmd)
    if vim.v.shell_error ~= 0 then
        print("Failed to send command to tmux pane: " .. result)
        return false
    end
    
    return true
end

-- Send command to AI pane (toggle_ai_tools)
function M.send_to_ai_pane(command)
    local panes = M.list_panes()
    for _, pane in ipairs(panes) do
        if pane.title and pane.title:match("toggle_ai_tools") then
            return M.send_to_pane(pane.id, command)
        end
    end
    print("AI pane (toggle_ai_tools) not found")
    return false
end

-- Send command to Test pane (toggle_zsh_t)
function M.send_to_test_pane(command)
    local panes = M.list_panes()
    for _, pane in ipairs(panes) do
        if pane.title and pane.title:match("toggle_zsh_t") then
            return M.send_to_pane(pane.id, command)
        end
    end
    print("Test pane (toggle_zsh_t) not found")
    return false
end

-- Send text to tmux pane without executing (for AI input)
function M.send_text_to_pane(pane_id, text)
    if not M.is_tmux() then
        print("Not running in tmux - cannot send text to pane")
        return false
    end
    
    -- Use single quotes to avoid shell interpretation issues
    -- Escape single quotes by ending the quote, adding escaped quote, and starting new quote
    local escaped_text = text:gsub("'", "'\"'\"'")
    
    -- Send text to specific pane without Enter
    local tmux_cmd = string.format("tmux send-keys -t %s '%s'", pane_id, escaped_text)
    
    local result = vim.fn.system(tmux_cmd)
    if vim.v.shell_error ~= 0 then
        print("Failed to send text to tmux pane: " .. result)
        return false
    end
    
    return true
end

-- Send text to AI pane (toggle_ai_tools) without executing
function M.send_text_to_ai_pane(text)
    local panes = M.list_panes()
    for _, pane in ipairs(panes) do
        if pane.title and pane.title:match("toggle_ai_tools") then
            return M.send_text_to_pane(pane.id, text)
        end
    end
    print("AI pane (toggle_ai_tools) not found")
    return false
end

-- Check if a tmux pane exists
function M.pane_exists(pane_id)
    if not M.is_tmux() then
        return false
    end
    
    local result = vim.fn.system(string.format('tmux list-panes -t %s 2>/dev/null', pane_id))
    return vim.v.shell_error == 0
end

-- Get list of available tmux panes
function M.list_panes()
    if not M.is_tmux() then
        return {}
    end
    
    local result = vim.fn.system('tmux list-panes -F "#{pane_id}:#{pane_title}"')
    if vim.v.shell_error ~= 0 then
        return {}
    end
    
    local panes = {}
    for line in result:gmatch("[^\r\n]+") do
        local pane_id, title = line:match("([^:]+):(.+)")
        if pane_id and title then
            table.insert(panes, { id = pane_id, title = title })
        end
    end
    
    return panes
end

return M