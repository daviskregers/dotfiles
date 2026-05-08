-- Statusline segment for review-notes count.
-- Shows "RN <unresolved>/<total>" when there are notes; empty otherwise.

local M = {}

function M.setup() end

function M.get()
  local ok, rn = pcall(require, "custom.review-notes")
  if not ok then return "" end
  local notes = rn.get_notes()
  if not notes or #notes == 0 then return "" end
  local total = #notes
  local unresolved = 0
  for _, n in ipairs(notes) do
    if not n.resolved then unresolved = unresolved + 1 end
  end
  return string.format("RN %d/%d", unresolved, total)
end

return M
