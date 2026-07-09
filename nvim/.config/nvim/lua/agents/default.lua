local M = {}

local CLAUDE_ALIASES = {
  claude = true,
  haiku = true,
  sonnet = true,
  opus = true,
  fable = true,
}

function M.file(path)
  return path or (vim.fn.stdpath("config") .. "/.agent")
end

function M.project_file()
  local root = vim.fs.find(".dk-notes", { upward = true, type = "directory" })[1]
  return root and (root .. "/.agent") or nil
end

function M.read(path)
  local ok, content = pcall(vim.fn.readfile, path)
  if ok and content[1] then return vim.trim(content[1]) end
  return nil
end

function M.provider(supported, fallback, path)
  local agent = M.read(path) or M.read(M.project_file()) or M.read(M.file())
  if not agent or agent == "" then return fallback end
  if supported[agent] then return agent end
  if CLAUDE_ALIASES[agent] and supported.claude then return "claude" end
  return fallback
end

return M
