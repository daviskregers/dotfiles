local core = require("code-agents.core")

describe("parse_search_results", function()
  it("parses path:line:col: reason lines into qf items", function()
    local out = core.parse_search_results(
      "src/foo.lua:42:7: defines the parser\nlib/bar.lua:3:1: entry point\n")
    assert.are.same({
      { filename = "src/foo.lua", lnum = 42, col = 7, text = "defines the parser" },
      { filename = "lib/bar.lua", lnum = 3, col = 1, text = "entry point" },
    }, out)
  end)

  it("defaults col to 1 when omitted (path:line: reason)", function()
    local out = core.parse_search_results("src/foo.lua:42: no column here\n")
    assert.are.same(
      { { filename = "src/foo.lua", lnum = 42, col = 1, text = "no column here" } }, out)
  end)

  it("ignores prose, blank lines, and code fences", function()
    local out = core.parse_search_results(
      "Here are the results:\n\n```\nsrc/foo.lua:1:1: real hit\n```\nHope that helps!\n")
    assert.are.same(
      { { filename = "src/foo.lua", lnum = 1, col = 1, text = "real hit" } }, out)
  end)

  it("returns empty list for no matches", function()
    assert.are.same({}, core.parse_search_results("nothing matches here\n"))
  end)
end)

describe("reload_changed", function()
  it("reloads externally-edited files into their open buffers (no manual :e)", function()
    local tmp = vim.fn.tempname()
    vim.fn.writefile({ "before" }, tmp)
    vim.cmd("edit " .. vim.fn.fnameescape(tmp))
    local buf = vim.api.nvim_get_current_buf()
    vim.fn.writefile({ "after" }, tmp) -- agent edits the file on disk
    core.reload_changed()
    assert.are.equal("after", vim.api.nvim_buf_get_lines(buf, 0, -1, false)[1])
    vim.cmd("bwipeout! " .. buf)
    vim.fn.delete(tmp)
  end)
end)

describe("to_qflist", function()
  it("populates the quickfix list from qf-shaped items", function()
    core.to_qflist({
      { filename = "src/foo.lua", lnum = 42, col = 7, text = "hit" },
    }, "test")
    local qf = vim.fn.getqflist()
    assert.are.equal(1, #qf)
    assert.are.equal(42, qf[1].lnum)
    assert.are.equal(7, qf[1].col)
    assert.are.equal("hit", qf[1].text)
    assert.are.equal("src/foo.lua", vim.fn.bufname(qf[1].bufnr))
  end)
end)

describe("model_for", function()
  it("resolves claude per-verb aliases", function()
    assert.are.equal("haiku", core.model_for("claude", "search"))
    assert.are.equal("sonnet", core.model_for("claude", "explain"))
    assert.are.equal("opus", core.model_for("claude", "command"))
  end)

  it("returns nil for unknown provider/verb (caller falls back to provider default)", function()
    assert.is_nil(core.model_for("opencode", "search"))
    assert.is_nil(core.model_for("claude", "bogus"))
  end)
end)

describe("on_search_complete", function()
  it("results found → open qflist and close the view", function()
    local r = core.on_search_complete("a/b.lua:1:1: hit\nc/d.lua:2:3: hit2", 0)
    assert.are.equal("qflist", r.action)
    assert.is_true(r.close)
    assert.are.equal(2, #r.items)
  end)

  it("no matches → notify empty, keep the view open", function()
    local r = core.on_search_complete("no matches here", 0)
    assert.are.equal("empty", r.action)
    assert.is_false(r.close)
  end)

  it("non-zero exit → error, keep the view open", function()
    local r = core.on_search_complete("", 1)
    assert.are.equal("error", r.action)
    assert.is_false(r.close)
  end)
end)

describe("render_transcript", function()
  it("never yields a line containing a newline (nvim_buf_set_lines contract)", function()
    local a = { status = "running", transcript = {
      { kind = "you", text = "line1\nline2" },
      { kind = "thinking", text = "th1\nth2" },
      { kind = "tool", tool = "Bash", input = { command = "ls\n-la" } },
      { kind = "text", text = "a\nb" },
    } }
    for _, line in ipairs(core.render_transcript(a)) do
      assert.is_nil(line:find("\n"))
    end
  end)

  it("labels turns and includes reasoning + answer", function()
    local a = { status = "done", transcript = {
      { kind = "you", text = "q" }, { kind = "thinking", text = "hmm" }, { kind = "text", text = "ans" },
    } }
    local joined = table.concat(core.render_transcript(a), "\n")
    assert.is_truthy(joined:find("you"))
    assert.is_truthy(joined:find("hmm"))
    assert.is_truthy(joined:find("ans"))
  end)

  it("shows a tool's target path incl. opencode's camelCase filePath", function()
    local a = { status = "running", transcript = { { kind = "tool", tool = "read", input = { filePath = "a/b.lua" } } } }
    assert.is_truthy(table.concat(core.render_transcript(a), "\n"):find("a/b.lua", 1, true))
  end)

  it("renders error entries with a ✗ marker", function()
    local a = { status = "error", transcript = { { kind = "error", text = "boom" } } }
    assert.is_truthy(table.concat(core.render_transcript(a), "\n"):find("boom", 1, true))
  end)

  it("surfaces a pending permission request in the transcript, in context", function()
    local a = { status = "awaiting", transcript = { { kind = "text", text = "let me run a command" } },
      pending = { tool = "Bash", input = { command = "rm -rf build" } } }
    local joined = table.concat(core.render_transcript(a), "\n")
    assert.is_truthy(joined:lower():find("permission"))
    assert.is_truthy(joined:find("rm %-rf build"))            -- the request, shown with the context above it
    assert.is_truthy(joined:lower():find("allow"))            -- how to decide, in-line
  end)

  it("appends a 'your turn' footer once the turn is finished", function()
    local a = { status = "done", transcript = { { kind = "you", text = "q" }, { kind = "text", text = "which one?" } } }
    assert.is_truthy(table.concat(core.render_transcript(a), "\n"):lower():find("reply"))
  end)

  it("shows no footer while still running", function()
    local a = { status = "running", transcript = { { kind = "text", text = "working" } } }
    assert.is_nil(table.concat(core.render_transcript(a), "\n"):lower():find("reply"))
  end)

  it("falls back to a status line when empty", function()
    assert.are.same({ "(no output — status: running)" },
      core.render_transcript({ status = "running", transcript = {} }))
  end)
end)

describe("resolve_model", function()
  it("prefers an explicit override", function()
    assert.are.equal("opus", core.resolve_model("claude", "search", "opus"))
  end)

  it("falls back to the per-verb default", function()
    assert.are.equal("haiku", core.resolve_model("claude", "search", nil))
    assert.are.equal("haiku", core.resolve_model("claude", "search", ""))
  end)

  it("falls back to the provider default when no per-verb default", function()
    core.config.providers.opencode.default_model = "gh/sonnet"
    assert.are.equal("gh/sonnet", core.resolve_model("opencode", "search", nil))
  end)
end)
