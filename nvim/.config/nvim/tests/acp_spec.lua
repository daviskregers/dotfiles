local acp = require("llm-agent.acp")

describe("classify", function()
  it("distinguishes responses, server→client requests, and notifications", function()
    assert.are.equal("response", acp.classify({ id = 1, result = {} }))
    assert.are.equal("response", acp.classify({ id = 1, error = {} }))
    assert.are.equal("request", acp.classify({ id = 2, method = "session/request_permission" }))
    assert.are.equal("notification", acp.classify({ method = "session/update", params = {} }))
  end)
end)

describe("map_update", function()
  it("maps agent_message_chunk → text", function()
    assert.are.same({ type = "text", text = "hi" },
      acp.map_update({ sessionUpdate = "agent_message_chunk", content = { type = "text", text = "hi" } }))
  end)

  it("maps agent_thought_chunk → thinking", function()
    assert.are.same({ type = "thinking", text = "hmm" },
      acp.map_update({ sessionUpdate = "agent_thought_chunk", content = { type = "text", text = "hmm" } }))
  end)

  it("maps tool_call → tool with its command + toolCallId (for coalescing updates)", function()
    local ev = acp.map_update({ sessionUpdate = "tool_call", toolCallId = "tc1", title = "bash",
      rawInput = { command = "echo hi" } })
    assert.are.equal("tool", ev.type)
    assert.are.equal("bash", ev.tool)
    assert.are.equal("echo hi", ev.input.command)
    assert.are.equal("tc1", ev.id)
  end)

  it("ignores non-content updates", function()
    assert.is_nil(acp.map_update({ sessionUpdate = "available_commands_update", availableCommands = {} }))
  end)
end)

describe("permission_option", function()
  local options = {
    { optionId = "once", kind = "allow_once" },
    { optionId = "always", kind = "allow_always" },
    { optionId = "reject", kind = "reject_once" },
  }
  it("maps our choice to the matching ACP optionId by kind", function()
    assert.are.equal("once", acp.permission_option(options, "once"))
    assert.are.equal("always", acp.permission_option(options, "session"))
    assert.are.equal("reject", acp.permission_option(options, "deny"))
  end)
end)

describe("run", function()
  it("surfaces the ACP session id before permission requests rely on it", function()
    local writes, events = {}, {}
    local stdout_cb
    local old_system, old_schedule = vim.system, vim.schedule

    vim.schedule = function(fn) fn() end
    vim.system = function(_, opts)
      stdout_cb = opts.stdout
      return {
        write = function(_, chunk) writes[#writes + 1] = chunk end,
      }
    end

    local ok, err = pcall(function()
      acp.run({
        cwd = "/tmp",
        prompt = "hi",
        on_event = function(ev) events[#events + 1] = ev end,
      })
      stdout_cb(nil, vim.json.encode({ jsonrpc = "2.0", id = 1, result = {} }) .. "\n")
      stdout_cb(nil, vim.json.encode({ jsonrpc = "2.0", id = 2, result = { sessionId = "sess-1" } }) .. "\n")
    end)

    vim.system, vim.schedule = old_system, old_schedule
    assert.is_true(ok, err)
    assert.are.same({ type = "session", session = "sess-1" }, events[1])
    assert.is_truthy(writes[3]:find('"method":"session/prompt"', 1, true))
  end)

  it("reuses an existing session on resumed turns", function()
    local writes = {}
    local stdout_cb
    local old_system, old_schedule = vim.system, vim.schedule

    vim.schedule = function(fn) fn() end
    vim.system = function(_, opts)
      stdout_cb = opts.stdout
      return {
        write = function(_, chunk) writes[#writes + 1] = chunk end,
      }
    end

    local ok, err = pcall(function()
      acp.run({ cwd = "/tmp", prompt = "again", session = "sess-9", resume = true })
      stdout_cb(nil, vim.json.encode({ jsonrpc = "2.0", id = 1, result = {} }) .. "\n")
    end)

    vim.system, vim.schedule = old_system, old_schedule
    assert.is_true(ok, err)
    assert.is_nil(writes[2]:find('"method":"session/new"', 1, true))
    assert.is_truthy(writes[2]:find('"method":"session/prompt"', 1, true))
    assert.is_truthy(writes[2]:find('"sessionId":"sess%-9"'))
  end)

  it("surfaces session/new errors via on_event so they show in transcript", function()
    local events = {}
    local stdout_cb
    local old_system, old_schedule = vim.system, vim.schedule

    vim.schedule = function(fn) fn() end
    vim.system = function(_, opts)
      stdout_cb = opts.stdout
      return {
        write = function(_, chunk) end,
        kill = function() end,
      }
    end

    local ok, err = pcall(function()
      acp.run({
        cwd = "/tmp", prompt = "hi",
        on_event = function(ev) events[#events + 1] = ev end,
      })
      stdout_cb(nil, vim.json.encode({ jsonrpc = "2.0", id = 1, result = {} }) .. "\n")
      stdout_cb(nil, vim.json.encode({ jsonrpc = "2.0", id = 2, error = { code = -32600, message = "session/new failed" } }) .. "\n")
    end)

    vim.system, vim.schedule = old_system, old_schedule
    assert.is_true(ok, err)
    assert.are.equal("error", events[1].type)
    assert.is_truthy(events[1].error:find("session/new"))
  end)

  it("surfaces session/prompt errors via on_event so they show in transcript", function()
    local events = {}
    local stdout_cb
    local old_system, old_schedule = vim.system, vim.schedule

    vim.schedule = function(fn) fn() end
    vim.system = function(_, opts)
      stdout_cb = opts.stdout
      return {
        write = function(_, chunk) end,
        kill = function() end,
      }
    end

    local ok, err = pcall(function()
      acp.run({
        cwd = "/tmp", prompt = "hi", session = "sess-42", resume = true,
        on_event = function(ev) events[#events + 1] = ev end,
      })
      stdout_cb(nil, vim.json.encode({ jsonrpc = "2.0", id = 1, result = {} }) .. "\n")
      stdout_cb(nil, vim.json.encode({ jsonrpc = "2.0", id = 2, error = { code = -32600, message = "prompt rejected" } }) .. "\n")
    end)

    vim.system, vim.schedule = old_system, old_schedule
    assert.is_true(ok, err)
    assert.are.equal("error", events[1].type)
    assert.is_truthy(events[1].error:find("session/prompt"))
  end)

  it("auto-recovers from stale session by creating a new one and retrying prompt", function()
    local writes, events = {}, {}
    local stdout_cb
    local old_system, old_schedule = vim.system, vim.schedule

    vim.schedule = function(fn) fn() end
    vim.system = function(_, opts)
      stdout_cb = opts.stdout
      return {
        write = function(_, chunk) writes[#writes + 1] = chunk end,
        kill = function() end,
      }
    end

    local ok, err = pcall(function()
      acp.run({
        cwd = "/tmp", prompt = "hi", session = "old-sess", resume = true,
        on_event = function(ev) events[#events + 1] = ev end,
      })
      stdout_cb(nil, vim.json.encode({ jsonrpc = "2.0", id = 1, result = {} }) .. "\n")
      -- session/prompt fails with "session not found" → should trigger session/new
      stdout_cb(nil, vim.json.encode({ jsonrpc = "2.0", id = 2, error = { code = -32602, message = "Session not found" } }) .. "\n")
      -- session/new succeeds
      stdout_cb(nil, vim.json.encode({ jsonrpc = "2.0", id = 3, result = { sessionId = "new-sess" } }) .. "\n")
      -- session/prompt succeeds
      stdout_cb(nil, vim.json.encode({ jsonrpc = "2.0", id = 4, result = {} }) .. "\n")
    end)

    vim.system, vim.schedule = old_system, old_schedule
    assert.is_true(ok, err)
    -- No error event should be emitted since we recovered
    assert.are.equal(1, #events)
    assert.are.same({ type = "session", session = "new-sess" }, events[1])
    -- Verify the retry sequence: prompt(old) → new → prompt(new)
    assert.is_truthy(writes[2]:find('"sessionId":"old%-sess"'))
    assert.is_truthy(writes[3]:find('"method":"session/new"'))
    assert.is_truthy(writes[4]:find('"sessionId":"new%-sess"'))
  end)
end)
