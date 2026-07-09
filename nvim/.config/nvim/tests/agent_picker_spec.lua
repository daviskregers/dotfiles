-- Integration: <leader>al opens a telescope agent picker that previews each
-- agent's transcript, and opens the chosen agent's conversation on select.
-- Telescope is faithfully faked (entry_maker / buffer previewer / default
-- selection) so the real telescope branch of pick_agent is exercised headlessly.
package.loaded["llm-agent.transport"] = {
  config = {}, run = function(opts) _G._ap_opts = opts; return { kill = function() end } end,
}

local sel = {} -- state captured by the fake picker across a single :find()
package.loaded["telescope.finders"] = { new_table = function(t) return t end }
package.loaded["telescope.config"] = { values = { generic_sorter = function() return {} end } }
package.loaded["telescope.actions.state"] = { get_selected_entry = function() return sel.entry end }
package.loaded["telescope.actions"] = {
  select_default = { replace = function(_, fn) sel.on_select = fn end },
  close = function() end,
}
package.loaded["telescope.previewers"] = { new_buffer_previewer = function(o) return o end }
package.loaded["telescope.pickers"] = {
  new = function(_, cfg)
    return { find = function()
      sel.entries = {}
      for _, r in ipairs(cfg.finder.results) do
        sel.entries[#sel.entries + 1] = cfg.finder.entry_maker(r)
      end
      sel.entry = sel.entries[1]
      if cfg.previewer and cfg.previewer.define_preview then -- exercise the preview pane
        local buf = vim.api.nvim_create_buf(false, true)
        local win = vim.api.nvim_open_win(buf, false,
          { relative = "editor", width = 10, height = 5, row = 1, col = 1, style = "minimal" })
        cfg.previewer.define_preview({ state = { bufnr = buf, winid = win } }, sel.entry)
        sel.preview = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
        vim.api.nvim_win_close(win, true)
      end
      cfg.attach_mappings(0)          -- install the default-select override…
      if sel.on_select then sel.on_select() end -- …and fire it (choose the first entry)
    end }
  end,
}

for _, m in ipairs({ "code-agents.core", "code-agents.keymaps", "code-agents.ui", "code-agents" }) do
  package.loaded[m] = nil
end
require("code-agents") -- registers keymaps
local core = require("code-agents.core")

local function trigger()
  sel.entries, sel.entry, sel.preview, sel.on_select = nil, nil, nil, nil
  vim.fn.maparg("<leader>al", "n", false, true).callback()
end

describe("agent picker (<leader>al)", function()
  before_each(function() core._reset() end)

  it("is mapped in normal mode", function()
    assert.is_not_nil(vim.fn.maparg("<leader>al", "n", false, true).callback)
  end)

  it("notifies when there are no agents", function()
    local msg
    local orig = vim.notify
    vim.notify = function(m) msg = m end
    trigger()
    vim.notify = orig
    assert.is_truthy((msg or ""):find("no code%-agents"))
  end)

  it("labels each agent with id, status and provider/model", function()
    local a = core.dispatch({ verb = "ask", provider = "claude", model = "opus", prompt = "hi" })
    trigger()
    local display = sel.entries[1].display
    assert.is_truthy(display:find(a.id, 1, true))
    assert.is_truthy(display:find("claude", 1, true))
    assert.is_truthy(display:find("opus", 1, true))
  end)

  it("previews the highlighted agent's transcript", function()
    core.dispatch({ verb = "ask", provider = "claude", model = "opus", prompt = "why is the sky blue" })
    trigger()
    assert.is_truthy(sel.preview:find("why is the sky blue", 1, true)) -- render_transcript output
  end)

  it("opens the chosen agent's conversation (wires live refresh)", function()
    local a = core.dispatch({ verb = "ask", provider = "claude", model = "opus", prompt = "hi" })
    trigger()
    vim.wait(500, function() return a.on_update ~= nil end)
    assert.is_not_nil(a.on_update) -- open_conversation ran → refresh handler installed
    assert.is_not_nil(a._view_buf)
    if a.close_view then a.close_view() end
  end)
end)

describe("shared conversation window", function()
  before_each(function() core._reset() end)

  it("creates a shared window that all agents render into", function()
    local a = core.dispatch({ verb = "ask", provider = "claude", model = "opus", prompt = "agent a" })
    trigger()
    vim.wait(500, function() return a._view_buf ~= nil end, 50)
    assert.is_not_nil(a._view_buf)
    assert.is_true(vim.api.nvim_buf_is_valid(a._view_buf))
    if a.close_view then a.close_view() end
  end)

  it("picker entry is searchable by title (ordinal includes raw_prompt)", function()
    local a = core.dispatch({ verb = "ask", provider = "claude", model = "opus", prompt = "refactor auth module" })
    trigger()
    vim.wait(500, function() return sel.entries ~= nil end, 50)
    assert.is_not_nil(sel.entries)
    local entry = sel.entries[1]
    assert.is_truthy(entry.ordinal:find("refactor auth module", 1, true))
  end)

  it("picker ordinal is lowercase for case-insensitive telescope matching", function()
    local a = core.dispatch({ verb = "ask", provider = "claude", model = "opus", prompt = "Refactor AUTH" })
    trigger()
    vim.wait(500, function() return sel.entries ~= nil end, 50)
    assert.is_not_nil(sel.entries)
    local entry = sel.entries[1]
    assert.is_truthy(entry.ordinal:find("refactor auth", 1, true))
    assert.is_nil(entry.ordinal:find("Refactor"))
    assert.is_nil(entry.ordinal:find("AUTH"))
  end)

end)
