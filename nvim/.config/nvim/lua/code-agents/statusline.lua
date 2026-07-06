-- Statusline segment for code-agents — compact count by state (▶ running,
-- ✓ done, ✗ error). Read via .get().
local M = {}

function M.get()
  local ok, C = pcall(require, "code-agents.core")
  if not ok then return "" end
  return C.statusline()
end

return M
