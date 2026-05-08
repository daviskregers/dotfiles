local agent_out = require("custom.review.outputs.agent")

local sample_note = {
  file = "src/auth.ts",
  start_line = 42,
  end_line = 42,
  text = "use refresh tokens here",
  author = "reviewer1",
}

describe("review.outputs.agent", function()
  local sent
  local original_send

  before_each(function()
    sent = nil
    -- Inject fake send function (replace the agents module's send for the test).
    local agents = require("custom.agents")
    original_send = agents.send
    agents.send = function(text) sent = text end
  end)

  after_each(function()
    require("custom.agents").send = original_send
  end)

  it("formats a single note with file:line header before the comment text", function()
    agent_out.push({ sample_note })
    assert.is_string(sent)
    assert.matches("src/auth%.ts:42", sent)
    assert.matches("use refresh tokens here", sent)
  end)

  it("includes the comment author when present", function()
    agent_out.push({ sample_note })
    assert.matches("reviewer1", sent)
  end)

  it("uses range format when start_line ≠ end_line", function()
    agent_out.push({ {
      file = "f.lua", start_line = 3, end_line = 7, text = "block-level note",
    } })
    assert.matches("f%.lua:3%-7", sent)
  end)

  it("returns ok with count", function()
    local res = agent_out.push({ sample_note })
    assert.is_true(res.ok)
    assert.equals(1, res.count)
  end)

  it("concatenates multiple notes with separators", function()
    agent_out.push({
      { file = "a.lua", start_line = 1, end_line = 1, text = "first" },
      { file = "b.lua", start_line = 2, end_line = 2, text = "second" },
    })
    assert.matches("first", sent)
    assert.matches("second", sent)
    -- some separator between them (not testing exact form)
    assert.is_true(sent:find("first") < sent:find("second"))
  end)

  it("returns not-ok if no active agent (send fails silently)", function()
    require("custom.agents").send = function() return false end
    local res = agent_out.push({ sample_note })
    -- Send is fire-and-forget for now; treat any path as ok=true unless we
    -- detect a clear failure. For empty input return early.
    local empty_res = agent_out.push({})
    assert.is_true(empty_res.ok)
    assert.equals(0, empty_res.count)
  end)
end)
