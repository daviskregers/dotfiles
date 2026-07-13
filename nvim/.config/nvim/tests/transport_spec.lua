local t = require("llm-agent.transport")

describe("build_cmd", function()
  before_each(function() t.config.llm_run = "llm-run" end)

  it("minimal: provider + prompt", function()
    assert.are.same({ "llm-run", "claude", "--", "hi" },
      t.build_cmd({ provider = "claude", prompt = "hi" }))
  end)

  it("threads model, agent, session, resume in order", function()
    assert.are.same(
      { "llm-run", "claude", "-m", "opus", "--agent", "rev", "--session", "s1", "--resume", "--", "go" },
      t.build_cmd({ provider = "claude", model = "opus", agent = "rev",
        session = "s1", resume = true, prompt = "go" }))
  end)

  it("permit=true passes --permit through to llm-run (provider translates it)", function()
    local cmd = t.build_cmd({ provider = "claude", prompt = "go", permit = true })
    assert.is_truthy(vim.tbl_contains(cmd, "--permit"))
  end)

  it("omits --permit when not requested", function()
    assert.is_falsy(vim.tbl_contains(t.build_cmd({ provider = "claude", prompt = "x" }), "--permit"))
  end)

  it("omits empty optional flags", function()
    assert.are.same({ "llm-run", "opencode", "--", "x" },
      t.build_cmd({ provider = "opencode", model = "", agent = "", session = "", prompt = "x" }))
  end)

  it("threads effort after model (provider-agnostic; llm-run maps per provider)", function()
    assert.are.same(
      { "llm-run", "claude", "-m", "opus", "--effort", "high", "--", "go" },
      t.build_cmd({ provider = "claude", model = "opus", effort = "high", prompt = "go" }))
  end)

  it("omits --effort when unset or empty", function()
    assert.is_falsy(vim.tbl_contains(t.build_cmd({ provider = "opencode", prompt = "x" }), "--effort"))
    assert.is_falsy(vim.tbl_contains(
      t.build_cmd({ provider = "claude", effort = "", prompt = "x" }), "--effort"))
  end)
end)

describe("parse_event", function()
  it("decodes a typed json line", function()
    assert.are.same({ type = "text", text = "hello" },
      t.parse_event('{"type":"text","text":"hello"}'))
  end)

  it("returns nil for blank / garbage / typeless", function()
    assert.is_nil(t.parse_event(""))
    assert.is_nil(t.parse_event("not json"))
    assert.is_nil(t.parse_event('{"no":"type"}'))
  end)
end)

describe("status_from_event", function()
  it("maps event types to status", function()
    assert.are.equal("running", t.status_from_event({ type = "text" }))
    assert.are.equal("running", t.status_from_event({ type = "tool" }))
    assert.are.equal("done", t.status_from_event({ type = "done" }))
    assert.are.equal("error", t.status_from_event({ type = "error" }))
    assert.is_nil(t.status_from_event({ type = "session" }))
  end)
end)
