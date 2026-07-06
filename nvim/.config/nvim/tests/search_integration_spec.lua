-- Integration: the search conversation window must close when results open in
-- the quickfix. Replicates the bug where on_done referenced a nil global `a`
-- (Lua local-scope trap) so close_view never ran and the window stayed open.
package.loaded["llm-agent.transport"] = {
  config = {}, run = function(opts) _G._search_opts = opts; return { kill = function() end } end,
}
-- Reload all code-agents modules so they bind to the fake transport above.
for _, m in ipairs({ "code-agents.core", "code-agents.keymaps", "code-agents.ui", "code-agents" }) do
  package.loaded[m] = nil
end
require("code-agents") -- registers keymaps
local core = require("code-agents.core")

local function run_search_and_finish(text, code)
  package.loaded["code-agents.ui"].prompt = function(_, cb) cb("myquery") end
  vim.fn.maparg("<leader>pq", "n", false, true).callback()
  vim.wait(500, function() local a = core.list()[1]; return a and a.close_view ~= nil end)
  local a = core.list()[1]
  _G._search_opts.on_event({ type = "text", text = text })
  _G._search_opts.on_exit(code, "")
  vim.wait(200)
  return a
end

describe("search view lifecycle", function()
  before_each(function() core._reset() end)

  it("closes the conversation window when results are found", function()
    local a = run_search_and_finish("a/b.lua:1:1: hit", 0)
    assert.is_nil(a.on_update) -- close_view nils on_update; proves the window was closed
  end)

  it("keeps the conversation window open when no results", function()
    local a = run_search_and_finish("no matches", 0)
    assert.is_not_nil(a.on_update) -- view stays so the transcript is visible
  end)
end)

-- Invoke a buffer-local normal-mode mapping by its lhs.
local function press(buf, lhs)
  for _, m in ipairs(vim.api.nvim_buf_get_keymap(buf, "n")) do
    if m.lhs == lhs and m.callback then return m.callback() end
  end
  error("no mapping for " .. lhs)
end

describe("conversation window ops", function()
  before_each(function() core._reset() end)

  it("the stop key halts the running agent", function()
    package.loaded["code-agents.ui"].prompt = function(_, cb) cb("q") end
    vim.fn.maparg("<leader>pq", "n", false, true).callback() -- opens conversation, agent running
    vim.wait(500, function() local a = core.list()[1]; return a and a._view_buf ~= nil end)
    local a = core.list()[1]
    assert.are.equal("running", a.status)
    press(a._view_buf, "s")
    assert.are.equal("stopped", a.status)
  end)
end)
