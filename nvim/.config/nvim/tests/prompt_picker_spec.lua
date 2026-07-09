-- Integration: <leader>ap opens a verb picker; selecting a verb runs it.
-- The picker lists the current verbs for now (explain/ask/command/search).
package.loaded["llm-agent.transport"] = {
  config = {}, run = function(opts) _G._pp_opts = opts; return { kill = function() end } end,
}
-- Reload all code-agents modules so they bind to the fake transport above.
for _, m in ipairs({ "code-agents.core", "code-agents.keymaps", "code-agents.ui", "code-agents" }) do
  package.loaded[m] = nil
end
require("code-agents") -- registers keymaps
local core = require("code-agents.core")

-- Drive the picker: choose the verb named `want`, then answer any ui.prompt.
local function pick_verb(want, answer)
  package.loaded["code-agents.ui"].prompt = function(_, cb) cb(answer or "q") end
  vim.ui.select = function(items, _, on_choice)
    for _, v in ipairs(items) do
      if v.name == want then return on_choice(v) end
    end
    error("no verb named " .. want)
  end
  vim.fn.maparg("<leader>ap", "n", false, true).callback()
  vim.wait(500, function() return core.list()[1] ~= nil end)
  return core.list()[1]
end

describe("prompt picker (<leader>ap)", function()
  before_each(function() core._reset() end)

  it("is mapped in normal mode", function()
    assert.is_not_nil(vim.fn.maparg("<leader>ap", "n", false, true).callback)
  end)

  it("lists the current verbs", function()
    local names
    vim.ui.select = function(items) names = vim.tbl_map(function(v) return v.name end, items) end
    vim.fn.maparg("<leader>ap", "n", false, true).callback()
    assert.is_not_nil(names)
    table.sort(names)
    assert.are.same({ "ask", "command", "explain", "search" }, names)
  end)

  it("runs the chosen verb — ask dispatches an ask agent", function()
    local a = pick_verb("ask", "why?")
    assert.is_not_nil(a)
    assert.are.equal("ask", a.verb)
  end)

  it("runs the chosen verb — search dispatches a search agent", function()
    local a = pick_verb("search", "where?")
    assert.is_not_nil(a)
    assert.are.equal("search", a.verb)
  end)
end)
