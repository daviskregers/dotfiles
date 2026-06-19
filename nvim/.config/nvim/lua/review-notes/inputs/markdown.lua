-- Input provider: parses markdown for findings. Supports two formats:
--   1. caveman-review:  #### [emoji] `path:line` — heading text
--                       (followed by optional body paragraphs / code blocks
--                        until the next finding or higher-level heading)
--   2. plain:           [bullet] path:line: text  (single-line)
-- Paths may be absolute or relative; caller decides whether to normalise.

local M = {}

local CAVEMAN = "`([^`]+):(%d+)%-?(%d*)`%s*[—:%-]+%s*(.+)$"
local PLAIN   = "^[%-%*%s]*([%w%./%-_]+):(%d+)%-?(%d*):%s*(.+)$"

local SEVERITY_BY_EMOJI = {
  ["🔴"] = "high",
  ["🟠"] = "high",
  ["🟡"] = "medium",
  ["🔵"] = "low",
  ["⚪"] = "info",
  ["🟢"] = "info",
}

local function detect_severity(line)
  for emoji, sev in pairs(SEVERITY_BY_EMOJI) do
    if line:find(emoji, 1, true) then return sev end
  end
  return nil
end

local function match_caveman(line)
  local file, sl, el, text = line:match(CAVEMAN)
  if file then return "caveman", file, sl, el, text end
  return nil
end

local function match_plain(line)
  local file, sl, el, text = line:match(PLAIN)
  if file then return "plain", file, sl, el, text end
  return nil
end

-- A line ends the current finding's body if it starts a new finding OR a
-- heading at level h1/h2/h3 (i.e. <= 3 leading #s — h4 #### is the finding).
local function ends_body(line)
  if match_caveman(line) then return true end
  if line:match("^#%s") or line:match("^##%s") or line:match("^###%s") then
    return true
  end
  return false
end

local function finalise(finding)
  -- Trim trailing blank lines from body
  while #finding.body > 0 and finding.body[#finding.body] == "" do
    table.remove(finding.body)
  end
  local text = finding.heading
  if #finding.body > 0 then
    text = text .. "\n\n" .. table.concat(finding.body, "\n")
  end
  return {
    file = finding.file,
    start_line = tonumber(finding.sl),
    end_line = (finding.el ~= "" and tonumber(finding.el)) or tonumber(finding.sl),
    text = text,
    severity = finding.severity,
  }
end

function M.parse(input)
  local out = {}
  local current  -- pending finding being built

  local function flush()
    if current then
      table.insert(out, finalise(current))
      current = nil
    end
  end

  for line in (input .. "\n"):gmatch("([^\n]*)\n") do
    -- New caveman finding starts here.
    local kind, file, sl, el, text = match_caveman(line)
    if kind then
      flush()
      current = {
        file = file, sl = sl, el = el,
        heading = vim.trim(text),
        severity = detect_severity(line),
        body = {},
      }
    else
      -- Plain finding (single-line, no body capture)
      local pkind, pf, psl, pel, ptext = match_plain(line)
      if pkind then
        flush()
        table.insert(out, {
          file = pf,
          start_line = tonumber(psl),
          end_line = (pel ~= "" and tonumber(pel)) or tonumber(psl),
          text = vim.trim(ptext),
          severity = detect_severity(line),
        })
      elseif current then
        if ends_body(line) then
          flush()
        else
          table.insert(current.body, line)
        end
      end
    end
  end
  flush()
  return out
end

function M.load(path)
  local f = io.open(path, "r")
  if not f then return {} end
  local content = f:read("*a")
  f:close()
  return M.parse(content)
end

return M
