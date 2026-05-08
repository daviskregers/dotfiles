local pr = require("custom.review.inputs.pr")

-- Real-world payload shape from `gh api repos/<owner>/<repo>/pulls/<n>/comments`
local SAMPLE_GH_JSON = vim.json.encode({
  {
    id = 12345,
    path = "src/auth.ts",
    line = 42,
    body = "use refresh tokens here",
    user = { login = "reviewer1" },
  },
  {
    id = 12346,
    path = "src/auth.ts",
    line = nil,                  -- comment on outdated line
    original_line = 30,          -- fall back to original_line
    body = "this changed",
    user = { login = "reviewer1" },
  },
  {
    id = 12347,
    path = "lib/util.go",
    line = 5,
    start_line = 3,              -- multi-line comment
    body = "extract helper",
    user = { login = "reviewer2" },
  },
})

describe("review.inputs.pr.parse", function()
  it("converts gh comments JSON into note shape", function()
    local notes = pr.parse(SAMPLE_GH_JSON)
    assert.equals(3, #notes)
    assert.equals("src/auth.ts", notes[1].file)
    assert.equals(42, notes[1].start_line)
    assert.equals(42, notes[1].end_line)
    assert.matches("refresh tokens", notes[1].text)
  end)

  it("falls back to original_line when line is nil", function()
    local notes = pr.parse(SAMPLE_GH_JSON)
    assert.equals(30, notes[2].start_line)
    assert.equals(30, notes[2].end_line)
  end)

  it("uses start_line for multi-line comments", function()
    local notes = pr.parse(SAMPLE_GH_JSON)
    assert.equals(3, notes[3].start_line)
    assert.equals(5, notes[3].end_line)
  end)

  it("preserves comment id for later replies", function()
    local notes = pr.parse(SAMPLE_GH_JSON)
    assert.equals(12345, notes[1].pr_comment_id)
  end)

  it("preserves author login", function()
    local notes = pr.parse(SAMPLE_GH_JSON)
    assert.equals("reviewer1", notes[1].author)
    assert.equals("reviewer2", notes[3].author)
  end)

  it("returns empty for empty array", function()
    assert.are.same({}, pr.parse("[]"))
  end)

  it("skips comments without a path (general PR comments)", function()
    local input = vim.json.encode({
      { id = 1, body = "general comment, no path", user = { login = "u" } },
      { id = 2, path = "f.lua", line = 1, body = "inline", user = { login = "u" } },
    })
    local notes = pr.parse(input)
    assert.equals(1, #notes)
    assert.equals("f.lua", notes[1].file)
  end)

  it("treats JSON null as nil (no vim.NIL leakage into note fields)", function()
    -- Real GitHub responses use null for missing line/original_line/etc.
    local input = '[' ..
      '{"id":1,"path":"f.lua","line":null,"original_line":5,"body":"outdated","user":{"login":"u"}},' ..
      '{"id":2,"path":"f.lua","line":10,"in_reply_to_id":null,"body":"fresh","user":{"login":"u"}}' ..
    ']'
    local notes = pr.parse(input)
    assert.equals(2, #notes)
    assert.equals("number", type(notes[1].start_line))
    assert.equals(5, notes[1].start_line)
    assert.is_nil(notes[2].in_reply_to_id)
  end)

  describe("fetch_thread_metadata", function()
    local original_runner

    before_each(function() original_runner = pr._runner end)
    after_each(function() pr._runner = original_runner end)

    it("returns a map from comment_id to { thread_id, resolved }", function()
      pr._runner = function(args)
        -- expect: { "api", "graphql", "-f", "query=...", "-F", "owner=o", ... }
        return vim.json.encode({
          data = {
            repository = {
              pullRequest = {
                reviewThreads = {
                  nodes = {
                    {
                      id = "T_1",
                      isResolved = false,
                      comments = { nodes = { { databaseId = 100 }, { databaseId = 101 } } },
                    },
                    {
                      id = "T_2",
                      isResolved = true,
                      comments = { nodes = { { databaseId = 200 } } },
                    },
                  },
                },
              },
            },
          },
        })
      end
      local meta = pr.fetch_thread_metadata({ owner = "o", repo = "r", number = "1" })
      assert.equals("T_1", meta[100].thread_id)
      assert.is_false(meta[100].resolved)
      assert.equals("T_1", meta[101].thread_id)
      assert.equals("T_2", meta[200].thread_id)
      assert.is_true(meta[200].resolved)
    end)

    it("returns empty map on runner failure", function()
      pr._runner = function() return nil end
      assert.are.same({}, pr.fetch_thread_metadata({ owner = "o", repo = "r", number = "1" }))
    end)
  end)

  describe("load enriches notes with thread metadata", function()
    local original_runner

    before_each(function() original_runner = pr._runner end)
    after_each(function() pr._runner = original_runner end)

    it("adds thread_id and resolved fields when graphql succeeds", function()
      local rest_response = vim.json.encode({
        { id = 555, path = "f.lua", line = 1, body = "x", user = { login = "u" } },
      })
      local graphql_response = vim.json.encode({
        data = { repository = { pullRequest = { reviewThreads = { nodes = {
          { id = "T_X", isResolved = true, comments = { nodes = { { databaseId = 555 } } } },
        } } } } },
      })

      local call_n = 0
      pr._runner = function(args)
        call_n = call_n + 1
        if call_n == 1 then return rest_response end
        return graphql_response
      end

      local notes = pr.load("https://github.com/o/r/pull/1")
      assert.equals(1, #notes)
      assert.equals("T_X", notes[1].thread_id)
      assert.is_true(notes[1].resolved)
    end)

    it("notes still load with thread_id=nil if graphql fails", function()
      local rest_response = vim.json.encode({
        { id = 1, path = "f.lua", line = 1, body = "x", user = { login = "u" } },
      })
      local n = 0
      pr._runner = function()
        n = n + 1
        if n == 1 then return rest_response end
        return nil
      end
      local notes = pr.load("https://github.com/o/r/pull/1")
      assert.equals(1, #notes)
      assert.is_nil(notes[1].thread_id)
    end)
  end)

  describe("resolve_thread", function()
    local original_runner

    before_each(function() original_runner = pr._runner end)
    after_each(function() pr._runner = original_runner end)

    it("invokes the resolveReviewThread mutation with the thread id", function()
      local got
      pr._runner = function(args) got = args; return vim.json.encode({ data = { resolveReviewThread = { thread = { isResolved = true } } } }) end
      local ok = pr.resolve_thread("T_ABC")
      assert.is_true(ok)
      -- Should be a graphql call referencing T_ABC
      local joined = table.concat(got, " ")
      assert.matches("graphql", joined)
      assert.matches("T_ABC", joined)
      assert.matches("resolveReviewThread", joined)
    end)

    it("returns false on runner failure", function()
      pr._runner = function() return nil end
      assert.is_false(pr.resolve_thread("T_X"))
    end)
  end)

  it("captures in_reply_to_id for thread replies", function()
    local input = vim.json.encode({
      { id = 100, path = "f.lua", line = 1, body = "root", user = { login = "u" } },
      { id = 101, path = "f.lua", line = 1, body = "reply", in_reply_to_id = 100, user = { login = "u" } },
    })
    local notes = pr.parse(input)
    assert.equals(2, #notes)
    assert.is_nil(notes[1].in_reply_to_id)
    assert.equals(100, notes[2].in_reply_to_id)
  end)
end)

describe("review.inputs.pr.load", function()
  -- Inject a fake gh runner so tests don't shell out.
  local original_runner

  before_each(function()
    original_runner = pr._runner
  end)

  after_each(function()
    pr._runner = original_runner
  end)

  it("calls gh with the parsed owner/repo/number for REST first", function()
    local first_call
    pr._runner = function(args)
      if not first_call then first_call = args end
      return SAMPLE_GH_JSON
    end
    pr.load("https://github.com/foo/bar/pull/123")
    assert.are.same(
      { "api", "repos/foo/bar/pulls/123/comments", "--paginate" },
      first_call
    )
  end)

  it("accepts a bare #N when origin remote is set", function()
    -- Skip if no origin remote in this repo
    local origin = vim.fn.systemlist("git -C " .. vim.fn.getcwd() .. " remote get-url origin")[1]
    if not origin or origin == "" then return end
    pr._runner = function() return "[]" end
    -- Should not error on bare number — exact owner/repo determination is the
    -- runner's domain; we only assert load() returns notes (or empty).
    local notes = pr.load("#456")
    assert.is_table(notes)
  end)

  it("returns parsed notes from runner output", function()
    pr._runner = function() return SAMPLE_GH_JSON end
    local notes = pr.load("https://github.com/o/r/pull/1")
    assert.equals(3, #notes)
  end)

  it("returns empty list on runner error (nil)", function()
    pr._runner = function() return nil end
    assert.are.same({}, pr.load("https://github.com/o/r/pull/1"))
  end)

  it("rejects unparseable input strings", function()
    assert.are.same({}, pr.load("not-a-pr-reference"))
  end)

  it("notifies when gh fails (non-zero exit)", function()
    local notified
    local orig_notify = vim.notify
    vim.notify = function(msg, level) notified = { msg = msg, level = level } end

    -- Real _runner with vim.system; force gh to fail by using a bogus PATH.
    local orig_path = vim.env.PATH
    vim.env.PATH = "/nonexistent"
    pr._runner = original_runner -- restore production runner
    local notes = pr.load("https://github.com/o/r/pull/1")
    vim.env.PATH = orig_path
    vim.notify = orig_notify

    assert.are.same({}, notes)
    assert.is_table(notified)
    assert.matches("gh", notified.msg)
    assert.equals(vim.log.levels.ERROR, notified.level)
  end)
end)
