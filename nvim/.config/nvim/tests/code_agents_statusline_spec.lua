local statusline = require("code-agents.statusline")

describe("format_usage", function()
  local now = 1700000000

  it("formats percentage with hours+minutes until reset", function()
    local out = statusline.format_usage(
      { updated_at = now, five_hour = { used_percentage = 41.6, resets_at = now + 3900 } }, now)
    assert.are.equal("5h:42%(1h5m)", out)
  end)

  it("formats percentage with only minutes when under an hour to reset", function()
    local out = statusline.format_usage(
      { updated_at = now, five_hour = { used_percentage = 10, resets_at = now + 300 } }, now)
    assert.are.equal("5h:10%(5m)", out)
  end)

  it("omits the reset suffix when resets_at is missing", function()
    local out = statusline.format_usage(
      { updated_at = now, five_hour = { used_percentage = 5 } }, now)
    assert.are.equal("5h:5%", out)
  end)

  it("omits the reset suffix when resets_at is already in the past", function()
    local out = statusline.format_usage(
      { updated_at = now, five_hour = { used_percentage = 5, resets_at = now - 10 } }, now)
    assert.are.equal("5h:5%", out)
  end)

  it("returns empty when the cache is stale (session ended long ago)", function()
    local out = statusline.format_usage(
      { updated_at = now - 100000, five_hour = { used_percentage = 42, resets_at = now + 100 } }, now)
    assert.are.equal("", out)
  end)

  it("returns empty when five_hour data is missing", function()
    assert.are.equal("", statusline.format_usage({ updated_at = now }, now))
  end)

  it("returns empty for non-table input", function()
    assert.are.equal("", statusline.format_usage(nil, now))
  end)
end)

describe("get", function()
  it("joins agent counts and usage with a space when both present", function()
    package.loaded["code-agents.core"] = { statusline = function() return "▶1" end }
    package.loaded["code-agents.statusline"] = nil
    local sl = require("code-agents.statusline")
    sl.read_usage = function() return "5h:10%" end
    assert.are.equal("▶1 5h:10%", sl.get())
  end)

  it("returns just the usage segment when there are no agents", function()
    package.loaded["code-agents.core"] = { statusline = function() return "" end }
    package.loaded["code-agents.statusline"] = nil
    local sl = require("code-agents.statusline")
    sl.read_usage = function() return "5h:10%" end
    assert.are.equal("5h:10%", sl.get())
  end)

  it("returns empty string when neither agents nor usage are present", function()
    package.loaded["code-agents.core"] = { statusline = function() return "" end }
    package.loaded["code-agents.statusline"] = nil
    local sl = require("code-agents.statusline")
    sl.read_usage = function() return "" end
    assert.are.equal("", sl.get())
  end)
end)
