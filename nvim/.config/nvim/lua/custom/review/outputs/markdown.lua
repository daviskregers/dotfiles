-- Output provider: writes notes to a markdown file. Reuses the formatter from
-- review-notes core so the on-disk format stays consistent with manual export.

local M = {}

function M.push(notes, opts)
  opts = opts or {}
  if #notes == 0 then return { ok = true, count = 0 } end

  local rn = require("custom.review-notes")
  local dir = opts.dir or rn.get_export_dir()
  if not dir then return { ok = false, count = 0, err = "no export dir" } end

  vim.fn.mkdir(dir, "p")
  local md = rn.format_markdown(notes, rn.get_git_metadata())
  local path = dir .. "/" .. os.date("%Y-%m-%d-%H%M%S") .. ".md"
  local f, err = io.open(path, "w")
  if not f then return { ok = false, count = 0, err = err } end
  f:write(md); f:close()
  return { ok = true, count = #notes, path = path }
end

return M
