-- Statusline segment for code-agents — compact count by state (▶ running,
-- ✓ done, ✗ error) plus Claude's 5h usage limit. Nothing renders this by
-- default (no statusline plugin in this config) — wired via settings.lua
-- appending %{v:lua.require('code-agents.statusline').get()} onto nvim's
-- built-in statusline. Read via .get().
local M = {}

-- claude/.claude/statusline.sh writes this cache on every render of a live
-- Claude Code session (it already receives rate_limits on stdin). Missing/
-- stale (no session in the last ~6h) → segment omits itself.
local USAGE_CACHE = vim.fn.expand("~/.claude/cache/rate-limits.json")
local STALE_SECS = 6 * 3600

-- Pure: decoded cache data + now → "5h:NN%(Xh Ym)" or "". Tested directly so
-- reset-math doesn't need mocking os.time().
function M.format_usage(data, now)
  if type(data) ~= "table" or not data.updated_at then return "" end
  if (now - data.updated_at) > STALE_SECS then return "" end
  local fh = data.five_hour
  if type(fh) ~= "table" or not fh.used_percentage then return "" end
  local pct = math.floor(fh.used_percentage + 0.5)
  local reset = ""
  if fh.resets_at then
    local secs = fh.resets_at - now
    if secs > 0 then
      local h, m = math.floor(secs / 3600), math.floor((secs % 3600) / 60)
      reset = h > 0 and string.format("(%dh%dm)", h, m) or string.format("(%dm)", m)
    end
  end
  return string.format("5h:%d%%%s", pct, reset)
end

-- Read + decode the cache file. Own function (not inlined into get) so tests
-- can stub it without touching the filesystem.
function M.read_usage()
  local f = io.open(USAGE_CACHE, "r")
  if not f then return "" end
  local raw = f:read("*a")
  f:close()
  local ok, data = pcall(vim.json.decode, raw)
  if not ok then return "" end
  return M.format_usage(data, os.time())
end

function M.get()
  local ok, C = pcall(require, "code-agents.core")
  local agents = ok and C.statusline() or ""
  local usage = M.read_usage()
  if agents ~= "" and usage ~= "" then return agents .. " " .. usage end
  return agents .. usage
end

return M
