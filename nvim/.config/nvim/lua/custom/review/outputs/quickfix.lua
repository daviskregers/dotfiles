-- Output provider: dumps notes into nvim's quickfix list. Title flagged so
-- :colder / :cnewer surfaces it among other lists.

local M = {}

local SEVERITY_TO_TYPE = { high = "E", medium = "W", low = "I" }

function M.push(notes, opts)
  opts = opts or {}
  -- Partition: unresolved first.
  local unresolved, resolved = {}, {}
  for _, n in ipairs(notes) do
    if n.resolved then table.insert(resolved, n) else table.insert(unresolved, n) end
  end

  local items = {}
  local function add(n)
    table.insert(items, {
      filename = n.file,
      lnum = n.start_line,
      end_lnum = n.end_line,
      col = 1,
      text = n.resolved and ("✓ " .. (n.text or "")) or (n.text or ""),
      type = SEVERITY_TO_TYPE[n.severity] or "",
    })
  end
  for _, n in ipairs(unresolved) do add(n) end
  for _, n in ipairs(resolved) do add(n) end

  vim.fn.setqflist({}, "r", { title = "Review Notes", items = items })
  if opts.open then vim.cmd("copen") end
  return { ok = true, count = #items }
end

return M
