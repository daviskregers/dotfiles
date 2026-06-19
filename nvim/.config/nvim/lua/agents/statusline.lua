-- Thin wrapper exposing the agent registry's active-label as a statusline
-- segment. mini.lua reads it via .get(). Replaces codecompanion_statusline.

local M = {}

function M.setup() end

function M.get()
  local ok, A = pcall(require, "agents.core")
  if not ok then return "" end
  return A.statusline()
end

return M
