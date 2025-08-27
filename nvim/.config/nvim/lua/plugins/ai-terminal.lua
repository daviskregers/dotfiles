return {
    {
        "ai-terminal",
        dir = vim.fn.stdpath("config"),
        name = "ai-terminal",
        config = function()
            -- State management for AI client terminals
            local ai_state = {
                claude = {
                    buf = -1,
                    win = -1,
                    job_id = -1,
                },
                opencode = {
                    buf = -1,
                    win = -1,
                    job_id = -1,
                },
                cursor_agent = {
                    buf = -1,
                    win = -1,
                    job_id = -1,
                },
                active_client = "claude", -- Track which client is currently active
            }

            -- Create a vsplit window for AI terminals (always right split)
            local function create_ai_terminal_window(opts)
                opts = opts or {}
                local cols = vim.o.columns
                local width = opts.width or math.floor(cols * 0.3) -- 30% of screen width

                local buf = nil
                if vim.api.nvim_buf_is_valid(opts.buf) then
                    buf = opts.buf
                else
                    buf = vim.api.nvim_create_buf(false, true)
                end

                local win_config = {
                    split = 'right',
                    win = vim.api.nvim_get_current_win(),
                    width = width,
                }

                local win = vim.api.nvim_open_win(buf, true, win_config)

                return { buf = buf, win = win }
            end

            -- Generic function to toggle AI client terminals
            local function toggle_ai_terminal(client_name, command)
                local client = ai_state[client_name]

                if not vim.api.nvim_win_is_valid(client.win) then
                    -- Create or show terminal
                    local result = create_ai_terminal_window({ buf = client.buf })
                    ai_state[client_name].buf = result.buf
                    ai_state[client_name].win = result.win
                    ai_state.active_client = client_name

                    -- Start terminal if not already a terminal buffer
                    if vim.api.nvim_buf_is_valid(result.buf) and vim.bo[result.buf].buftype ~= "terminal" then
                        if command then
                            vim.cmd.term(command)
                        else
                            vim.cmd.term()
                        end
                    end

                    -- Update job_id for sending commands (ensure buffer is still valid)
                    if vim.api.nvim_buf_is_valid(result.buf) then
                        ai_state[client_name].job_id = vim.bo[result.buf].channel
                    end
                else
                    -- Hide terminal
                    vim.api.nvim_win_hide(client.win)
                    ai_state[client_name].win = -1
                end
            end

            -- Toggle Claude terminal
            local function toggle_claude_terminal()
                toggle_ai_terminal("claude", "claude")
            end

            -- Toggle OpenCode terminal
            local function toggle_opencode_terminal()
                toggle_ai_terminal("opencode", nil) -- Will just open a regular terminal for now
            end

            -- Toggle Cursor Agent terminal
            local function toggle_cursor_agent_terminal()
                toggle_ai_terminal("cursor_agent", nil) -- Will just open a regular terminal for now
            end

            -- Multiline Input Function
            local function multiline_input(opts, callback)
                opts = opts or {}
                local prompt = opts.prompt or "Enter text:"
                local default = opts.default or ""
                
                -- Create a floating window for multiline input
                local buf = vim.api.nvim_create_buf(false, true)
                local width = math.min(80, vim.o.columns - 10)
                local height = math.min(20, vim.o.lines - 10)
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
                vim.bo[buf].filetype = "markdown"  -- For syntax highlighting
                
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
                vim.api.nvim_win_set_cursor(win, {#instructions, 0})
                
                -- Set up keymaps for the input window
                local function submit()
                    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
                    
                    -- Remove instruction lines (first 3 lines)
                    local content_lines = {}
                    for i = 4, #lines do
                        table.insert(content_lines, lines[i])
                    end
                    
                    -- Remove trailing empty lines
                    while #content_lines > 0 and content_lines[#content_lines] == "" do
                        table.remove(content_lines)
                    end
                    
                    local content = table.concat(content_lines, "\n")
                    
                    -- Safely close window and cleanup buffer
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
                    
                    -- Call callback with content
                    if content ~= "" then
                        callback(content)
                    else
                        callback(nil)
                    end
                end
                
                local function cancel()
                    -- Safely close window and cleanup buffer
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
                    callback(nil)
                end
                
                -- Set up key mappings for the input buffer
                vim.keymap.set({"n", "i"}, "<C-s>", submit, { buffer = buf, nowait = true })
                vim.keymap.set({"n", "i"}, "<C-c>", cancel, { buffer = buf, nowait = true })
                vim.keymap.set("n", "<Esc>", cancel, { buffer = buf, nowait = true })
                
                -- Start in insert mode at the end of the buffer
                vim.cmd("startinsert")
            end

            -- Get selected text and prompt for input
            local function send_code_to_ai()
                -- Get the current active AI client
                local active = ai_state.active_client
                local client = ai_state[active]

                -- Ensure terminal is open and valid
                if not vim.api.nvim_win_is_valid(client.win) or not vim.api.nvim_buf_is_valid(client.buf) or client.job_id == -1 then
                    print("No active AI terminal. Please open one first with <leader>z + c/o/g")
                    return
                end

                -- Get selected text
                local start_pos = vim.fn.getpos("'<")
                local end_pos = vim.fn.getpos("'>")

                if start_pos[2] == 0 or end_pos[2] == 0 then
                    print("No text selected. Please select code first.")
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
                    prompt = "Enter prompt for " .. active .. ": ",
                    default = "",
                }, function(prompt)
                    if not prompt or prompt == "" then
                        return
                    end

                    -- Format the message to send to AI terminal
                    local file_path = vim.fn.expand('%:.')  -- Relative path from current working directory
                    local file_name = vim.fn.expand('%:t')  -- Just the filename
                    local start_line = start_pos[2]
                    local end_line = end_pos[2]
                    
                    local location_info
                    if start_line == end_line then
                        location_info = string.format("From %s:%d", file_path, start_line)
                    else
                        location_info = string.format("From %s:%d-%d", file_path, start_line, end_line)
                    end
                    
                    local message = string.format("%s\n\n```%s\n%s\n```\n\n%s", location_info, vim.bo.filetype, selected_code, prompt)

                    -- Store current window for later restoration
                    local current_win = vim.api.nvim_get_current_win()
                    
                    -- Switch to terminal window and handle focus properly
                    vim.api.nvim_set_current_win(client.win)
                    
                    -- Use vim.schedule to ensure proper timing for terminal operations
                    vim.schedule(function()
                        -- Enter insert mode in terminal
                        vim.cmd('startinsert')
                        
                        -- Send message with appropriate delay for Claude vs other terminals
                        vim.defer_fn(function()
                            if active == "claude" then
                                -- For claude-code, send the message then submit
                                vim.fn.chansend(client.job_id, escape_terminal_input(message))
                                vim.defer_fn(function()
                                    vim.fn.feedkeys("\r", "n") -- Enter key to submit
                                    -- Return focus to original window after submission
                                    vim.defer_fn(function()
                                        if vim.api.nvim_win_is_valid(current_win) then
                                            vim.api.nvim_set_current_win(current_win)
                                        end
                                    end, 200)
                                end, 100)
                            else
                                -- For other terminals, send the formatted message and submit
                                vim.fn.chansend(client.job_id, escape_terminal_input(message) .. "\n")
                                -- Return focus to original window
                                vim.defer_fn(function()
                                    if vim.api.nvim_win_is_valid(current_win) then
                                        vim.api.nvim_set_current_win(current_win)
                                    end
                                end, 200)
                            end
                        end, 50)
                    end)

                    print("Code sent to " .. active .. " terminal")
                end)
            end

            -- Send current file context to AI (normal mode)
            local function send_file_to_ai()
                -- Get the current active AI client
                local active = ai_state.active_client
                local client = ai_state[active]

                -- Ensure terminal is open and valid
                if not vim.api.nvim_win_is_valid(client.win) or not vim.api.nvim_buf_is_valid(client.buf) or client.job_id == -1 then
                    print("No active AI terminal. Please open one first with <leader>z + c/o/g")
                    return
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
                    local file_path = vim.fn.expand('%:.')  -- Relative path from current working directory
                    local message = string.format("Working with file: %s\n\n%s", file_path, prompt)

                    -- Store current window for later restoration
                    local current_win = vim.api.nvim_get_current_win()
                    
                    -- Switch to terminal window and handle focus properly
                    vim.api.nvim_set_current_win(client.win)
                    
                    -- Use vim.schedule to ensure proper timing for terminal operations
                    vim.schedule(function()
                        -- Enter insert mode in terminal
                        vim.cmd('startinsert')
                        
                        -- Send message with appropriate delay for Claude vs other terminals
                        vim.defer_fn(function()
                            if active == "claude" then
                                -- For claude-code, send the message then submit
                                vim.fn.chansend(client.job_id, escape_terminal_input(message))
                                vim.defer_fn(function()
                                    vim.fn.feedkeys("\r", "n") -- Enter key to submit
                                    -- Return focus to original window after submission
                                    vim.defer_fn(function()
                                        if vim.api.nvim_win_is_valid(current_win) then
                                            vim.api.nvim_set_current_win(current_win)
                                        end
                                    end, 200)
                                end, 100)
                            else
                                -- For other terminals, send the formatted message and submit
                                vim.fn.chansend(client.job_id, escape_terminal_input(message) .. "\n")
                                -- Return focus to original window
                                vim.defer_fn(function()
                                    if vim.api.nvim_win_is_valid(current_win) then
                                        vim.api.nvim_set_current_win(current_win)
                                    end
                                end, 200)
                            end
                        end, 50)
                    end)

                    print("File context sent to " .. active .. " terminal")
                end)
            end

            -- Send current file context to AI without auto-submit (normal mode)
            local function send_file_to_ai_no_submit()
                -- Get the current active AI client
                local active = ai_state.active_client
                local client = ai_state[active]

                -- Ensure terminal is open and valid
                if not vim.api.nvim_win_is_valid(client.win) or not vim.api.nvim_buf_is_valid(client.buf) or client.job_id == -1 then
                    print("No active AI terminal. Please open one first with <leader>z + c/o/g")
                    return
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
                    local file_path = vim.fn.expand('%:.')  -- Relative path from current working directory
                    local message = string.format("Working with file: %s\n\n%s\n\n", file_path, prompt)

                    -- Store current window for later restoration
                    local current_win = vim.api.nvim_get_current_win()
                    
                    -- Switch to terminal window and handle focus properly
                    vim.api.nvim_set_current_win(client.win)
                    
                    -- Use vim.schedule to ensure proper timing for terminal operations
                    vim.schedule(function()
                        -- Enter insert mode in terminal
                        vim.cmd('startinsert')
                        
                        -- Send message without auto-submit
                        vim.defer_fn(function()
                            -- Send the message to the terminal input
                            vim.fn.chansend(client.job_id, escape_terminal_input(message))
                            
                            -- Return focus to original window after sending message
                            vim.defer_fn(function()
                                if vim.api.nvim_win_is_valid(current_win) then
                                    vim.api.nvim_set_current_win(current_win)
                                end
                            end, 100)
                        end, 50)
                    end)

                    print("Message added to " .. active .. " terminal (not submitted)")
                end)
            end

            -- Send selected code to AI without auto-submit (visual mode)
            local function send_code_to_ai_no_submit()
                -- Get the current active AI client
                local active = ai_state.active_client
                local client = ai_state[active]

                -- Ensure terminal is open and valid
                if not vim.api.nvim_win_is_valid(client.win) or not vim.api.nvim_buf_is_valid(client.buf) or client.job_id == -1 then
                    print("No active AI terminal. Please open one first with <leader>z + c/o/g")
                    return
                end

                -- Get selected text
                local start_pos = vim.fn.getpos("'<")
                local end_pos = vim.fn.getpos("'>")

                if start_pos[2] == 0 or end_pos[2] == 0 then
                    print("No text selected. Please select code first.")
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
                    prompt = "Enter prompt for " .. active .. " (no auto-submit): ",
                    default = "",
                }, function(prompt)
                    if not prompt or prompt == "" then
                        return
                    end

                    -- Format the message to send to AI terminal
                    local file_path = vim.fn.expand('%:.')  -- Relative path from current working directory
                    local file_name = vim.fn.expand('%:t')  -- Just the filename
                    local start_line = start_pos[2]
                    local end_line = end_pos[2]
                    
                    local location_info
                    if start_line == end_line then
                        location_info = string.format("From %s:%d", file_path, start_line)
                    else
                        location_info = string.format("From %s:%d-%d", file_path, start_line, end_line)
                    end
                    
                    local message = string.format("%s\n\n```%s\n%s\n```\n\n%s\n\n", location_info, vim.bo.filetype, selected_code, prompt)

                    -- Store current window for later restoration
                    local current_win = vim.api.nvim_get_current_win()
                    
                    -- Switch to terminal window and handle focus properly
                    vim.api.nvim_set_current_win(client.win)
                    
                    -- Use vim.schedule to ensure proper timing for terminal operations
                    vim.schedule(function()
                        -- Enter insert mode in terminal
                        vim.cmd('startinsert')
                        
                        -- Send message without auto-submit
                        vim.defer_fn(function()
                            -- Send the message to the terminal input
                            vim.fn.chansend(client.job_id, escape_terminal_input(message))
                            
                            -- Return focus to original window after sending message
                            vim.defer_fn(function()
                                if vim.api.nvim_win_is_valid(current_win) then
                                    vim.api.nvim_set_current_win(current_win)
                                end
                            end, 100)
                        end, 50)
                    end)

                    print("Code added to " .. active .. " terminal (not submitted)")
                end)
                
                -- Clear visual selection by pressing escape
                vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)
            end

            -- AI Snippet System
            local snippet_cache = {
                global_snippets = {},
                file_mtimes = {},
                last_check_time = 0
            }

            -- Utility function to escape terminal input
            local function escape_terminal_input(input)
                if not input or type(input) ~= "string" then
                    return ""
                end
                
                -- Remove control characters except newlines and tabs
                input = input:gsub("[\1-\8\11-\12\14-\31\127]", "")
                
                -- Escape terminal escape sequences
                input = input:gsub("\27", "")  -- Remove ESC character
                
                return input
            end

            -- Utility function to sanitize file paths
            local function sanitize_file_path(path, base_dir)
                if not path or type(path) ~= "string" then
                    return nil
                end
                
                -- Remove any null bytes
                path = path:gsub("%z", "")
                
                -- Normalize path separators
                path = path:gsub("\\", "/")
                
                -- Remove any path traversal attempts
                path = path:gsub("%.%./", "")
                path = path:gsub("%.%.", "")
                
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
                    vim.notify("Error parsing snippet file " .. filepath .. ": " .. tostring(result), vim.log.levels.ERROR)
                end
                
                return snippets
            end

            local function load_global_snippets()
                local current_time = vim.loop.hrtime()
                local cache_ttl = 5 * 1e9 -- 5 seconds in nanoseconds
                
                -- Check if cache is still valid (not older than TTL)
                if current_time - snippet_cache.last_check_time < cache_ttl then
                    return snippet_cache.global_snippets
                end
                
                local snippets = {}
                local ai_snippets_dir = vim.fn.stdpath("config") .. "/ai-snippets"
                local needs_update = false
                
                -- Get all .txt files in the ai-snippets directory
                local files = vim.fn.glob(ai_snippets_dir .. "/*.txt", false, true)
                
                for _, filepath in ipairs(files) do
                    local stat = vim.loop.fs_stat(filepath)
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
                    -- Rebuild entire cache since we need consistent state
                    snippets = {}
                    for _, filepath in ipairs(files) do
                        local file_snippets = parse_snippet_file(filepath)
                        local category = vim.fn.fnamemodify(filepath, ":t:r")
                        
                        for name, content in pairs(file_snippets) do
                            snippets[name] = {
                                content = content,
                                category = category,
                                display_name = string.format("[%s] %s", category, name)
                            }
                        end
                    end
                    
                    snippet_cache.global_snippets = snippets
                    snippet_cache.last_check_time = current_time
                else
                    snippets = snippet_cache.global_snippets
                end
                
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
                for name, snippet_data in pairs(global_snippets) do
                    snippets[name] = snippet_data
                end
                
                -- Load project snippets (they take precedence for same names)
                local project_snippets = load_project_snippets()
                for name, snippet_data in pairs(project_snippets) do
                    snippets[name] = snippet_data
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
                -- Get the current active AI client
                local active = ai_state.active_client
                local client = ai_state[active]

                -- Ensure terminal is open and valid
                if not vim.api.nvim_win_is_valid(client.win) or not vim.api.nvim_buf_is_valid(client.buf) or client.job_id == -1 then
                    print("No active AI terminal. Please open one first with <leader>z + c/o/g")
                    return
                end

                local snippets = load_all_snippets()
                local snippet_data = snippets[snippet_name]
                
                if not snippet_data then
                    print("Snippet '" .. snippet_name .. "' not found")
                    return
                end

                local content = process_placeholders(snippet_data.content, context)

                -- Store current window for later restoration
                local current_win = vim.api.nvim_get_current_win()
                
                -- Switch to terminal window and handle focus properly
                vim.api.nvim_set_current_win(client.win)
                
                -- Use vim.schedule to ensure proper timing for terminal operations
                vim.schedule(function()
                    -- Enter insert mode in terminal
                    vim.cmd('startinsert')
                    
                    -- Send snippet content without auto-submit
                    vim.defer_fn(function()
                        -- Send the snippet content to the terminal input
                        vim.fn.chansend(client.job_id, escape_terminal_input(content))
                        
                        -- Return focus to original window after sending content
                        vim.defer_fn(function()
                            if vim.api.nvim_win_is_valid(current_win) then
                                vim.api.nvim_set_current_win(current_win)
                            end
                        end, 100)
                    end, 50)
                end)

                print("Snippet '" .. snippet_name .. "' inserted into " .. active .. " terminal")
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
                            vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, vim.split(entry.value.content, "\n"))
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

            -- Add new snippet functionality
            local function add_new_snippet()
                -- Get available categories from existing files
                local ai_snippets_dir = vim.fn.stdpath("config") .. "/ai-snippets"
                local files = vim.fn.glob(ai_snippets_dir .. "/*.txt", false, true)
                local categories = {}
                
                for _, filepath in ipairs(files) do
                    local category = vim.fn.fnamemodify(filepath, ":t:r")
                    table.insert(categories, category)
                end
                
                -- Add option to create new category
                table.insert(categories, "[Create new category]")
                
                -- Select category
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
                            if not new_category or new_category == "" then
                                return
                            end
                            -- Sanitize category name
                            new_category = new_category:gsub("[^%w%-_]", ""):gsub("^%s+", ""):gsub("%s+$", "")
                            if new_category == "" then
                                vim.notify("Error: Invalid category name", vim.log.levels.ERROR)
                                return
                            end
                            category = new_category
                        end)
                        
                        if not category or category == "[Create new category]" then
                            return
                        end
                    end
                    
                    -- Get snippet name
                    vim.ui.input({
                        prompt = "Enter snippet name: ",
                    }, function(snippet_name)
                        if not snippet_name or snippet_name == "" then
                            return
                        end
                        
                        -- Sanitize snippet name
                        snippet_name = snippet_name:gsub("[^%w%s%-_]", ""):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
                        if snippet_name == "" then
                            vim.notify("Error: Invalid snippet name", vim.log.levels.ERROR)
                            return
                        end
                        
                        -- Get snippet content
                        multiline_input({
                            prompt = "Enter snippet content: ",
                        }, function(snippet_content)
                            if not snippet_content or snippet_content == "" then
                                return
                            end
                            
                            -- Save snippet to file (with path sanitization)
                            local sanitized_filename = sanitize_file_path(category .. ".txt", ai_snippets_dir)
                            if not sanitized_filename then
                                vim.notify("Error: Invalid category name '" .. category .. "'", vim.log.levels.ERROR)
                                return
                            end
                            local category_file = sanitized_filename
                            local file, err = io.open(category_file, "a")
                            
                            if file then
                                local success, write_err = pcall(function()
                                    -- Add newlines before the new snippet if file exists and has content
                                    local file_stat = vim.loop.fs_stat(category_file)
                                    if file_stat and file_stat.size > 0 then
                                        file:write("\n\n")
                                    end
                                    
                                    file:write("# " .. snippet_name .. "\n")
                                    file:write(snippet_content .. "\n")
                                end)
                                
                                file:close()
                                
                                if success then
                                    print("Snippet '" .. snippet_name .. "' added to category '" .. category .. "'")
                                else
                                    vim.notify("Error writing to file " .. category_file .. ": " .. tostring(write_err), vim.log.levels.ERROR)
                                end
                            else
                                vim.notify("Error: Could not open file " .. category_file .. ": " .. (err or "unknown error"), vim.log.levels.ERROR)
                            end
                        end)
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
                                vim.notify("Error reading " .. nvim_config_file .. ": " .. tostring(content), vim.log.levels.WARN)
                            end
                        elseif read_err then
                            vim.notify("Note: " .. nvim_config_file .. " does not exist, will create new file", vim.log.levels.INFO)
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
                                local new_snippet = string.format('%s\n  ["%s"] = %s', comma, snippet_name:gsub('"', '\\"'), formatted_content)
                                new_content = before_snippets .. "AI_SNIPPETS = {" .. snippets_content .. new_snippet .. "\n}" .. after_snippets
                            else
                                -- Fallback: append at the end
                                new_content = existing_content .. string.format('\n\nAI_SNIPPETS = {\n  ["%s"] = "%s"\n}\n', snippet_name:gsub('"', '\\"'), snippet_content:gsub('"', '\\"'))
                            end
                        else
                            -- Create new AI_SNIPPETS table
                            local snippet_table = string.format('\nAI_SNIPPETS = {\n  ["%s"] = "%s"\n}\n', snippet_name:gsub('"', '\\"'), snippet_content:gsub('"', '\\"'))
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
                                vim.notify("Project snippet '" .. snippet_name .. "' added to .nvim.lua", vim.log.levels.INFO)
                                vim.notify("Please reload the .nvim.lua file manually or restart Neovim to use the new snippet", vim.log.levels.INFO)
                            else
                                vim.notify("Error writing to " .. nvim_config_file .. ": " .. tostring(err), vim.log.levels.ERROR)
                            end
                        else
                            vim.notify("Error: Could not open " .. nvim_config_file .. " for writing: " .. (write_err or "unknown error"), vim.log.levels.ERROR)
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
            vim.keymap.set("n", "<leader>zS", send_file_to_ai_no_submit, { desc = "Send file context to AI (no auto-submit)" })
            vim.keymap.set("v", "<leader>zS", send_code_to_ai_no_submit, { desc = "Send selected code to AI (no auto-submit)" })
            vim.keymap.set("n", "<leader>zi", open_snippet_picker, { desc = "Open AI snippet picker" })

            -- Utility function to switch active AI client
            local function set_active_ai_client()
                local clients = { "claude", "opencode", "cursor_agent" }
                vim.ui.select(clients, {
                    prompt = "Select active AI client:",
                }, function(choice)
                    if choice then
                        ai_state.active_client = choice
                        print("Active AI client set to: " .. choice)
                    end
                end)
            end

            vim.keymap.set("n", "<leader>za", set_active_ai_client, { desc = "Set active AI client" })
        end,
    }
}

