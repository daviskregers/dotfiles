return {
    {
        "ai-terminal",
        dir = vim.fn.stdpath("config"),
        name = "ai-terminal",
        config = function()
            -- Import tmux utilities
            local tmux = require("tmux")
            
            -- Constants
            local CONSTANTS = {
                MULTILINE_INPUT_WIDTH = 80,
                MULTILINE_INPUT_HEIGHT = 20,
                MULTILINE_INPUT_PADDING = 10,
                CACHE_TTL_SECONDS = 5,
                INSTRUCTION_LINES_COUNT = 3,
                MUTEX_TIMEOUT_MS = 100
            }
            
            -- Centralized error handling
            local function handle_error(message, level)
                level = level or vim.log.levels.ERROR
                vim.notify(message, level)
            end
            
            -- Utility function to escape terminal input
            local function escape_terminal_input(input)
                if not input or type(input) ~= "string" then
                    return ""
                end

                -- Remove control characters except newlines and tabs
                input = input:gsub("[\1-\8\11-\12\14-\31\127]", "")

                -- Escape terminal escape sequences
                input = input:gsub("\27", "") -- Remove ESC character
                
                -- Escape shell metacharacters to prevent command injection
                input = input:gsub("([%$`%\\])", "\\%1") -- Escape $, `, \
                input = input:gsub("([\"'])", "\\%1") -- Escape quotes
                input = input:gsub("([;&|])", "\\%1") -- Escape command separators

                return input
            end

            -- State management for AI clients (now using tmux)
            local ai_state = {
                claude = {
                    active = false,
                },
                opencode = {
                    active = false,
                },
                cursor_agent = {
                    active = false,
                },
                active_client = "claude", -- Track which client is currently active
            }

            -- Check if tmux AI pane is available
            local function check_ai_pane()
                if not tmux.is_tmux() then
                    handle_error("Not running in tmux - AI functionality requires tmux", vim.log.levels.WARN)
                    return false
                end
                
                -- Find AI pane by title instead of hardcoded ID
                local panes = tmux.list_panes()
                local ai_pane_id = nil
                for _, pane in ipairs(panes) do
                    if pane.title and pane.title:match("toggle_ai_tools") then
                        ai_pane_id = pane.id
                        break
                    end
                end
                
                if not ai_pane_id then
                    handle_error("AI pane (toggle_ai_tools) not found - please create it first", vim.log.levels.WARN)
                    return false
                end
                
                return true, ai_pane_id
            end

            -- Generic function to activate AI client (now using tmux)
            local function activate_ai_client(client_name, command)
                if not check_ai_pane() then
                    return
                end
                
                local client = ai_state[client_name]
                
                if not client.active then
                    -- Activate client
                    ai_state[client_name].active = true
                    ai_state.active_client = client_name
                    
                    -- Send command to tmux pane if provided
                    if command then
                        tmux.send_to_ai_pane(command)
                    end
                    
                    vim.notify("Activated " .. client_name .. " AI client (using tmux ALT+A pane)", vim.log.levels.INFO)
                else
                    -- Deactivate client
                    ai_state[client_name].active = false
                    vim.notify("Deactivated " .. client_name .. " AI client", vim.log.levels.INFO)
                end
            end

            local function cleanup_ai_clients()
                for name, client in pairs(ai_state) do
                    if type(client) == "table" and client.active then
                        client.active = false
                    end
                end
                vim.notify("Deactivated all AI clients", vim.log.levels.INFO)
            end

            -- Auto-cleanup on Neovim exit
            vim.api.nvim_create_autocmd("VimLeavePre", {
                desc = "Clean up AI clients on exit",
                callback = cleanup_ai_clients
            })

            -- Toggle Claude AI client
            local function toggle_claude_terminal()
                activate_ai_client("claude", "claude")
            end

            -- Toggle OpenCode AI client
            local function toggle_opencode_terminal()
                activate_ai_client("opencode", nil)
            end

            -- Toggle Cursor Agent AI client
            local function toggle_cursor_agent_terminal()
                activate_ai_client("cursor_agent", "cursor-agent")
            end

            -- Multiline Input Function
            local function multiline_input(opts, callback)
                opts = opts or {}
                local prompt = opts.prompt or "Enter text:"
                local default = opts.default or ""

                -- Create a floating window for multiline input
                local buf = vim.api.nvim_create_buf(false, true)
                local width = math.min(CONSTANTS.MULTILINE_INPUT_WIDTH, vim.o.columns - CONSTANTS.MULTILINE_INPUT_PADDING)
                local height = math.min(CONSTANTS.MULTILINE_INPUT_HEIGHT, vim.o.lines - CONSTANTS.MULTILINE_INPUT_PADDING)
                local row = math.floor((vim.o.lines - height) / 2)
                local col = math.floor((vim.o.columns - width) / 2)

                local win = vim.api.nvim_open_win(buf, true, {
                    relative = "editor",
                    width = width,
                    height = height,
                    row = row,
                    col = col,
                    border = "rounded",
                    title = " " .. prompt .. " ",
                    title_pos = "center",
                })

                -- Set buffer options
                vim.bo[buf].buftype = "nofile"
                vim.bo[buf].filetype = "markdown" -- For syntax highlighting

                -- Add instructions and default content
                local instructions = {
                    "-- " .. prompt,
                    "-- Press Ctrl+S to submit, Ctrl+C or Esc to cancel",
                    "",
                }

                if default ~= "" then
                    local default_lines = vim.split(default, "\n")
                    for _, line in ipairs(default_lines) do
                        table.insert(instructions, line)
                    end
                else
                    table.insert(instructions, "")
                end

                vim.api.nvim_buf_set_lines(buf, 0, -1, false, instructions)

                -- Position cursor after instructions
                vim.api.nvim_win_set_cursor(win, { #instructions, 0 })

                -- Cleanup function to ensure resources are freed
                local function cleanup()
                    pcall(function()
                        if vim.api.nvim_win_is_valid(win) then
                            vim.api.nvim_win_close(win, true)
                        end
                    end)
                    pcall(function()
                        if vim.api.nvim_buf_is_valid(buf) then
                            vim.api.nvim_buf_delete(buf, { force = true })
                        end
                    end)
                end

                -- Set up keymaps for the input window
                local function submit()
                    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

                    -- Remove instruction lines (first N lines)
                    local content_lines = {}
                    for i = CONSTANTS.INSTRUCTION_LINES_COUNT + 1, #lines do
                        table.insert(content_lines, lines[i])
                    end

                    -- Remove trailing empty lines
                    while #content_lines > 0 and content_lines[#content_lines] == "" do
                        table.remove(content_lines)
                    end

                    local content = table.concat(content_lines, "\n")

                    -- Cleanup resources
                    cleanup()

                    -- Call callback with content
                    if content ~= "" then
                        callback(content)
                    else
                        callback(nil)
                    end
                end

                local function cancel()
                    -- Cleanup resources
                    cleanup()
                    callback(nil)
                end

                -- Set up key mappings for the input buffer
                vim.keymap.set({ "n", "i" }, "<C-s>", submit, { buffer = buf, nowait = true })
                vim.keymap.set({ "n", "i" }, "<C-c>", cancel, { buffer = buf, nowait = true })
                vim.keymap.set("n", "<Esc>", cancel, { buffer = buf, nowait = true })

                -- Ensure cleanup on buffer deletion
                vim.api.nvim_create_autocmd("BufDelete", {
                    buffer = buf,
                    once = true,
                    callback = cleanup
                })

                -- Start in insert mode at the end of the buffer
                vim.cmd("startinsert")
            end

            -- Shared function to get selected text and format message
            local function get_selected_text_and_format_message(prompt_suffix, auto_submit)
                -- Ensure tmux pane exists
                if not check_ai_pane() then
                    return
                end
                
                -- Auto-activate default client if none is active
                local active = ai_state.active_client
                local client = ai_state[active]
                if not client.active then
                    client.active = true
                    vim.notify("Auto-activated " .. active .. " AI client", vim.log.levels.INFO)
                end

                -- Get selected text
                local start_pos = vim.fn.getpos("'<")
                local end_pos = vim.fn.getpos("'>")

                if start_pos[2] == 0 or end_pos[2] == 0 then
                    handle_error("No text selected. Please select code first.", vim.log.levels.WARN)
                    return
                end

                local lines = vim.fn.getline(start_pos[2], end_pos[2])
                if type(lines) == "string" then
                    lines = { lines }
                end

                -- Handle partial line selections
                if #lines > 0 then
                    if #lines == 1 then
                        -- Single line selection - ensure positions are within bounds
                        local line_len = #lines[1]
                        local start_col = math.max(1, math.min(start_pos[3], line_len))
                        local end_col = math.max(start_col, math.min(end_pos[3], line_len))
                        lines[1] = string.sub(lines[1], start_col, end_col)
                    else
                        -- Multi-line selection - ensure positions are within bounds
                        local first_line_len = #lines[1]
                        local last_line_len = #lines[#lines]
                        local start_col = math.max(1, math.min(start_pos[3], first_line_len))
                        local end_col = math.max(1, math.min(end_pos[3], last_line_len))
                        lines[1] = string.sub(lines[1], start_col)
                        lines[#lines] = string.sub(lines[#lines], 1, end_col)
                    end
                end

                local selected_code = table.concat(lines, "\n")

                -- Get user prompt with multiline input
                multiline_input({
                    prompt = "Enter prompt for " .. active .. prompt_suffix,
                    default = "",
                }, function(prompt)
                    if not prompt or prompt == "" then
                        return
                    end

                    -- Format the message to send to AI terminal
                    local file_path = vim.fn.expand('%:.') -- Relative path from current working directory
                    local start_line = start_pos[2]
                    local end_line = end_pos[2]

                    local location_info
                    if start_line == end_line then
                        location_info = string.format("From %s:%d", file_path, start_line)
                    else
                        location_info = string.format("From %s:%d-%d", file_path, start_line, end_line)
                    end

                    local message_format = auto_submit and "%s\n\n```%s\n%s\n```\n\n%s" or "%s\n\n```%s\n%s\n```\n\n%s\n\n"
                    local message = string.format(message_format, location_info, vim.bo.filetype, selected_code, prompt)

                    -- Send message to tmux AI pane
                    if auto_submit then
                        if active == "claude" then
                            -- For claude-code, send the message then submit
                            tmux.send_text_to_ai_pane(escape_terminal_input(message))
                            tmux.send_to_ai_pane("") -- Send Enter to submit
                        else
                            -- For other terminals, send the formatted message and submit
                            tmux.send_to_ai_pane(escape_terminal_input(message))
                        end
                        vim.notify("Code sent to " .. active .. " AI client (tmux ALT+A pane)", vim.log.levels.INFO)
                    else
                        -- Send message to tmux AI pane without submitting
                        tmux.send_text_to_ai_pane(escape_terminal_input(message))
                        vim.notify("Code added to " .. active .. " AI client (tmux ALT+A pane, not submitted)", vim.log.levels.INFO)
                    end
                end)
            end

            -- Get selected text and prompt for input
            local function send_code_to_ai()
                get_selected_text_and_format_message(": ", true)
            end

            -- Send current file context to AI (normal mode)
            local function send_file_to_ai()
                -- Ensure tmux pane exists
                if not check_ai_pane() then
                    return
                end
                
                -- Auto-activate default client if none is active
                local active = ai_state.active_client
                local client = ai_state[active]
                if not client.active then
                    client.active = true
                    vim.notify("Auto-activated " .. active .. " AI client", vim.log.levels.INFO)
                end

                -- Get user prompt with multiline input
                multiline_input({
                    prompt = "Enter prompt for " .. active .. " (file context): ",
                    default = "",
                }, function(prompt)
                    if not prompt or prompt == "" then
                        return
                    end

                    -- Format the message to send to AI terminal
                    local file_path = vim.fn.expand('%:.') -- Relative path from current working directory
                    local message = string.format("Working with file: %s\n\n%s", file_path, prompt)

                    -- Send message to tmux AI pane
                    if active == "claude" then
                        -- For claude-code, send the message then submit
                        tmux.send_text_to_ai_pane(escape_terminal_input(message))
                        tmux.send_to_ai_pane("") -- Send Enter to submit
                    else
                        -- For other terminals, send the formatted message and submit
                        tmux.send_to_ai_pane(escape_terminal_input(message))
                    end

                    vim.notify("File context sent to " .. active .. " AI client (tmux ALT+A pane)", vim.log.levels.INFO)
                end)
            end

            -- Send current file context to AI without auto-submit (normal mode)
            local function send_file_to_ai_no_submit()
                -- Ensure tmux pane exists
                if not check_ai_pane() then
                    return
                end
                
                -- Auto-activate default client if none is active
                local active = ai_state.active_client
                local client = ai_state[active]
                if not client.active then
                    client.active = true
                    vim.notify("Auto-activated " .. active .. " AI client", vim.log.levels.INFO)
                end

                -- Get user prompt with multiline input
                multiline_input({
                    prompt = "Enter prompt for " .. active .. " (file context, no auto-submit): ",
                    default = "",
                }, function(prompt)
                    if not prompt or prompt == "" then
                        return
                    end

                    -- Format the message to send to AI terminal
                    local file_path = vim.fn.expand('%:.') -- Relative path from current working directory
                    local message = string.format("Working with file: %s\n\n%s\n\n", file_path, prompt)

                    -- Send message to tmux AI pane without submitting
                    tmux.send_text_to_ai_pane(escape_terminal_input(message))

                    vim.notify("Message added to " .. active .. " AI client (tmux ALT+A pane, not submitted)", vim.log.levels.INFO)
                end)
            end

            -- Send selected code to AI without auto-submit (visual mode)
            local function send_code_to_ai_no_submit()
                get_selected_text_and_format_message(" (no auto-submit): ", false)
                -- Clear visual selection by pressing escape
                vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)
            end

            -- AI Snippet System
            local snippet_cache = {
                global_snippets = {},
                file_mtimes = {},
                last_check_time = 0,
                loading = false -- Simple mutex to prevent concurrent access
            }

            -- Utility function to sanitize file paths
            local function sanitize_file_path(path, base_dir)
                if not path or type(path) ~= "string" then
                    return nil
                end

                -- Remove any null bytes
                path = path:gsub("%z", "")

                -- Normalize path separators
                path = path:gsub("\\", "/")

                -- Remove any path traversal attempts (more comprehensive)
                path = path:gsub("%.%./", "") -- Remove ../
                path = path:gsub("%.%./", "") -- Remove remaining ../
                path = path:gsub("%.%.", "") -- Remove ..
                path = path:gsub("%.%.", "") -- Remove remaining ..
                path = path:gsub("//+", "/") -- Normalize multiple slashes

                -- Ensure the path doesn't start with /
                if path:match("^/") then
                    return nil
                end

                -- Build full path
                local full_path = base_dir .. "/" .. path

                -- Resolve to absolute path and ensure it's within base directory
                local resolved_path = vim.fn.resolve(full_path)
                local resolved_base = vim.fn.resolve(base_dir)

                -- Check if the resolved path starts with the resolved base directory
                if not resolved_path:find("^" .. vim.pesc(resolved_base)) then
                    return nil
                end

                return resolved_path
            end

            local function parse_snippet_file(filepath)
                local snippets = {}
                
                -- Validate file path before opening
                if not filepath or type(filepath) ~= "string" or filepath == "" then
                    vim.notify("Invalid file path provided", vim.log.levels.ERROR)
                    return snippets
                end
                
                -- Check if file exists and is readable
                local stat = vim.loop.fs_stat(filepath)
                if not stat or stat.type ~= "file" then
                    vim.notify("File does not exist or is not a regular file: " .. filepath, vim.log.levels.WARN)
                    return snippets
                end
                
                local file, err = io.open(filepath, "r")
                if not file then
                    if err then
                        vim.notify("Failed to open snippet file " .. filepath .. ": " .. err, vim.log.levels.WARN)
                    end
                    return snippets
                end

                local current_snippet = nil
                local current_content = {}

                local success, result = pcall(function()
                    for line in file:lines() do
                        if line:match("^#%s+(.+)") then
                            -- Save previous snippet if it exists
                            if current_snippet then
                                local content = table.concat(current_content, "\n")
                                -- Single pass trim: remove leading and trailing whitespace
                                snippets[current_snippet] = content:match("^%s*(.-)%s*$") or content
                            end

                            -- Start new snippet
                            current_snippet = line:match("^#%s+(.+)")
                            current_content = {}
                        elseif current_snippet then
                            -- Add line to current snippet content
                            table.insert(current_content, line)
                        end
                    end

                    -- Save the last snippet
                    if current_snippet then
                        local content = table.concat(current_content, "\n")
                        -- Single pass trim: remove leading and trailing whitespace
                        snippets[current_snippet] = content:match("^%s*(.-)%s*$") or content
                    end
                end)

                file:close()

                if not success then
                    vim.notify("Error parsing snippet file " .. filepath .. ": " .. tostring(result),
                        vim.log.levels.ERROR)
                end

                return snippets
            end

            local function load_global_snippets()
                local current_time = vim.loop.hrtime()
                local cache_ttl = CONSTANTS.CACHE_TTL_SECONDS * 1e9 -- Convert seconds to nanoseconds

                -- Check if cache is still valid (not older than TTL)
                if current_time - snippet_cache.last_check_time < cache_ttl then
                    return snippet_cache.global_snippets
                end
                
                -- Prevent concurrent access
                if snippet_cache.loading then
                    -- Wait a bit and return cached version if still loading
                    vim.defer_fn(function()
                        if snippet_cache.loading then
                            snippet_cache.loading = false
                        end
                    end, CONSTANTS.MUTEX_TIMEOUT_MS)
                    return snippet_cache.global_snippets
                end
                
                snippet_cache.loading = true

                local snippets = {}
                local ai_snippets_dir = vim.fn.stdpath("config") .. "/ai-snippets"
                local needs_update = false

                -- Get all .txt files in the ai-snippets directory
                local files = vim.fn.glob(ai_snippets_dir .. "/*.txt", false, true)

                -- Cache file stats to avoid redundant calls
                local file_stats = {}
                for _, filepath in ipairs(files) do
                    file_stats[filepath] = vim.loop.fs_stat(filepath)
                end
                
                for _, filepath in ipairs(files) do
                    local stat = file_stats[filepath]
                    local cached_mtime = snippet_cache.file_mtimes[filepath]

                    -- Check if file was modified since last cache
                    if not stat or not cached_mtime or stat.mtime.sec ~= cached_mtime then
                        needs_update = true
                        if stat then
                            snippet_cache.file_mtimes[filepath] = stat.mtime.sec
                        end

                        local file_snippets = parse_snippet_file(filepath)
                        local category = vim.fn.fnamemodify(filepath, ":t:r") -- Get filename without extension

                        for name, content in pairs(file_snippets) do
                            snippets[name] = {
                                content = content,
                                category = category,
                                display_name = string.format("[%s] %s", category, name)
                            }
                        end
                    end
                end

                -- If any files were updated, rebuild cache; otherwise return cached version
                if needs_update then
                    -- The snippets table already contains all the loaded snippets from the first loop
                    -- Just update the cache
                    snippet_cache.global_snippets = snippets
                    snippet_cache.last_check_time = current_time
                else
                    snippets = snippet_cache.global_snippets
                end
                
                -- Release the mutex
                snippet_cache.loading = false

                return snippets
            end

            local function load_project_snippets()
                local snippets = {}

                -- Check if AI_SNIPPETS is defined in the global scope (from .nvim.lua)
                if _G.AI_SNIPPETS and type(_G.AI_SNIPPETS) == "table" then
                    for name, content in pairs(_G.AI_SNIPPETS) do
                        snippets[name] = {
                            content = content,
                            category = "project",
                            display_name = string.format("[project] %s", name)
                        }
                    end
                end

                return snippets
            end

            local function load_all_snippets()
                local snippets = {}

                -- Load global snippets
                local global_snippets = load_global_snippets()
                local global_count = 0
                for name, snippet_data in pairs(global_snippets) do
                    snippets[name] = snippet_data
                    global_count = global_count + 1
                end

                -- Load project snippets (they take precedence for same names)
                local project_snippets = load_project_snippets()
                local project_count = 0
                for name, snippet_data in pairs(project_snippets) do
                    snippets[name] = snippet_data
                    project_count = project_count + 1
                end


                return snippets
            end

            -- Get snippet names for autocompletion
            local function get_snippet_names()
                local snippets = load_all_snippets()
                local names = {}
                for name, _ in pairs(snippets) do
                    table.insert(names, name)
                end
                table.sort(names)
                return names
            end

            -- Process placeholders in snippet content
            local function process_placeholders(content, context)
                context = context or {}

                -- Get current file information
                local filepath = vim.fn.expand('%:.')
                local filename = vim.fn.expand('%:t')
                local filetype = vim.bo.filetype

                -- Replace placeholders
                content = content:gsub("{{filepath}}", filepath)
                content = content:gsub("{{filename}}", filename)
                content = content:gsub("{{filetype}}", filetype)

                -- Handle selection-based placeholders
                if context.selection then
                    content = content:gsub("{{selection}}", context.selection)

                    if context.location then
                        content = content:gsub("{{location}}", context.location)
                    end
                else
                    -- Remove selection placeholders if no selection
                    content = content:gsub("{{selection}}", "")
                    content = content:gsub("{{location}}", filepath)
                end

                return content
            end

            -- Insert snippet into AI terminal
            local function insert_ai_snippet(snippet_name, context)
                -- Ensure tmux pane exists
                if not check_ai_pane() then
                    return
                end
                
                -- Auto-activate default client if none is active
                local active = ai_state.active_client
                local client = ai_state[active]
                if not client.active then
                    client.active = true
                    vim.notify("Auto-activated " .. active .. " AI client", vim.log.levels.INFO)
                end

                local snippets = load_all_snippets()
                local snippet_data = snippets[snippet_name]

                if not snippet_data then
                    handle_error("Snippet '" .. snippet_name .. "' not found", vim.log.levels.WARN)
                    return
                end

                local content = process_placeholders(snippet_data.content, context)

                -- Send snippet content to tmux AI pane without submitting
                tmux.send_text_to_ai_pane(escape_terminal_input(content))

                vim.notify("Snippet '" .. snippet_name .. "' added to " .. active .. " AI client (tmux ALT+A pane, not submitted)", vim.log.levels.INFO)
            end

            -- Insert snippet into AI terminal with auto-submit
            local function insert_ai_snippet_auto_submit(snippet_name, context)
                -- Ensure tmux pane exists
                if not check_ai_pane() then
                    return
                end
                
                -- Auto-activate default client if none is active
                local active = ai_state.active_client
                local client = ai_state[active]
                if not client.active then
                    client.active = true
                    vim.notify("Auto-activated " .. active .. " AI client", vim.log.levels.INFO)
                end

                local snippets = load_all_snippets()
                local snippet_data = snippets[snippet_name]

                if not snippet_data then
                    handle_error("Snippet '" .. snippet_name .. "' not found", vim.log.levels.WARN)
                    return
                end

                local content = process_placeholders(snippet_data.content, context)

                -- Send snippet content to tmux AI pane and auto-submit
                tmux.send_text_to_ai_pane(escape_terminal_input(content))
                tmux.send_to_ai_pane("") -- Send Enter to submit

                vim.notify("Snippet '" .. snippet_name .. "' sent to " .. active .. " AI client (tmux ALT+A pane, auto-submitted)", vim.log.levels.INFO)
            end

            -- Get current context for placeholders
            local function get_current_context()
                local context = {}

                -- Check if there's a visual selection
                local start_pos = vim.fn.getpos("'<")
                local end_pos = vim.fn.getpos("'>")

                if start_pos[2] ~= 0 and end_pos[2] ~= 0 and
                    (start_pos[2] ~= end_pos[2] or start_pos[3] ~= end_pos[3]) then
                    local lines = vim.fn.getline(start_pos[2], end_pos[2])
                    if type(lines) == "string" then
                        lines = { lines }
                    end

                    -- Handle partial line selections
                    if #lines > 0 then
                        if #lines == 1 then
                            -- Single line selection - ensure positions are within bounds
                            local line_len = #lines[1]
                            local start_col = math.max(1, math.min(start_pos[3], line_len))
                            local end_col = math.max(start_col, math.min(end_pos[3], line_len))
                            lines[1] = string.sub(lines[1], start_col, end_col)
                        else
                            -- Multi-line selection - ensure positions are within bounds
                            local first_line_len = #lines[1]
                            local last_line_len = #lines[#lines]
                            local start_col = math.max(1, math.min(start_pos[3], first_line_len))
                            local end_col = math.max(1, math.min(end_pos[3], last_line_len))
                            lines[1] = string.sub(lines[1], start_col)
                            lines[#lines] = string.sub(lines[#lines], 1, end_col)
                        end
                    end

                    context.selection = table.concat(lines, "\n")

                    -- Create location info
                    local file_path = vim.fn.expand('%:.')
                    local start_line = start_pos[2]
                    local end_line = end_pos[2]

                    if start_line == end_line then
                        context.location = string.format("From %s:%d", file_path, start_line)
                    else
                        context.location = string.format("From %s:%d-%d", file_path, start_line, end_line)
                    end
                end

                return context
            end

            -- Telescope picker for snippets
            local function open_snippet_picker()
                local pickers = require "telescope.pickers"
                local finders = require "telescope.finders"
                local conf = require "telescope.config".values
                local actions = require "telescope.actions"
                local action_state = require "telescope.actions.state"
                local themes = require "telescope.themes"

                local snippets = load_all_snippets()
                local snippet_list = {}

                for name, snippet_data in pairs(snippets) do
                    table.insert(snippet_list, {
                        name = name,
                        display_name = snippet_data.display_name,
                        content = snippet_data.content,
                        category = snippet_data.category
                    })
                end

                -- Sort by display name
                table.sort(snippet_list, function(a, b)
                    return a.display_name < b.display_name
                end)

                pickers.new(themes.get_ivy({
                    prompt_title = "AI Snippets",
                    finder = finders.new_table({
                        results = snippet_list,
                        entry_maker = function(entry)
                            return {
                                value = entry,
                                display = entry.display_name,
                                ordinal = entry.display_name,
                            }
                        end,
                    }),
                    sorter = conf.generic_sorter({}),
                    previewer = require("telescope.previewers").new_buffer_previewer({
                        title = "Snippet Content",
                        define_preview = function(self, entry, status)
                            vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false,
                                vim.split(entry.value.content, "\n"))
                            vim.api.nvim_buf_set_option(self.state.bufnr, "filetype", "markdown")
                        end
                    }),
                    attach_mappings = function(prompt_bufnr, map)
                        actions.select_default:replace(function()
                            actions.close(prompt_bufnr)
                            local selection = action_state.get_selected_entry()
                            if selection then
                                -- Try to get current selection context for placeholders
                                local context = get_current_context()
                                insert_ai_snippet(selection.value.name, context)
                            end
                        end)
                        return true
                    end,
                })):find()
            end

            -- Telescope picker for snippets with auto-submit
            local function open_snippet_picker_auto_submit()
                local pickers = require "telescope.pickers"
                local finders = require "telescope.finders"
                local conf = require "telescope.config".values
                local actions = require "telescope.actions"
                local action_state = require "telescope.actions.state"
                local themes = require "telescope.themes"

                local snippets = load_all_snippets()
                local snippet_list = {}

                for name, snippet_data in pairs(snippets) do
                    table.insert(snippet_list, {
                        name = name,
                        display_name = snippet_data.display_name,
                        content = snippet_data.content,
                        category = snippet_data.category
                    })
                end

                -- Sort by display name
                table.sort(snippet_list, function(a, b)
                    return a.display_name < b.display_name
                end)

                pickers.new(themes.get_ivy({
                    prompt_title = "AI Snippets (Auto-Submit)",
                    finder = finders.new_table({
                        results = snippet_list,
                        entry_maker = function(entry)
                            return {
                                value = entry,
                                display = entry.display_name,
                                ordinal = entry.display_name,
                            }
                        end,
                    }),
                    sorter = conf.generic_sorter({}),
                    previewer = require("telescope.previewers").new_buffer_previewer({
                        title = "Snippet Content",
                        define_preview = function(self, entry, status)
                            vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false,
                                vim.split(entry.value.content, "\n"))
                            vim.api.nvim_buf_set_option(self.state.bufnr, "filetype", "markdown")
                        end
                    }),
                    attach_mappings = function(prompt_bufnr, map)
                        actions.select_default:replace(function()
                            actions.close(prompt_bufnr)
                            local selection = action_state.get_selected_entry()
                            if selection then
                                -- Try to get current selection context for placeholders
                                local context = get_current_context()
                                insert_ai_snippet_auto_submit(selection.value.name, context)
                            end
                        end)
                        return true
                    end,
                })):find()
            end

            -- AI Snippet command function that handles both direct snippet name and picker
            local function ai_snippet_command(opts)
                local snippet_name = opts.args

                if snippet_name and snippet_name ~= "" then
                    -- Direct snippet insertion with context
                    local context = get_current_context()
                    insert_ai_snippet(snippet_name, context)
                else
                    -- Open telescope picker
                    open_snippet_picker()
                end
            end

            -- Helper function to get available categories
            local function get_available_categories()
                local ai_snippets_dir = vim.fn.stdpath("config") .. "/ai-snippets"
                local files = vim.fn.glob(ai_snippets_dir .. "/*.txt", false, true)
                local categories = {}

                for _, filepath in ipairs(files) do
                    local category = vim.fn.fnamemodify(filepath, ":t:r")
                    table.insert(categories, category)
                end

                -- Add option to create new category
                table.insert(categories, "[Create new category]")
                return categories
            end

            -- Helper function to sanitize category name
            local function sanitize_category_name(name)
                if not name or name == "" then
                    return nil
                end
                local sanitized = name:gsub("[^%w%-_]", ""):gsub("^%s+", ""):gsub("%s+$", "")
                return sanitized ~= "" and sanitized or nil
            end

            -- Helper function to sanitize snippet name
            local function sanitize_snippet_name(name)
                if not name or name == "" then
                    return nil
                end
                local sanitized = name:gsub("[^%w%s%-_]", ""):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
                return sanitized ~= "" and sanitized or nil
            end

            -- Helper function to save snippet to file
            local function save_snippet_to_file(category, snippet_name, snippet_content)
                local ai_snippets_dir = vim.fn.stdpath("config") .. "/ai-snippets"
                local sanitized_filename = sanitize_file_path(category .. ".txt", ai_snippets_dir)
                
                if not sanitized_filename then
                    handle_error("Invalid category name '" .. category .. "'")
                    return false
                end
                
                local file, err = io.open(sanitized_filename, "a")
                if not file then
                    handle_error("Could not open file " .. sanitized_filename .. ": " .. (err or "unknown error"))
                    return false
                end

                local success, write_err = pcall(function()
                    -- Add newlines before the new snippet if file exists and has content
                    local file_stat = vim.loop.fs_stat(sanitized_filename)
                    if file_stat and file_stat.size > 0 then
                        file:write("\n\n")
                    end

                    file:write("# " .. snippet_name .. "\n")
                    file:write(snippet_content .. "\n")
                end)

                file:close()

                if success then
                    vim.notify("Snippet '" .. snippet_name .. "' added to category '" .. category .. "'", vim.log.levels.INFO)
                    return true
                else
                    handle_error("Error writing to file " .. sanitized_filename .. ": " .. tostring(write_err))
                    return false
                end
            end

            -- Add new snippet functionality
            local function add_new_snippet()
                local categories = get_available_categories()

                vim.ui.select(categories, {
                    prompt = "Select category for new snippet:",
                }, function(selected_category)
                    if not selected_category then
                        return
                    end

                    local category = selected_category

                    -- Handle new category creation
                    if selected_category == "[Create new category]" then
                        vim.ui.input({
                            prompt = "Enter new category name: ",
                        }, function(new_category)
                            category = sanitize_category_name(new_category)
                            if not category then
                                handle_error("Invalid category name")
                                return
                            end
                            proceed_with_snippet_name(category)
                        end)
                    else
                        proceed_with_snippet_name(category)
                    end
                end)
            end

            -- Helper function to proceed with snippet name input
            local function proceed_with_snippet_name(category)
                vim.ui.input({
                    prompt = "Enter snippet name: ",
                }, function(snippet_name)
                    snippet_name = sanitize_snippet_name(snippet_name)
                    if not snippet_name then
                        handle_error("Invalid snippet name")
                        return
                    end

                    -- Get snippet content
                    multiline_input({
                        prompt = "Enter snippet content: ",
                    }, function(snippet_content)
                        if not snippet_content or snippet_content == "" then
                            return
                        end

                        save_snippet_to_file(category, snippet_name, snippet_content)
                    end)
                end)
            end

            -- Create user commands
            vim.api.nvim_create_user_command("ToggleClaudeTerminal", toggle_claude_terminal, {})
            vim.api.nvim_create_user_command("ToggleOpenCodeTerminal", toggle_opencode_terminal, {})
            vim.api.nvim_create_user_command("ToggleCursorAgentTerminal", toggle_cursor_agent_terminal, {})
            vim.api.nvim_create_user_command("SendCodeToAI", send_code_to_ai, { range = true })

            -- AI Snippet command with autocompletion
            vim.api.nvim_create_user_command("AISnippet", ai_snippet_command, {
                nargs = "?",
                complete = function(arg_lead, cmd_line, cursor_pos)
                    local snippet_names = get_snippet_names()
                    local matches = {}
                    for _, name in ipairs(snippet_names) do
                        if name:lower():find(arg_lead:lower(), 1, true) then
                            table.insert(matches, name)
                        end
                    end
                    return matches
                end,
                desc = "Insert AI snippet (use without args to open picker, or specify snippet name)"
            })

            -- Add new snippet functionality for project-specific snippets
            local function add_project_snippet()
                -- Check if we're in a git repository or project directory
                local nvim_config_file = vim.fn.getcwd() .. "/.nvim.lua"

                -- Get snippet name
                vim.ui.input({
                    prompt = "Enter project snippet name: ",
                }, function(snippet_name)
                    if not snippet_name or snippet_name == "" then
                        return
                    end

                    -- Get snippet content
                    multiline_input({
                        prompt = "Enter snippet content: ",
                    }, function(snippet_content)
                        if not snippet_content or snippet_content == "" then
                            return
                        end

                        -- Read existing .nvim.lua file or create new content
                        local existing_content = ""
                        local file, read_err = io.open(nvim_config_file, "r")
                        if file then
                            local success, content = pcall(function() return file:read("*all") end)
                            file:close()
                            if success and content then
                                existing_content = content
                            else
                                vim.notify("Error reading " .. nvim_config_file .. ": " .. tostring(content),
                                    vim.log.levels.WARN)
                            end
                        elseif read_err then
                            vim.notify("Note: " .. nvim_config_file .. " does not exist, will create new file",
                                vim.log.levels.INFO)
                        end

                        -- Parse or create AI_SNIPPETS table
                        local new_content
                        if existing_content:find("AI_SNIPPETS") then
                            -- Find the AI_SNIPPETS table and add to it
                            local before_snippets = existing_content:match("(.-)AI_SNIPPETS%s*=%s*{")
                            local after_snippets = existing_content:match("AI_SNIPPETS%s*=%s*{.-}(.*)")
                            local snippets_content = existing_content:match("AI_SNIPPETS%s*=%s*{(.-)}[^}]*$")

                            if before_snippets and after_snippets and snippets_content then
                                -- Add comma if there are existing snippets
                                local comma = snippets_content:match("%S") and "," or ""
                                -- Use long string syntax for multiline content
                                local formatted_content
                                if snippet_content:find('\n') then
                                    formatted_content = string.format('[[%s]]', snippet_content)
                                else
                                    formatted_content = string.format('"%s"', snippet_content:gsub('"', '\\"'))
                                end
                                local new_snippet = string.format('%s\n  ["%s"] = %s', comma,
                                    snippet_name:gsub('"', '\\"'), formatted_content)
                                new_content = before_snippets ..
                                    "AI_SNIPPETS = {" .. snippets_content .. new_snippet .. "\n}" .. after_snippets
                            else
                                -- Fallback: append at the end
                                new_content = existing_content ..
                                    string.format('\n\nAI_SNIPPETS = {\n  ["%s"] = "%s"\n}\n',
                                        snippet_name:gsub('"', '\\"'),
                                        snippet_content:gsub('"', '\\"'))
                            end
                        else
                            -- Create new AI_SNIPPETS table
                            local snippet_table = string.format('\nAI_SNIPPETS = {\n  ["%s"] = "%s"\n}\n',
                                snippet_name:gsub('"', '\\"'), snippet_content:gsub('"', '\\"'))
                            new_content = existing_content .. snippet_table
                        end

                        -- Write to .nvim.lua file
                        local output_file, write_err = io.open(nvim_config_file, "w")
                        if output_file then
                            local success, err = pcall(function()
                                output_file:write(new_content)
                            end)
                            output_file:close()

                            if success then
                                -- Note: We don't automatically reload .nvim.lua for security reasons
                                -- User should manually reload or restart Neovim
                                vim.notify("Project snippet '" .. snippet_name .. "' added to .nvim.lua",
                                    vim.log.levels.INFO)
                                vim.notify(
                                    "Please reload the .nvim.lua file manually or restart Neovim to use the new snippet",
                                    vim.log.levels.INFO)
                            else
                                vim.notify("Error writing to " .. nvim_config_file .. ": " .. tostring(err),
                                    vim.log.levels.ERROR)
                            end
                        else
                            vim.notify(
                                "Error: Could not open " ..
                                nvim_config_file .. " for writing: " .. (write_err or "unknown error"),
                                vim.log.levels.ERROR)
                        end
                    end)
                end)
            end

            -- Add new snippet command
            vim.api.nvim_create_user_command("AISnippetAdd", add_new_snippet, {
                desc = "Add a new global AI snippet"
            })

            -- Add new project snippet command
            vim.api.nvim_create_user_command("AISnippetAddProject", add_project_snippet, {
                desc = "Add a new project-specific AI snippet"
            })

            -- Set up keybindings
            vim.keymap.set("n", "<leader>zc", toggle_claude_terminal, { desc = "Toggle Claude terminal" })
            vim.keymap.set("n", "<leader>zo", toggle_opencode_terminal, { desc = "Toggle OpenCode terminal" })
            vim.keymap.set("n", "<leader>zg", toggle_cursor_agent_terminal, { desc = "Toggle Cursor Agent terminal" })
            vim.keymap.set("n", "<leader>zs", send_file_to_ai, { desc = "Send file context to AI with prompt" })
            vim.keymap.set("v", "<leader>zs", send_code_to_ai, { desc = "Send selected code to AI with prompt" })
            vim.keymap.set("n", "<leader>zS", send_file_to_ai_no_submit,
                { desc = "Send file context to AI (no auto-submit)" })
            vim.keymap.set("v", "<leader>zS", send_code_to_ai_no_submit,
                { desc = "Send selected code to AI (no auto-submit)" })
            vim.keymap.set("n", "<leader>zi", open_snippet_picker_auto_submit, { desc = "Open AI snippet picker (auto-submit)" })
            vim.keymap.set("n", "<leader>zI", open_snippet_picker, { desc = "Open AI snippet picker (no auto-submit)" })
            vim.keymap.set("n", "<leader>zX", cleanup_ai_clients, { desc = "Cleanup all AI clients" })


            -- Utility function to switch active AI client
            local function set_active_ai_client()
                local clients = { "claude", "opencode", "cursor_agent" }
                vim.ui.select(clients, {
                    prompt = "Select active AI client:",
                }, function(choice)
                    if choice then
                        ai_state.active_client = choice
                        vim.notify("Active AI client set to: " .. choice, vim.log.levels.INFO)
                    end
                end)
            end

            vim.keymap.set("n", "<leader>za", set_active_ai_client, { desc = "Set active AI client" })
        end,
    }
}
