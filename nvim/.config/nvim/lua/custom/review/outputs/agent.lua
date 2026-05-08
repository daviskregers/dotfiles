-- Output provider: sends review notes to the active P2 agent slot for triage
-- or fix. Replaces the manual /comment round-trip.

local M = {}

local function format_note(n)
  local range = (n.start_line == n.end_line)
    and tostring(n.start_line)
    or string.format("%d-%d", n.start_line, n.end_line)
  local header = string.format("%s:%s", n.file, range)
  if n.author then header = header .. " (" .. n.author .. ")" end
  return header .. "\n" .. (n.text or "")
end

function M.push(notes)
  if #notes == 0 then return { ok = true, count = 0 } end
  local parts = {}
  for _, n in ipairs(notes) do
    table.insert(parts, format_note(n))
  end
  local body = "Review findings:\n\n" .. table.concat(parts, "\n\n---\n\n")
  require("custom.agents").send(body)
  return { ok = true, count = #notes }
end

return M
