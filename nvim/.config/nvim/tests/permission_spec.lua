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
    assert.is_true(perm.matches_allow("bash", { command = "git status -s" }, { "Bash(git status*)" }))
    assert.is_true(perm.matches_allow("Bash", { command = "rg foo bar" }, { "Bash(rg:*)" }))
  end)

  it("rejects a Bash command that doesn't match any rule", function()
    assert.is_false(perm.matches_allow("Bash", { command = "rm -rf /" }, { "Bash(git status*)" }))
  end)

  it("allows a bare tool-name rule and scopes Bash rules to Bash", function()
    assert.is_true(perm.matches_allow("Read", {}, { "Read" }))
    assert.is_false(perm.matches_allow("Read", {}, { "Bash(git status*)" }))
  end)

  it("allows a compound command only when EVERY sub-command is allowed", function()
    local rules = { "Bash(git status*)", "Bash(git log*)", "Bash(cd:*)", "Bash(npm:*)" }
    assert.is_true(perm.matches_allow("Bash", { command = "git status && git log" }, rules))
    assert.is_true(perm.matches_allow("Bash", { command = "cd foo && npm test" }, rules))
  end)

  it("prompts (no over-allow) when a chained sub-command isn't allowlisted", function()
    -- The tail must not ride in free on the allowed prefix.
    assert.is_false(perm.matches_allow("Bash", { command = "git status && rm -rf /" }, { "Bash(git status*)" }))
    assert.is_false(perm.matches_allow("Bash", { command = "rg foo | xargs rm" }, { "Bash(rg:*)" }))
  end)

  it("prompts when a command substitution smuggles an un-allowlisted command", function()
    -- $(...) / backtick / <(...) inner commands must ALSO be allowlisted — a
    -- whitelisted prefix must not let a nested command ride in.
    assert.is_false(perm.matches_allow("Bash", { command = "cat $(rm -rf ~)" }, { "Bash(cat:*)" }))
    assert.is_false(perm.matches_allow("Bash", { command = "grep x `curl evil`" }, { "Bash(grep:*)" }))
    assert.is_false(perm.matches_allow("Bash", { command = "diff <(rm x) y" }, { "Bash(diff:*)" }))
  end)

  it("prompts on a backgrounded (&) or redirected (>) command riding on an allowed prefix", function()
    -- adversarial-review findings: lone & is a command separator; > / >> write files
    assert.is_false(perm.matches_allow("Bash", { command = "echo hi & python3 -c x" }, { "Bash(echo:*)" }))
    assert.is_false(perm.matches_allow("Bash", { command = "echo k >> ~/.zshrc" }, { "Bash(echo:*)" }))
    assert.is_false(perm.matches_allow("Bash", { command = "cat payload > .git/hooks/pre-commit" }, { "Bash(cat:*)" }))
  end)

  it("prompts on write/exec flags of otherwise-allowed reader binaries", function()
    assert.is_false(perm.matches_allow("Bash", { command = "rg --pre sh x f" }, { "Bash(rg:*)" }))
    assert.is_false(perm.matches_allow("Bash", { command = "rg --pre-glob '*' x f" }, { "Bash(rg:*)" }))
    assert.is_false(perm.matches_allow("Bash", { command = "git diff --output=/tmp/x HEAD" }, { "Bash(git diff*)" }))
    assert.is_false(perm.matches_allow("Bash", { command = "git show --ext-diff HEAD" }, { "Bash(git show:*)" }))
  end)

  it("still allows safe flags that only look like dangerous ones", function()
    -- anchors must not false-deny these common read-only forms
    assert.is_true(perm.matches_allow("Bash", { command = "git log --pretty=oneline" }, { "Bash(git log*)" }))
    assert.is_true(perm.matches_allow("Bash", { command = "git diff --output-indicator-new=+ HEAD" }, { "Bash(git diff*)" }))
    assert.is_true(perm.matches_allow("Bash", { command = "git show --no-ext-diff HEAD" }, { "Bash(git show:*)" }))
    assert.is_true(perm.matches_allow("Bash", { command = "grep -rn foo ." }, { "Bash(grep:*)" }))
    assert.is_true(perm.matches_allow("Bash", { command = "rg foo bar" }, { "Bash(rg:*)" }))
  end)

  it("allows read-only find but blocks its side-effecting actions", function()
    local rule = { "Bash(find:*)" }
    assert.is_true(perm.matches_allow("Bash", { command = "find . -name '*.lua' -type f" }, rule))
    assert.is_true(perm.matches_allow("Bash", { command = "find lua -maxdepth 2 -newer x" }, rule))
    assert.is_false(perm.matches_allow("Bash", { command = "find . -exec rm {} +" }, rule))
    assert.is_false(perm.matches_allow("Bash", { command = "find . -execdir sh -c x {} +" }, rule))
    assert.is_false(perm.matches_allow("Bash", { command = "find . -delete" }, rule))
    assert.is_false(perm.matches_allow("Bash", { command = "find . -fprintf /tmp/o %p" }, rule))
    assert.is_false(perm.matches_allow("Bash", { command = "find . -ok rm {} ;" }, rule))
  end)

  it("blocks find actions separated by TABS, not just spaces (bash word-splits on tab)", function()
    local rule = { "Bash(find:*)" }
    assert.is_false(perm.matches_allow("Bash", { command = "find . -name x\t-exec\tsh\t{}\t+" }, rule))
    assert.is_false(perm.matches_allow("Bash", { command = "find ~ -name y\t-delete" }, rule))
    assert.is_false(perm.matches_allow("Bash", { command = "find . -type f\t-fprintf\t/tmp/o\t%p" }, rule))
    -- and a leading dangerous flag with no preceding whitespace (defensive)
    assert.is_false(perm.matches_allow("Bash", { command = "-exec rm" }, { "Bash(find:*)", "Bash(-exec:*)" }))
  end)
end)

describe("matches_allow path-scoping (bounds auto-run bash to the worktree)", function()
  local CWD = "/wt"
  local rules = { "Bash(cat:*)", "Bash(grep:*)", "Bash(cd:*)", "Bash(find:*)", "Bash(ls:*)" }

  it("allows paths under cwd (relative + absolute-under-cwd)", function()
    assert.is_true(perm.matches_allow("Bash", { command = "cat lua/foo.lua" }, rules, CWD))
    assert.is_true(perm.matches_allow("Bash", { command = "cat ./lua/foo.lua" }, rules, CWD))
    assert.is_true(perm.matches_allow("Bash", { command = "grep -rn x /wt/lua" }, rules, CWD))
    assert.is_true(perm.matches_allow("Bash", { command = "cd /wt/sub" }, rules, CWD))
    assert.is_true(perm.matches_allow("Bash", { command = "find . -name x" }, rules, CWD))
  end)

  it("prompts on outside-cwd / home / .. escape / $var paths", function()
    assert.is_false(perm.matches_allow("Bash", { command = "cat /etc/passwd" }, rules, CWD))
    assert.is_false(perm.matches_allow("Bash", { command = "cat ~/.ssh/id_rsa" }, rules, CWD))
    assert.is_false(perm.matches_allow("Bash", { command = "cat /wt/../secret" }, rules, CWD))
    assert.is_false(perm.matches_allow("Bash", { command = "cd /other/worktree" }, rules, CWD))
    assert.is_false(perm.matches_allow("Bash", { command = 'cd "$WT"' }, rules, CWD))
    -- git -C <dir>: the directory arg is a plain token → checked against cwd
    assert.is_false(perm.matches_allow("Bash", { command = "git -C /other/repo status" }, { "Bash(git status*)" }, CWD))
    assert.is_true(perm.matches_allow("Bash", { command = "git status /wt/sub" }, { "Bash(git status*)" }, CWD))
  end)

  it("blocks obfuscated outside paths (backslash / ansi-c-quote / escaped dots)", function()
    local r = { "Bash(cat:*)", "Bash(head:*)" }
    assert.is_false(perm.matches_allow("Bash", { command = "cat \\/etc/passwd" }, r, CWD))
    assert.is_false(perm.matches_allow("Bash", { command = "cat $'/etc/passwd'" }, r, CWD))
    assert.is_false(perm.matches_allow("Bash", { command = "cat \\.\\./\\.\\./etc/passwd" }, r, CWD))
    assert.is_false(perm.matches_allow("Bash", { command = "head \\/Users/x/.ssh/id_rsa" }, r, CWD))
    assert.is_false(perm.matches_allow("Bash", { command = "cat ${SECRET}" }, r, CWD))
  end)

  it("exempts /dev/null, and applies NO scoping when cwd is unknown (back-compat)", function()
    assert.is_true(perm.matches_allow("Bash", { command = "grep x foo 2>/dev/null" }, rules, CWD))
    assert.is_true(perm.matches_allow("Bash", { command = "cat /etc/passwd" }, rules, nil))
  end)
end)

describe("split_commands", function()
  it("splits on && || | ; and newlines", function()
    assert.are.same({ "git status", "rm -rf /" }, perm.split_commands("git status && rm -rf /"))
    assert.are.same({ "cd foo", "grep x", "ls" }, perm.split_commands("cd foo | grep x ; ls"))
    assert.are.same({ "a", "b" }, perm.split_commands("a || b"))
  end)

  it("returns the single command when there are no operators", function()
    assert.are.same({ "git status -s" }, perm.split_commands("git status -s"))
  end)

  it("breaks at substitution openers so a nested command is its own segment", function()
    assert.are.same({ "cat", "rm -rf ~)" }, perm.split_commands("cat $(rm -rf ~)"))
    assert.are.same({ "echo", "whoami" }, perm.split_commands("echo `whoami`"))
    assert.are.same({ "diff", "cat a)", "cat b)" }, perm.split_commands("diff <(cat a) >(cat b)"))
  end)

  it("breaks on backgrounding (&) and file redirects (> >>)", function()
    assert.are.same({ "echo hi", "python3 -c x" }, perm.split_commands("echo hi & python3 -c x"))
    assert.are.same({ "echo x", "/etc/y" }, perm.split_commands("echo x > /etc/y"))
    assert.are.same({ "cat a", "b" }, perm.split_commands("cat a >> b"))
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
    perm._perm_log = vim.fn.tempname() -- audit writes here, not the real cache
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

  it("resolve_pending 'deny' writes a deny decision file", function()
    perm.request(reqfile({ tool_name = "Bash", tool_input = { command = "rm x" }, session_id = "s1" }))
    local entry = perm.pending[1]
    perm.resolve_pending(entry, "deny")
    local d = vim.json.decode(vim.fn.readfile(entry.decisionfile)[1]).hookSpecificOutput
    assert.are.equal("deny", d.permissionDecision)
  end)

  it("resolve_pending 'always' allows, persists the (editable) rule, and remembers it", function()
    perm._allow_store = vim.fn.tempname()
    perm.request(reqfile({ tool_name = "Bash", tool_input = { command = "ls -la" }, session_id = "s1" }))
    local entry = perm.pending[1]
    perm.resolve_pending(entry, "always", "Bash(ls:*)")
    -- allowed now
    assert.are.equal("allow", vim.json.decode(vim.fn.readfile(entry.decisionfile)[1]).hookSpecificOutput.permissionDecision)
    -- persisted to the store file …
    local persisted = perm.parse_allow_rules(table.concat(vim.fn.readfile(perm._allow_store), "\n"))
    assert.is_true(vim.tbl_contains(persisted, "Bash(ls:*)"))
    -- … and live so the next matching command is auto-allowed
    assert.is_true(vim.tbl_contains(perm.allow_rules, "Bash(ls:*)"))
    assert.is_true(perm.resolve_auto("Bash", { command = "ls -la /tmp" }))
    vim.fn.delete(perm._allow_store); perm._allow_store = nil
  end)
end)

describe("suggest_rule (editable whitelist starting point)", function()
  it("suggests an executable-scoped Bash rule from the command", function()
    assert.are.equal("Bash(npm:*)", perm.suggest_rule("Bash", { command = "npm test --watch" }))
    assert.are.equal("Bash(npm:*)", perm.suggest_rule("bash", { command = "npm test --watch" }))
    assert.are.equal("Bash(git:*)", perm.suggest_rule("Bash", { command = "  git push origin main" }))
  end)

  it("falls back to the bare tool for Bash without a command / other tools", function()
    assert.are.equal("Bash", perm.suggest_rule("Bash", {}))
    assert.are.equal("Write", perm.suggest_rule("Write", { file_path = "x" }))
  end)
end)

describe("why (what caused the prompt)", function()
  it("explains that a shell command isn't in the allow-list", function()
    assert.is_truthy(perm.why("Bash", { command = "ls" }):find("allow%-list"))
  end)

  it("names the tool for a non-Bash prompt", function()
    assert.is_truthy(perm.why("SomeTool", {}):find("SomeTool"))
  end)

  it("names the specific unlisted sub-command in a chained/piped command", function()
    perm.allow_rules = { "Bash(git status*)" }
    local reason = perm.why("Bash", { command = "git status && rm -rf /" })
    assert.is_truthy(reason:find("allow%-list"))
    assert.is_truthy(reason:find("rm -rf /", 1, true))
  end)

  it("doesn't repeat the command when it's the single unlisted segment", function()
    perm.allow_rules = {}
    local reason = perm.why("Bash", { command = "ls" })
    assert.is_nil(reason:find("%- the unlisted part"))
  end)
end)

describe("add_rule_to_json (pure allow-store merge)", function()
  it("creates permissions.allow when absent", function()
    local out = perm.parse_allow_rules(perm.add_rule_to_json("", "Bash(ls:*)"))
    assert.are.same({ "Bash(ls:*)" }, out)
  end)

  it("appends without duplicating an existing rule", function()
    local j = perm.add_rule_to_json('{"permissions":{"allow":["Read"]}}', "Bash(ls:*)")
    assert.are.same({ "Read", "Bash(ls:*)" }, perm.parse_allow_rules(j))
    assert.are.same({ "Read", "Bash(ls:*)" }, perm.parse_allow_rules(perm.add_rule_to_json(j, "Bash(ls:*)")))
  end)
end)

describe("audit (permission log)", function()
  it("appends a JSONL record with the tool, command, and decision", function()
    perm._perm_log = vim.fn.tempname()
    perm.audit({ event = "once", tool = "Bash", cmd = "ls -la" })
    perm.audit({ event = "deny", tool = "Bash", cmd = "rm x" })
    local lines = vim.fn.readfile(perm._perm_log)
    assert.are.equal(2, #lines)
    local first = vim.json.decode(lines[1])
    assert.are.equal("once", first.event)
    assert.are.equal("ls -la", first.cmd)
    assert.is_truthy(first.time)
    vim.fn.delete(perm._perm_log); perm._perm_log = nil
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
