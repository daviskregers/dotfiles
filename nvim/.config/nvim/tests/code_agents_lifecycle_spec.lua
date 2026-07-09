-- Lifecycle tests: dispatch / stream accumulation / stop / remove / steer.
-- Stubs llm-agent.transport BEFORE core loads so no real process spawns; the
-- test drives on_event/on_exit synchronously to simulate a stream.
local fake = { runs = {}, handles = {} }
package.loaded["llm-agent.transport"] = {
  config = {},
  run = function(opts)
    table.insert(fake.runs, opts)
    local h = { killed = false }
    h.kill = function() h.killed = true end
    table.insert(fake.handles, h)
    return h
  end,
}
package.loaded["code-agents.core"] = nil
local core = require("code-agents.core")

local function force_claude_default()
  local p = vim.fn.tempname()
  vim.fn.writefile({ "claude" }, p)
  core.default_agent_file = p
  return p
end

local function reset_env()
  core._reset()
  fake.runs, fake.handles = {}, {}
  if fake._default_agent_file then vim.fn.delete(fake._default_agent_file) end
  fake._default_agent_file = force_claude_default()
end

local function last_run() return fake.runs[#fake.runs] end

describe("dispatch", function()
  before_each(reset_env)

  it("registers a running agent and launches one turn", function()
    local a = core.dispatch({ verb = "search", prompt = "find x" })
    assert.are.equal("running", a.status)
    assert.are.equal(1, #core.list())
    assert.are.equal("find x", last_run().prompt)
  end)

  it("accumulates text events and completes as done", function()
    local done
    local a = core.dispatch({ verb = "explain", prompt = "p",
      on_done = function(text, code) done = { text = text, code = code } end })
    last_run().on_event({ type = "text", text = "hel" })
    last_run().on_event({ type = "text", text = "lo" })
    last_run().on_exit(0, "")
    assert.are.equal("done", a.status)
    assert.are.same({ text = "hello", code = 0 }, done)
  end)

  it("uses a provided session id (so it's stable/resumable across restarts)", function()
    local a = core.dispatch({ verb = "command", prompt = "x", session = "uuid-abc" })
    assert.are.equal("uuid-abc", a.session)
    assert.are.equal("uuid-abc", last_run().session)
  end)

  it("runs in the given cwd (the agent's worktree)", function()
    core.dispatch({ verb = "command", prompt = "x", cwd = "/tmp/wt-xyz" })
    assert.are.equal("/tmp/wt-xyz", last_run().cwd)
  end)

  it("find_by_session locates an agent by its session id", function()
    local a = core.dispatch({ verb = "command", prompt = "x" })
    a.session = "sess-9"
    assert.are.equal(a, core.find_by_session("sess-9"))
    assert.is_nil(core.find_by_session("nope"))
  end)

  it("coalesces consecutive streaming chunks of the same kind (opencode token-streaming)", function()
    local a = core.dispatch({ verb = "ask", prompt = "p" })
    last_run().on_event({ type = "thinking", text = "The " })
    last_run().on_event({ type = "thinking", text = "user " })
    last_run().on_event({ type = "thinking", text = "wants" })
    last_run().on_event({ type = "text", text = "Answer " })
    last_run().on_event({ type = "text", text = "here" })
    local kinds = vim.tbl_map(function(e) return e.kind end, a.transcript)
    assert.are.same({ "you", "thinking", "text" }, kinds)      -- not 6 separate token entries
    assert.are.equal("The user wants", a.transcript[2].text)
    assert.are.equal("Answer here", a.transcript[3].text)
  end)

  it("coalesces tool_call updates by id into one entry (opencode sends call + updates)", function()
    local a = core.dispatch({ verb = "command", prompt = "p" })
    last_run().on_event({ type = "tool", id = "tc1", tool = "read", input = { cwd = "/x" } })
    last_run().on_event({ type = "tool", id = "tc1", tool = "read", input = { filePath = "/x/f.lua" } })
    last_run().on_event({ type = "tool", id = "tc1", tool = "/x/f.lua", input = { filePath = "/x/f.lua" } })
    local tools = vim.tbl_filter(function(e) return e.kind == "tool" end, a.transcript)
    assert.are.equal(1, #tools)                       -- one entry, not three
    assert.are.equal("read", tools[1].tool)           -- keeps the tool name
    assert.are.equal("/x/f.lua", tools[1].input.filePath) -- latest (fuller) input
  end)

  it("captures the session id from a session event", function()
    local a = core.dispatch({ verb = "search", prompt = "p" })
    last_run().on_event({ type = "session", session = "s1" })
    assert.are.equal("s1", a.session)
  end)

  it("non-zero exit marks the agent errored", function()
    local a = core.dispatch({ verb = "search", prompt = "p" })
    last_run().on_exit(1, "boom")
    assert.are.equal("error", a.status)
  end)
end)

describe("stop / remove", function()
  before_each(reset_env)

  it("stop kills the process, marks stopped, keeps the record", function()
    local a = core.dispatch({ verb = "search", prompt = "p" })
    core.stop(a.id)
    assert.is_true(fake.handles[1].killed)
    assert.are.equal("stopped", a.status)
    assert.is_nil(a.proc)
    assert.are.equal(1, #core.list())
  end)

  it("remove stops and drops from the list", function()
    local a = core.dispatch({ verb = "search", prompt = "p" })
    core.remove(a.id)
    assert.is_true(fake.handles[1].killed)
    assert.are.equal(0, #core.list())
    assert.is_nil(core.get(a.id))
  end)

  it("remove discards the agent's worktree (no orphan left behind)", function()
    local repo = vim.fn.tempname(); vim.fn.mkdir(repo, "p")
    local function git(...) vim.system({ "git", "-C", repo, ... }, {}):wait() end
    git("init", "-q"); git("config", "user.email", "t@t"); git("config", "user.name", "t")
    vim.fn.writefile({ "x" }, repo .. "/f.txt"); git("add", "-A"); git("commit", "-qm", "i")
    local wtpath = repo .. "/.wt/x"
    require("code-agents.worktree").create(repo, wtpath, "code-agents/x")

    local a = core.dispatch({ verb = "command", prompt = "p" })
    a.worktree, a.repo = wtpath, repo
    assert.are.equal(1, vim.fn.isdirectory(wtpath))
    core.remove(a.id)
    assert.are.equal(0, vim.fn.isdirectory(wtpath)) -- worktree gone
    vim.fn.delete(repo, "rf")
  end)

  it("remove_all clears everything", function()
    core.dispatch({ verb = "search", prompt = "a" })
    core.dispatch({ verb = "explain", prompt = "b" })
    assert.are.equal(2, #core.list())
    core.remove_all()
    assert.are.equal(0, #core.list())
  end)
end)

describe("steer", function()
  before_each(reset_env)

  it("resumes a finished agent's session with fresh output", function()
    local a = core.dispatch({ verb = "search", prompt = "first" })
    last_run().on_event({ type = "session", session = "s9" })
    last_run().on_event({ type = "text", text = "old" })
    last_run().on_exit(0, "")

    core.steer(a.id, "more context")
    local run = last_run()
    assert.is_true(run.resume)          -- resumes rather than fresh session
    assert.are.equal("s9", run.session) -- threads the captured session
    assert.are.equal("more context", run.prompt)
    assert.are.same({}, a.chunks)       -- prior output cleared for the new turn
    assert.are.equal("running", a.status)
  end)

  it("re-invokes the completion handler on steered turns (persisted from dispatch)", function()
    local calls = {}
    local a = core.dispatch({ verb = "search", prompt = "first",
      on_done = function(text, code) calls[#calls + 1] = { text = text, code = code } end })
    last_run().on_event({ type = "text", text = "hit1" })
    last_run().on_exit(0, "")
    core.steer(a.id, "refine")
    last_run().on_event({ type = "text", text = "hit2" })
    last_run().on_exit(0, "")
    assert.are.equal(2, #calls)               -- fired on both the original and steered turn
    assert.are.equal("hit2", calls[2].text)   -- steered turn's own output, not stale
  end)

  it("threads permit through to the transport and preserves it on steer", function()
    local a = core.dispatch({ verb = "command", prompt = "do x", permit = true })
    assert.is_true(last_run().permit)
    last_run().on_exit(0, "")
    core.steer(a.id, "more")
    assert.is_true(last_run().permit) -- steered turns stay permission-gated
  end)

  it("passes resume + session through on opencode steered turns", function()
    local acp_calls = {}
    package.loaded["llm-agent.acp"] = {
      run = function(opts)
        acp_calls[#acp_calls + 1] = opts
        return { kill = function() end }
      end,
    }
    package.loaded["code-agents.core"] = nil
    core = require("code-agents.core")
    force_claude_default()
    reset_env()

    local a = core.dispatch({ verb = "ask", provider = "opencode", prompt = "first" })
    a.session = "sess-42"
    a.proc = nil

    core.steer(a.id, "more")
    local run = acp_calls[#acp_calls]
    assert.is_true(run.resume)
    assert.are.equal("sess-42", run.session)
  end)

  it("fires on_update immediately when steer launches so the title flips to running", function()
    local a = core.dispatch({ verb = "ask", prompt = "first" })
    last_run().on_event({ type = "text", text = "answer" })
    last_run().on_exit(0, "")
    local refreshed = false
    a.on_update = function() refreshed = true end
    core.steer(a.id, "follow up")
    assert.is_true(refreshed)
    assert.are.equal("running", a.status)
  end)

  it("refuses to steer a busy (still-running) agent", function()
    local a = core.dispatch({ verb = "search", prompt = "p" }) -- no on_exit → busy
    local runs_before = #fake.runs
    core.steer(a.id, "x")
    assert.are.equal(runs_before, #fake.runs) -- no new turn launched
  end)

  it("reconstructs full conversation context for opencode steer so the LLM remembers", function()
    local acp_calls = {}
    package.loaded["llm-agent.acp"] = {
      run = function(opts)
        acp_calls[#acp_calls + 1] = opts
        return { kill = function() end }
      end,
    }
    package.loaded["code-agents.core"] = nil
    core = require("code-agents.core")
    force_claude_default()
    reset_env()

    local a = core.dispatch({ verb = "ask", provider = "opencode", prompt = "What is 2+2?" })
    -- simulate prior response in transcript (as ingest_event would do)
    a.transcript[#a.transcript + 1] = { kind = "text", text = "The answer is 4." }
    a.proc = nil

    core.steer(a.id, "What is 3+3?")
    local run = acp_calls[#acp_calls]
    assert.is_truthy(run.prompt:find("What is 2+2?", 1, true))
    assert.is_truthy(run.prompt:find("The answer is 4.", 1, true))
    assert.is_truthy(run.prompt:find("What is 3+3?", 1, true))
  end)
end)

describe("transcript", function()
  before_each(reset_env)

  local function kinds(a)
    return vim.tbl_map(function(e) return e.kind end, a.transcript)
  end

  it("records the prompt, thinking, tool calls and text in order", function()
    local a = core.dispatch({ verb = "explain", prompt = "explain foo" })
    last_run().on_event({ type = "thinking", text = "let me look" })
    last_run().on_event({ type = "tool", tool = "Grep", input = { pattern = "foo" } })
    last_run().on_event({ type = "text", text = "it does X" })
    assert.are.same({ "you", "thinking", "tool", "text" }, kinds(a))
    assert.are.equal("explain foo", a.transcript[1].text)
    assert.are.equal("Grep", a.transcript[3].tool)
  end)

  it("keeps chunks text-only (parse input excludes thinking/tool)", function()
    local a = core.dispatch({ verb = "search", prompt = "p" })
    last_run().on_event({ type = "thinking", text = "hmm" })
    last_run().on_event({ type = "tool", tool = "Read", input = {} })
    last_run().on_event({ type = "text", text = "src/a.lua:1:1: hit" })
    assert.are.equal("src/a.lua:1:1: hit", table.concat(a.chunks))
  end)

  it("invokes the agent's on_update hook as the transcript grows (live view)", function()
    local a = core.dispatch({ verb = "explain", prompt = "p" })
    local n = 0
    a.on_update = function() n = n + 1 end
    last_run().on_event({ type = "thinking", text = "mm" })
    last_run().on_event({ type = "text", text = "hi" })
    assert.is_true(n >= 2)
  end)

  it("steer preserves the transcript and appends a new turn", function()
    local a = core.dispatch({ verb = "explain", prompt = "first" })
    last_run().on_event({ type = "text", text = "answer one" })
    last_run().on_exit(0, "")
    core.steer(a.id, "follow up")
    assert.are.same({ "you", "text", "you" }, kinds(a))
    assert.are.equal("follow up", a.transcript[3].text)
    assert.are.same({}, a.chunks) -- fresh parse buffer for the new turn
  end)
end)

describe("transcript persistence", function()
  before_each(reset_env)

  it("persists entries and reloads them (survives an nvim restart)", function()
    core.logs_dir = vim.fn.tempname()
    core.persist_entry("sess-x", { kind = "you", text = "add a button" })
    core.persist_entry("sess-x", { kind = "text", text = "did it" })
    local t = core.load_transcript("sess-x")
    assert.are.equal(2, #t)
    assert.are.equal("add a button", t[1].text)
    assert.are.equal("text", t[2].kind)
    vim.fn.delete(core.logs_dir, "rf"); core.logs_dir = nil
  end)
end)

describe("parse_worktree_name", function()
  it("strips a known provider prefix; else falls back to the default provider", function()
    local p, s = core.parse_worktree_name("opencode-ef16-ab-cd")
    assert.are.equal("opencode", p); assert.are.equal("ef16-ab-cd", s)
    p, s = core.parse_worktree_name("claude-x-y")
    assert.are.equal("claude", p); assert.are.equal("x-y", s)
    p, s = core.parse_worktree_name("plain-uuid-here") -- "plain" isn't a provider
    assert.are.equal(core.default_provider, p); assert.are.equal("plain-uuid-here", s)
  end)
end)

describe("reattach", function()
  before_each(reset_env)

  it("reconstructs agents from existing worktrees + restores their transcript", function()
    local root = vim.fn.tempname()
    vim.fn.mkdir(root .. "/platform/sess-aaa", "p")
    vim.fn.mkdir(root .. "/platform/sess-bbb", "p")
    core.logs_dir = vim.fn.tempname()
    core.persist_entry("sess-aaa", { kind = "you", text = "wire up the button" })
    local n = core.reattach("/repos/platform", root)
    assert.are.equal(2, n)
    local a = core.find_by_session("sess-aaa")
    assert.is_not_nil(a)
    assert.are.equal("stopped", a.status)
    assert.is_truthy(a.worktree:find("sess-aaa", 1, true))
    assert.are.equal("wire up the button", a.transcript[1].text) -- restored what it was for
    vim.fn.delete(root, "rf"); vim.fn.delete(core.logs_dir, "rf"); core.logs_dir = nil
  end)

  it("is a no-op when the worktree dir doesn't exist", function()
    assert.are.equal(0, core.reattach("/repos/platform", vim.fn.tempname()))
  end)

  it("restores the persisted seed so post-restart review diffs against the ORIGINAL base", function()
    local root = vim.fn.tempname()
    vim.fn.mkdir(root .. "/platform/claude-sess-ccc", "p")
    core.logs_dir = vim.fn.tempname()
    core.save_seed("claude-sess-ccc", "abc123seed") -- captured at dispatch, before restart
    core.reattach("/repos/platform", root)
    local a = core.find_by_session("sess-ccc")
    assert.is_not_nil(a)
    assert.are.equal("abc123seed", a.seed) -- else diff falls back to HEAD → empty when agent committed
    vim.fn.delete(root, "rf"); vim.fn.delete(core.logs_dir, "rf"); core.logs_dir = nil
  end)
end)

describe("turn-complete attention", function()
  before_each(reset_env)

  it("completes opencode turns on on_done so the agent is steerable again", function()
    local acp_calls = {}
    package.loaded["llm-agent.acp"] = {
      run = function(opts)
        acp_calls[#acp_calls + 1] = opts
        return { kill = function() end }
      end,
    }
    package.loaded["code-agents.core"] = nil
    core = require("code-agents.core")
    reset_env()

    local a = core.dispatch({ verb = "command", provider = "opencode", prompt = "x" })
    local run = acp_calls[#acp_calls]
    run.on_done()
    assert.are.equal("done", a.status)
    assert.is_nil(a.proc) -- steerable again
    -- on_exit is a no-op when already done (guard prevents double-completion)
    run.on_exit(0)
    assert.are.equal("done", a.status)
  end)

  it("notifies when an interactive agent's turn completes", function()
    local msgs, orig = {}, vim.notify
    vim.notify = function(m) msgs[#msgs + 1] = m end
    core.dispatch({ verb = "command", prompt = "x" })
    last_run().on_exit(0, "")
    vim.notify = orig
    assert.is_true(#msgs >= 1)
  end)

  it("does not notify for search (the quickfix is the signal)", function()
    local msgs, orig = {}, vim.notify
    vim.notify = function(m) msgs[#msgs + 1] = m end
    core.dispatch({ verb = "search", prompt = "x", on_done = function() end })
    last_run().on_exit(0, "")
    vim.notify = orig
    assert.are.equal(0, #msgs)
  end)
end)

describe("error surfacing", function()
  before_each(reset_env)

  it("records stderr in the transcript on non-zero exit", function()
    local a = core.dispatch({ verb = "search", prompt = "p" })
    last_run().on_exit(1, "rg: command failed")
    assert.are.equal("error", a.status)
    local last = a.transcript[#a.transcript]
    assert.are.equal("error", last.kind)
    assert.is_truthy(last.text:find("rg: command failed", 1, true))
  end)

  it("marks error and records it if the process fails to spawn", function()
    local orig = package.loaded["llm-agent.transport"].run
    package.loaded["llm-agent.transport"].run = function() error("ENOENT llm-run") end
    local a = core.dispatch({ verb = "search", prompt = "p" })
    package.loaded["llm-agent.transport"].run = orig
    assert.are.equal("error", a.status)
    assert.are.equal("error", a.transcript[#a.transcript].kind)
    assert.is_truthy(a.transcript[#a.transcript].text:find("ENOENT", 1, true))
  end)
end)

describe("counts", function()
  before_each(reset_env)

  it("tallies by status", function()
    local a = core.dispatch({ verb = "search", prompt = "p" })
    core.dispatch({ verb = "explain", prompt = "q" })
    core.stop(a.id)
    local c = core.counts()
    assert.are.equal(1, c.running)
    assert.are.equal(1, c.stopped)
  end)
end)
