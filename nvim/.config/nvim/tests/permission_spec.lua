local perm = require("code-agents.permission")

describe("classify", function()
  it("auto-allows read-only tools", function()
    assert.are.equal("allow", perm.classify("Read"))
    assert.are.equal("allow", perm.classify("Grep"))
    assert.are.equal("allow", perm.classify("Glob"))
  end)

  it("auto-allows file edits (safe — agent works in an isolated worktree)", function()
    assert.are.equal("allow", perm.classify("Edit"))
    assert.are.equal("allow", perm.classify("Write"))
    assert.are.equal("allow", perm.classify("MultiEdit"))
    assert.are.equal("allow", perm.classify("NotebookEdit"))
  end)

  it("still asks for shell / unknown tools (Bash can escape the worktree)", function()
    assert.are.equal("ask", perm.classify("Bash"))
    assert.are.equal("ask", perm.classify("SomethingUnknown"))
  end)
end)

describe("parse_hook_input", function()
  it("extracts tool name + input from the PreToolUse stdin JSON", function()
    local r = perm.parse_hook_input(
      '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"rm x"},"session_id":"s1","cwd":"/tmp"}')
    assert.are.equal("Bash", r.tool)
    assert.are.equal("rm x", r.input.command)
    assert.are.equal("s1", r.session)
  end)

  it("returns nil on garbage", function()
    assert.is_nil(perm.parse_hook_input("not json"))
  end)
end)

describe("matches_allow (reuse claude's pre-approvals)", function()
  it("allows a Bash command matching a glob rule", function()
    assert.is_true(perm.matches_allow("Bash", { command = "git status -s" }, { "Bash(git status*)" }))
    assert.is_true(perm.matches_allow("Bash", { command = "rg foo bar" }, { "Bash(rg:*)" }))
  end)

  it("rejects a Bash command that doesn't match any rule", function()
    assert.is_false(perm.matches_allow("Bash", { command = "rm -rf /" }, { "Bash(git status*)" }))
  end)

  it("allows a bare tool-name rule and scopes Bash rules to Bash", function()
    assert.is_true(perm.matches_allow("Read", {}, { "Read" }))
    assert.is_false(perm.matches_allow("Read", {}, { "Bash(git status*)" }))
  end)
end)

describe("parse_allow_rules", function()
  it("extracts permissions.allow", function()
    assert.are.same({ "Bash(git status*)", "Read" },
      perm.parse_allow_rules('{"permissions":{"allow":["Bash(git status*)","Read"]}}'))
  end)

  it("returns empty on missing/garbage", function()
    assert.are.same({}, perm.parse_allow_rules("nope"))
    assert.are.same({}, perm.parse_allow_rules('{"other":1}'))
  end)

  it("load_allow_rules reads + merges rules from settings files (missing files skipped)", function()
    local p = vim.fn.tempname()
    vim.fn.writefile({ '{"permissions":{"allow":["Bash(rg:*)","Read"]}}' }, p)
    perm.allow_rules = {}
    perm.load_allow_rules({ p, "/no/such/settings.json" })
    assert.is_true(vim.tbl_contains(perm.allow_rules, "Bash(rg:*)"))
    assert.is_true(vim.tbl_contains(perm.allow_rules, "Read"))
    vim.fn.delete(p)
  end)
end)

describe("request / resolve_pending (async)", function()
  local function reqfile(tbl)
    local p = vim.fn.tempname()
    vim.fn.writefile({ vim.json.encode(tbl) }, p)
    return p
  end
  before_each(function()
    perm._reset(); perm.allow_rules = {}
    perm._notify_pending = function() end -- silence the notify/attach shell
  end)

  it("auto-allows without registering a pending request", function()
    local out = perm.request(reqfile({ tool_name = "Grep", tool_input = {} }))
    assert.are.equal("allow", vim.json.decode(out).hookSpecificOutput.permissionDecision)
    assert.are.equal(0, #perm.pending)
  end)

  it("registers a pending request and returns a PENDING sentinel for new tools", function()
    local out = perm.request(reqfile({ tool_name = "Bash", tool_input = { command = "rm x" }, session_id = "s1" }))
    assert.is_truthy(out:find("^PENDING:"))
    assert.are.equal(1, #perm.pending)
    assert.are.equal("Bash", perm.pending[1].tool)
  end)

  it("resolve_pending writes an allow decision file and clears the entry", function()
    perm.request(reqfile({ tool_name = "Bash", tool_input = { command = "ls" }, session_id = "s1" }))
    local entry = perm.pending[1]
    perm.resolve_pending(entry, "once")
    assert.are.equal("allow", vim.json.decode(vim.fn.readfile(entry.decisionfile)[1]).hookSpecificOutput.permissionDecision)
    assert.are.equal(0, #perm.pending)
  end)

  it("resolve_pending 'improve' writes deny + feedback", function()
    perm.request(reqfile({ tool_name = "Bash", tool_input = { command = "rm x" }, session_id = "s1" }))
    local entry = perm.pending[1]
    perm.resolve_pending(entry, "improve", "use a Map")
    local d = vim.json.decode(vim.fn.readfile(entry.decisionfile)[1]).hookSpecificOutput
    assert.are.equal("deny", d.permissionDecision)
    assert.are.equal("use a Map", d.permissionDecisionReason)
  end)
end)

describe("request_key", function()
  it("is stable for the same tool+input and distinct across commands", function()
    local a = perm.request_key("Bash", { command = "npm test" })
    local b = perm.request_key("Bash", { command = "npm test" })
    local c = perm.request_key("Bash", { command = "rm -rf /" })
    assert.are.equal(a, b)
    assert.are_not.equal(a, c)
  end)
end)

describe("resolve_auto (silent-allow vs notify)", function()
  before_each(function() perm._reset(); perm.allow_rules = {} end)

  it("auto-allows read-only tools", function()
    assert.is_true(perm.resolve_auto("Grep", {}))
  end)

  it("auto-allows a session-remembered command", function()
    perm.session_allow[perm.request_key("Bash", { command = "ls" })] = true
    assert.is_true(perm.resolve_auto("Bash", { command = "ls" }))
  end)

  it("auto-allows a claude-allowlisted command", function()
    perm.allow_rules = { "Bash(git status*)" }
    assert.is_true(perm.resolve_auto("Bash", { command = "git status -s" }))
  end)

  it("does NOT auto-allow an un-approved shell command (→ notify the user)", function()
    assert.is_false(perm.resolve_auto("Bash", { command = "rm -rf /" }))
  end)
end)

describe("hook_output", function()
  it("emits the PreToolUse decision envelope claude expects", function()
    local decoded = vim.json.decode(perm.hook_output("allow"))
    assert.are.equal("PreToolUse", decoded.hookSpecificOutput.hookEventName)
    assert.are.equal("allow", decoded.hookSpecificOutput.permissionDecision)
  end)

  it("includes an optional reason", function()
    local decoded = vim.json.decode(perm.hook_output("deny", "user rejected"))
    assert.are.equal("deny", decoded.hookSpecificOutput.permissionDecision)
    assert.are.equal("user rejected", decoded.hookSpecificOutput.permissionDecisionReason)
  end)
end)
