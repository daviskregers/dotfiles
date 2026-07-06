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
