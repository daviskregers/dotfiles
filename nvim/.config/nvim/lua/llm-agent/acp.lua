-- opencode ACP (Agent Client Protocol) transport. opencode has no working
-- PreToolUse-hook equivalent (plugin permission.ask is buggy — sst/opencode
-- #7006/#19927), so its permission bridge goes through ACP's interrupt-driven
-- session/request_permission instead. Newline-delimited JSON-RPC 2.0 over stdio
-- against `opencode acp`. Pure protocol helpers are tested; run() is the shell.
local M = {}

-- Classify an incoming JSON-RPC message.
function M.classify(msg)
  if msg.id ~= nil and (msg.result ~= nil or msg.error ~= nil) then return "response" end
  if msg.id ~= nil and msg.method then return "request" end -- server→client (e.g. request_permission)
  return "notification"
end

-- Map an ACP session/update payload to a normalized event, or nil to ignore.
function M.map_update(update)
  local t = update.sessionUpdate
  if t == "agent_message_chunk" then
    return { type = "text", text = (update.content or {}).text or "" }
  elseif t == "agent_thought_chunk" then
    return { type = "thinking", text = (update.content or {}).text or "" }
  elseif t == "tool_call" or t == "tool_call_update" then
    return { type = "tool", tool = update.title, input = update.rawInput, id = update.toolCallId }
  end
  return nil
end

-- Pick the ACP optionId matching our decision, by option kind.
-- once → allow_once · session → allow_always · deny → reject_once/reject_always.
function M.permission_option(options, choice)
  local want = ({ once = "allow_once", session = "allow_always", deny = "reject_once" })[choice]
  for _, o in ipairs(options or {}) do if o.kind == want then return o.optionId end end
  -- fall back to any reject/allow of the right polarity
  local allow = choice ~= "deny"
  for _, o in ipairs(options or {}) do
    if allow == (o.kind:sub(1, 5) == "allow") then return o.optionId end
  end
  return nil
end

-- Drive one prompt over ACP. opts: prompt, cwd, on_event(ev), on_permission(entry)
-- where entry = {tool,input,session,respond(choice)}, on_done(), on_exit(code).
-- Returns the vim.system handle. Shell (verified live, not unit-tested).
function M.run(opts)
  local id_seq, handlers, partial, proc = 0, {}, "", nil

  local function send(obj) if proc then proc:write(vim.json.encode(obj) .. "\n") end end
  local function request(method, params, cb)
    id_seq = id_seq + 1
    handlers[id_seq] = cb or function() end
    send({ jsonrpc = "2.0", id = id_seq, method = method, params = params })
  end

  local function on_message(msg)
    local kind = M.classify(msg)
    if kind == "response" then
      local h = handlers[msg.id]; handlers[msg.id] = nil
      if h then h(msg.result, msg.error) end
    elseif kind == "request" and msg.method == "session/request_permission" then
      local p = msg.params
      if opts.on_permission then
        opts.on_permission({
          tool = (p.toolCall or {}).title, input = (p.toolCall or {}).rawInput, session = p.sessionId,
          respond = function(choice)
            send({ jsonrpc = "2.0", id = msg.id,
              result = { outcome = { outcome = "selected", optionId = M.permission_option(p.options, choice) } } })
          end,
        })
      end
    elseif kind == "notification" and msg.method == "session/update" then
      local ev = M.map_update((msg.params or {}).update or {})
      if ev and opts.on_event then opts.on_event(ev) end
    end
  end

  local function on_stdout(_, data)
    if not data then return end
    partial = partial .. data
    while true do
      local nl = partial:find("\n"); if not nl then break end
      local line = partial:sub(1, nl - 1); partial = partial:sub(nl + 1)
      if line ~= "" then
        local ok, msg = pcall(vim.json.decode, line)
        if ok and type(msg) == "table" then vim.schedule(function() on_message(msg) end) end
      end
    end
  end

  proc = vim.system({ "opencode", "acp" }, { cwd = opts.cwd, stdin = true, text = true, stdout = on_stdout },
    function(o) vim.schedule(function() if opts.on_exit then opts.on_exit(o.code) end end) end)

  request("initialize", { protocolVersion = 1, clientCapabilities = { fs = { readTextFile = false, writeTextFile = false } } },
    function()
      request("session/new", { cwd = opts.cwd or vim.fn.getcwd(), mcpServers = {} }, function(res)
        request("session/prompt", { sessionId = res and res.sessionId, prompt = { { type = "text", text = opts.prompt } } },
          function() if opts.on_done then opts.on_done() end end)
      end)
    end)
  return proc
end

return M
