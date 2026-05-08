-- Keymaps + pickers for the agent registry. Replaces codecompanion / opencode
-- / 99 / copilot. Implementation lives in lua/custom/agents.lua.

local A = require("custom.agents")

-- ── core: toggle / spawn / pick / rename / kill ──────────────────────────

vim.keymap.set("n", "<C-\\>", function() A.toggle() end, { desc = "Agent: toggle active" })
vim.keymap.set("t", "<C-\\>", function() A.toggle() end, { desc = "Agent: toggle active" })

vim.keymap.set("n", "<leader>aA", function() A.toggle(nil, "float") end, { desc = "Agent: toggle (float)" })

vim.keymap.set("n", "<leader>an", function()
  local types = vim.tbl_keys(A.types)
  table.sort(types)
  vim.ui.select(types, { prompt = "Agent type: " }, function(t)
    if not t then return end
    vim.ui.input({ prompt = "Label: ", default = t }, function(label)
      if label and label ~= "" then A.spawn(t, label) end
    end)
  end)
end, { desc = "Agent: new" })

vim.keymap.set("n", "<leader>al", function()
  local agents = A.list()
  if #agents == 0 then return vim.notify("no agents", vim.log.levels.INFO) end
  vim.ui.select(agents, {
    prompt = "Pick active agent",
    format_item = function(a)
      return string.format("%s [%s]%s", a.id, a.type, A.active() and a.id == A.active().id and "  *" or "")
    end,
  }, function(a)
    if a then A.focus(a.id) end
  end)
end, { desc = "Agent: pick active" })

vim.keymap.set("n", "<leader>aR", function()
  local a = A.active()
  if not a then return vim.notify("no active agent", vim.log.levels.WARN) end
  vim.ui.input({ prompt = "Rename: ", default = a.id }, function(name)
    if name and name ~= "" then A.rename(a.id, name) end
  end)
end, { desc = "Agent: rename" })

vim.keymap.set("n", "<leader>ax", function() A.kill() end, { desc = "Agent: kill active" })

-- ── resize active agent's split (works in normal + terminal mode) ────────

vim.keymap.set({ "n", "t" }, "<leader>a>", function() A.resize(5) end, { desc = "Agent: grow split" })
vim.keymap.set({ "n", "t" }, "<leader>a<", function() A.resize(-5) end, { desc = "Agent: shrink split" })

-- ── send selection ───────────────────────────────────────────────────────

vim.keymap.set("v", "<leader>as", function() A.send_selection() end, { desc = "Agent: send selection" })
vim.keymap.set("v", "<leader>aS", function()
  A.send_selection("{description}\n\n{selection}", { needs_description = true })
end, { desc = "Agent: send selection + prompt" })

-- ── verb registry → visual + capital-variant keymaps ─────────────────────

for _, verb in pairs(A.verbs) do
  vim.keymap.set("v", "<leader>" .. verb.keymap, function()
    A.send_selection(verb.template, { needs_description = verb.needs_description })
  end, { desc = "Agent verb: " .. verb.keymap })

  local cap = verb.keymap:sub(1, 1) .. verb.keymap:sub(2):upper()
  if cap ~= verb.keymap then
    vim.keymap.set("v", "<leader>" .. cap, function()
      A.send_selection("{description}\n\n" .. verb.template, { needs_description = true })
    end, { desc = "Agent verb: " .. cap .. " (with description)" })
  end
end
