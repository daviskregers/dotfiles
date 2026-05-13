local A = require("custom.agents")

-- Use `cat` as a benign agent type for tests — echoes input, no auth.
local function with_fake_type()
  A.types.fake = { cmd = "cat" }
end

describe("agents", function()
  before_each(function()
    A._reset()
    with_fake_type()
  end)

  after_each(function()
    A._reset()
  end)

  describe("module shape", function()
    it("exposes types and verbs", function()
      assert.is_table(A.types)
      assert.is_table(A.types.claude)
      assert.is_table(A.verbs)
      assert.is_string(A.verbs.explain.template)
      assert.is_string(A.verbs.explain.keymap)
    end)

    it("exposes core functions", function()
      for _, name in ipairs({
        "spawn", "toggle", "kill", "set_active", "rename",
        "list", "active", "send", "send_selection",
        "format_message", "statusline",
      }) do
        assert.is_function(A[name], name .. " missing")
      end
    end)
  end)

  describe("format_message", function()
    it("renders selection + filename:line header", function()
      local out = A.format_message("{selection}", "code", "src/x.lua", 1, 3)
      assert.equals("src/x.lua:1-3\ncode", out)
    end)

    it("substitutes {description}", function()
      local out = A.format_message("{description}\n\n{selection}", "x", "f", 1, 1, "do thing")
      assert.equals("do thing\n\nf:1-1\nx", out)
    end)

    it("renders verb template (explain)", function()
      local out = A.format_message(A.verbs.explain.template, "code", "f.lua", 5, 7)
      assert.matches("one abstraction below", out)
      assert.matches("f%.lua:5%-7\ncode", out)
    end)

    it("defaults template to {selection}", function()
      local out = A.format_message(nil, "x", "f", 1, 1)
      assert.equals("f:1-1\nx", out)
    end)

    it("substitutes empty description when not provided", function()
      local out = A.format_message("{description}!", "_", "_", 1, 1)
      assert.equals("!", out)
    end)
  end)

  describe("spawn", function()
    it("creates agent and makes it active", function()
      local a = A.spawn("fake", "test1")
      assert.equals("test1", a.id)
      assert.equals("fake", a.type)
      assert.is_number(a.buf)
      assert.is_true(vim.api.nvim_buf_is_valid(a.buf))
      assert.is_number(a.job)
      assert.equals("test1", A.active().id)
    end)

    it("rejects unknown type", function()
      assert.has_error(function() A.spawn("bogus", "x") end)
    end)

    it("rejects empty label", function()
      assert.has_error(function() A.spawn("fake", "") end)
    end)

    it("rejects duplicate label", function()
      A.spawn("fake", "dup")
      assert.has_error(function() A.spawn("fake", "dup") end)
    end)

    it("supports float mode", function()
      local a = A.spawn("fake", "f1", { mode = "float" })
      assert.equals("float", a.mode)
      assert.is_true(vim.api.nvim_win_is_valid(a.win))
    end)

    it("tags the buffer with agent_id", function()
      local a = A.spawn("fake", "tagged")
      assert.equals("tagged", vim.b[a.buf].agent_id)
    end)
  end)

  describe("toggle", function()
    it("hides visible agent, then re-shows it without losing buffer/job", function()
      local a = A.spawn("fake", "t1")
      local buf, job = a.buf, a.job
      assert.is_true(vim.api.nvim_win_is_valid(a.win))

      A.toggle()
      assert.is_nil(a.win)
      assert.is_true(vim.api.nvim_buf_is_valid(buf))

      A.toggle()
      assert.is_true(vim.api.nvim_win_is_valid(a.win))
      assert.equals(buf, a.buf)
      assert.equals(job, a.job)
    end)

    it("hides others when re-showing an agent (single-visible)", function()
      local a = A.spawn("fake", "first")
      local b = A.spawn("fake", "second")
      -- After spawning b, a should be hidden.
      assert.is_nil(a.win)
      assert.is_true(vim.api.nvim_win_is_valid(b.win))

      -- Hide b, then toggle a back.
      A.toggle("second")
      assert.is_nil(b.win)
      A.toggle("first")
      assert.is_true(vim.api.nvim_win_is_valid(a.win))
      assert.is_nil(b.win)
    end)
  end)

  describe("spawn enforces single-visible", function()
    it("hides previous agent when spawning a new one", function()
      local a = A.spawn("fake", "first")
      assert.is_true(vim.api.nvim_win_is_valid(a.win))
      local b = A.spawn("fake", "second")
      assert.is_nil(a.win)
      assert.is_true(vim.api.nvim_win_is_valid(b.win))
    end)
  end)

  describe("focus", function()
    it("brings hidden agent to the front and hides others", function()
      local a = A.spawn("fake", "first")
      local b = A.spawn("fake", "second")
      -- a is hidden, b visible
      A.focus("first")
      assert.is_true(vim.api.nvim_win_is_valid(a.win))
      assert.is_nil(b.win)
      assert.equals("first", A.active().id)
    end)

    it("is idempotent on the already-active visible agent", function()
      local a = A.spawn("fake", "only")
      local original_win = a.win
      A.focus("only")
      assert.equals(original_win, a.win)
      assert.is_true(vim.api.nvim_win_is_valid(a.win))
    end)

    it("no-ops on unknown id", function()
      A.spawn("fake", "real")
      A.focus("ghost")  -- should not error
      assert.equals("real", A.active().id)
    end)
  end)

  describe("kill", function()
    it("removes agent and clears active when killing active", function()
      A.spawn("fake", "k1")
      A.kill()
      assert.is_nil(A.active())
      assert.equals(0, #A.list())
    end)

    it("preserves active when killing a non-active agent", function()
      A.spawn("fake", "a")
      local b = A.spawn("fake", "b")  -- active
      A.kill("a")
      assert.equals("b", A.active().id)
      assert.equals(1, #A.list())
      assert.is_true(vim.api.nvim_buf_is_valid(b.buf))
    end)

    it("falls through gracefully on unknown id", function()
      A.kill("no-such-thing")
    end)
  end)

  describe("set_active / rename", function()
    it("set_active switches active id", function()
      A.spawn("fake", "x")
      A.spawn("fake", "y")
      A.set_active("x")
      assert.equals("x", A.active().id)
    end)

    it("set_active ignores unknown id", function()
      A.spawn("fake", "x")
      A.set_active("nope")
      assert.equals("x", A.active().id)
    end)

    it("rename updates id and active pointer", function()
      A.spawn("fake", "old")
      A.rename("old", "new")
      assert.equals("new", A.active().id)
      assert.is_nil(A.list()[1].id == "old" and "should be renamed" or nil)
    end)

    it("rename refuses collision", function()
      A.spawn("fake", "a")
      A.spawn("fake", "b")
      A.rename("a", "b")
      -- Both still exist with original ids
      local ids = {}
      for _, ag in ipairs(A.list()) do table.insert(ids, ag.id) end
      table.sort(ids)
      assert.are.same({ "a", "b" }, ids)
    end)
  end)

  describe("list", function()
    it("returns sorted agents", function()
      A.spawn("fake", "c")
      A.spawn("fake", "a")
      A.spawn("fake", "b")
      local ids = {}
      for _, ag in ipairs(A.list()) do table.insert(ids, ag.id) end
      assert.are.same({ "a", "b", "c" }, ids)
    end)
  end)

  describe("send", function()
    it("warns when no active agent", function()
      local notified = false
      local orig = vim.notify
      vim.notify = function(_, _) notified = true end
      A.send("hello")
      vim.notify = orig
      assert.is_true(notified)
    end)

    it("sends to active agent's job channel", function()
      local a = A.spawn("fake", "echo")
      -- chan_send to `cat` should not error; output appears in the buf
      -- after a moment. Not deterministic to assert content here, but we can
      -- verify the call succeeds.
      A.send("ping\n")
      assert.is_number(a.job)
    end)
  end)

  describe("resize", function()
    -- Headless nvim has small default columns; force a wide screen so
    -- resize math isn't clamped by the screen edge.
    before_each(function() vim.o.columns = 200 end)

    it("changes active agent's split width and persists it", function()
      local a = A.spawn("fake", "wide")
      vim.api.nvim_win_set_width(a.win, 80)
      A.resize(10)
      assert.equals(90, vim.api.nvim_win_get_width(a.win))
      assert.equals(90, a.width)
    end)

    it("clamps to a minimum width of 20", function()
      local a = A.spawn("fake", "narrow")
      vim.api.nvim_win_set_width(a.win, 25)
      A.resize(-100)
      assert.equals(20, vim.api.nvim_win_get_width(a.win))
    end)

    it("no-ops when no agent is active", function()
      A.resize(5)  -- should not error
    end)
  end)

  describe("default_width", function()
    before_each(function() vim.o.columns = 200 end)

    it("opens new split agents at the configured default", function()
      A.default_width = 60
      local a = A.spawn("fake", "sized")
      assert.equals(60, vim.api.nvim_win_get_width(a.win))
      A.default_width = 80
    end)
  end)

  describe("get_default_agent", function()
    it("is exposed as a function", function()
      assert.is_function(A.get_default_agent)
    end)

    it("returns nil when no config exists", function()
      -- In test environment, no .dk-notes/ and no global config expected
      local result = A.get_default_agent()
      assert.is_nil(result)
    end)
  end)

  describe("set_default_agent", function()
    it("is exposed as a function", function()
      assert.is_function(A.set_default_agent)
    end)

    it("warns when no .dk-notes directory exists", function()
      local notified = false
      local notify_msg = nil
      local orig = vim.notify
      vim.notify = function(msg, level)
        notified = true
        notify_msg = msg
      end

      -- Ensure we're in a location without .dk-notes
      local orig_dir = vim.fn.getcwd()
      vim.cmd("cd /tmp")
      A.set_default_agent()
      vim.cmd("cd " .. orig_dir)

      vim.notify = orig
      assert.is_true(notified)
      assert.matches("No .dk%-notes/ directory found", notify_msg)
    end)
  end)

  describe("statusline", function()
    it("returns empty when no agent", function()
      assert.equals("", A.statusline())
    end)

    it("returns [label] of active agent", function()
      A.spawn("fake", "refactor-auth")
      assert.equals("[refactor-auth]", A.statusline())
    end)

    it("updates after rename", function()
      A.spawn("fake", "old")
      A.rename("old", "new")
      assert.equals("[new]", A.statusline())
    end)
  end)
end)
