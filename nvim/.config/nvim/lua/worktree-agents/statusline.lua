-- Statusline segment for background worktree agents — a compact count of
-- agents by state (▶ running, ⏸ awaiting, ✓ done, ✗ error). mini.lua reads it
-- via .get(). Sibling to agent_statusline.lua (which shows the active slot).

local M = {}

function M.setup() end

function M.get()
  local ok, W = pcall(require, "worktree-agents.core")
  if not ok then return "" end
  return W.statusline()
end

return M
