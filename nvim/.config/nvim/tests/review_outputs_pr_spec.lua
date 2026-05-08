local pr_out = require("custom.review.outputs.pr")

local function notes_fixture()
  return {
    { file = "src/a.lua", start_line = 5, end_line = 5, text = "fix this" },
    { file = "lib/b.go", start_line = 10, end_line = 12, text = "refactor block" },
  }
end

describe("review.outputs.pr", function()
  local original_runner

  before_each(function() original_runner = pr_out._runner end)
  after_each(function() pr_out._runner = original_runner end)

  it("returns posted map keyed by note.id with pr_comment_id from response", function()
    pr_out._runner = function(a)
      if a[1] == "pr" and a[2] == "view" then return "sha\n" end
      -- Simulate a successful inline POST response
      return vim.json.encode({ id = 9999, body = "fix this", path = "src/a.lua" })
    end
    local notes = {
      { id = "n_local", file = "src/a.lua", start_line = 5, end_line = 5, text = "fix this" },
    }
    local res = pr_out.push(notes, { pr = "https://github.com/o/r/pull/1" })
    assert.is_table(res.posted)
    assert.equals(9999, res.posted["n_local"].pr_comment_id)
    assert.equals("original", res.posted["n_local"].kind)
  end)

  it("returns failures map keyed by note.id when reply post fails", function()
    pr_out._runner = function(a)
      if a[1] == "pr" and a[2] == "view" then return "sha\n" end
      return nil  -- every reply/inline POST fails
    end
    local res = pr_out.push({
      { id = "n_reply", kind = "reply", file = "a.lua", start_line = 1, end_line = 1, text = "r", replies_to_id = 999 },
    }, { pr = "https://github.com/o/r/pull/1" })
    assert.is_false(res.ok)
    assert.is_table(res.failures)
    assert.is_string(res.failures["n_reply"])
    assert.matches("reply", res.failures["n_reply"])
  end)

  it("returns failures map for inline-fallback when both reject", function()
    pr_out._runner = function(a)
      if a[1] == "pr" and a[2] == "view" then return "sha\n" end
      return nil  -- inline + issue fallback both fail
    end
    local res = pr_out.push({
      { id = "n_local", file = "x.lua", start_line = 1, end_line = 1, text = "x" },
    }, { pr = "https://github.com/o/r/pull/1" })
    assert.is_false(res.ok)
    assert.is_string(res.failures["n_local"])
  end)

  it("does NOT mark a note as failed when issue fallback rescues it", function()
    local call_n = 0
    pr_out._runner = function(a)
      call_n = call_n + 1
      if a[1] == "pr" and a[2] == "view" then return "sha\n" end
      -- inline POST fails (call 2), issue-fallback succeeds (call 3)
      if call_n == 2 then return nil end
      return "{}"
    end
    local res = pr_out.push({
      { id = "n_fallback", file = "x.lua", start_line = 1, end_line = 1, text = "x" },
    }, { pr = "https://github.com/o/r/pull/1" })
    assert.is_true(res.ok)
    assert.is_nil((res.failures or {})["n_fallback"])
    assert.is_truthy((res.posted or {})["n_fallback"])
  end)

  it("skips notes already marked pushed (idempotent)", function()
    local invocations = {}
    pr_out._runner = function(a)
      table.insert(invocations, a)
      if a[1] == "pr" and a[2] == "view" then return "sha\n" end
      return "{}"
    end
    local res = pr_out.push({
      { id = "n1", kind = "original", file = "a.lua", start_line = 1, end_line = 1, text = "skip" },
      { id = "n2", pushed = true,     file = "b.lua", start_line = 2, end_line = 2, text = "also skip" },
      { id = "n3",                    file = "c.lua", start_line = 3, end_line = 3, text = "post" },
    }, { pr = "https://github.com/o/r/pull/1" })
    assert.equals(1, res.count)
    -- 1 head-sha + 1 inline POST; not 3 posts
    assert.equals(2, #invocations)
  end)

  it("posts each note as an individual review comment with commit_id", function()
    local invocations = {}
    pr_out._runner = function(a)
      table.insert(invocations, a)
      -- First call resolves head SHA
      if a[1] == "pr" and a[2] == "view" then return "abc123sha\n" end
      return "{}"
    end
    pr_out.push(notes_fixture(), { pr = "https://github.com/o/r/pull/1" })

    -- 1 head-sha lookup + 2 inline comments
    assert.equals(3, #invocations)
    -- Inline comment POSTs hit /pulls/N/comments
    assert.equals("repos/o/r/pulls/1/comments", invocations[2][2])
    -- Args contain commit_id, path, body, side, line
    local joined = table.concat(invocations[2], " ")
    assert.matches("commit_id=abc123sha", joined)
    assert.matches("path=src/a%.lua", joined)
    assert.matches("body=fix this", joined)
    assert.matches("side=RIGHT", joined)
    assert.matches("line=5", joined)
  end)

  it("range notes include start_line and start_side", function()
    pr_out._runner = function(a)
      if a[1] == "pr" and a[2] == "view" then return "sha\n" end
      return "{}"
    end
    -- Call directly to inspect args of the range-note POST
    local invocations = {}
    pr_out._runner = function(a)
      table.insert(invocations, a)
      if a[1] == "pr" and a[2] == "view" then return "sha\n" end
      return "{}"
    end
    pr_out.push({
      { file = "lib/b.go", start_line = 10, end_line = 12, text = "block" },
    }, { pr = "https://github.com/o/r/pull/1" })
    -- skip head-sha invocation
    local args = invocations[2]
    local joined = table.concat(args, " ")
    assert.matches("start_line=10", joined)
    assert.matches("line=12", joined)
    assert.matches("start_side=RIGHT", joined)
  end)

  it("returns ok with count when runner succeeds", function()
    pr_out._runner = function() return "" end
    local res = pr_out.push(notes_fixture(), { pr = "https://github.com/o/r/pull/1" })
    assert.is_true(res.ok)
    assert.equals(2, res.count)
  end)

  it("returns not-ok when runner returns nil (gh failed)", function()
    pr_out._runner = function() return nil end
    local res = pr_out.push(notes_fixture(), { pr = "https://github.com/o/r/pull/1" })
    assert.is_false(res.ok)
  end)

  it("requires a pr in opts; refuses without one", function()
    local called = false
    pr_out._runner = function() called = true; return "" end
    local res = pr_out.push(notes_fixture(), {})
    assert.is_false(res.ok)
    assert.is_false(called)
  end)

  it("handles empty notes list (no runner call)", function()
    local called = false
    pr_out._runner = function() called = true; return "" end
    local res = pr_out.push({}, { pr = "x" })
    assert.is_true(res.ok)
    assert.equals(0, res.count)
    assert.is_false(called)
  end)

  it("skips notes with kind=original (already on server)", function()
    local called = false
    pr_out._runner = function() called = true; return "" end
    local res = pr_out.push({
      { kind = "original", file = "a.lua", start_line = 1, end_line = 1, text = "x", pr_comment_id = 1 },
    }, { pr = "https://github.com/o/r/pull/1" })
    assert.is_true(res.ok)
    assert.equals(0, res.count)
    assert.is_false(called)
  end)

  it("posts each reply via /pulls/N/comments/<id>/replies", function()
    local invocations = {}
    pr_out._runner = function(a) table.insert(invocations, a); return "{}" end
    local res = pr_out.push({
      { kind = "reply", file = "a.lua", start_line = 1, end_line = 1, text = "thanks", replies_to_id = 999 },
    }, { pr = "https://github.com/o/r/pull/42" })
    assert.is_true(res.ok)
    assert.equals(1, res.count)
    assert.equals(1, #invocations)
    -- args = { "api", "repos/o/r/pulls/42/comments/999/replies", "-X", "POST", "-f", "body=thanks" }
    assert.equals("api", invocations[1][1])
    assert.equals("repos/o/r/pulls/42/comments/999/replies", invocations[1][2])
    assert.is_true(vim.list_contains(invocations[1], "POST"))
    -- body=thanks should appear
    local found_body = false
    for _, v in ipairs(invocations[1]) do
      if v == "body=thanks" then found_body = true; break end
    end
    assert.is_true(found_body)
  end)

  it("loaded + local notes get one inline POST each", function()
    local invocations = {}
    pr_out._runner = function(a)
      table.insert(invocations, a)
      if a[1] == "pr" and a[2] == "view" then return "sha\n" end
      return "{}"
    end
    local res = pr_out.push({
      { kind = "loaded", file = "x.lua", start_line = 1, end_line = 1, text = "from md" },
      { kind = "local",  file = "y.lua", start_line = 2, end_line = 2, text = "fresh" },
    }, { pr = "https://github.com/o/r/pull/1" })
    assert.is_true(res.ok)
    assert.equals(2, res.count)
    -- 1 head-sha lookup + 2 individual comment POSTs
    assert.equals(3, #invocations)
    assert.equals("repos/o/r/pulls/1/comments", invocations[2][2])
    assert.equals("repos/o/r/pulls/1/comments", invocations[3][2])
  end)

  it("mixed kinds: replies POSTed individually, locals via inline endpoint, originals skipped", function()
    local invocations = {}
    pr_out._runner = function(a)
      table.insert(invocations, a)
      if a[1] == "pr" and a[2] == "view" then return "sha\n" end
      return "{}"
    end
    local res = pr_out.push({
      { kind = "original", file = "a.lua", start_line = 1, end_line = 1, text = "skip", pr_comment_id = 1 },
      { kind = "reply",    file = "a.lua", start_line = 1, end_line = 1, text = "r1",   replies_to_id = 1 },
      { kind = "reply",    file = "a.lua", start_line = 1, end_line = 1, text = "r2",   replies_to_id = 2 },
      { kind = "local",    file = "b.lua", start_line = 5, end_line = 5, text = "new" },
    }, { pr = "https://github.com/o/r/pull/3" })
    assert.is_true(res.ok)
    assert.equals(3, res.count) -- 2 replies + 1 inline (original skipped)
    -- 2 reply POSTs + 1 head-sha lookup + 1 inline POST = 4 invocations
    assert.equals(4, #invocations)
  end)
end)
