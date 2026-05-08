-- Input provider: fetches GitHub PR review comments via `gh api` and converts
-- them to notes. Drops reviewinator from the nvim path.

local M = {}

local PR_URL = "^https://github%.com/([%w%-_%.]+)/([%w%-_%.]+)/pull/(%d+)"

-- Calls `gh` and returns stdout as a string (or nil on error). Indirected via
-- M._runner so tests can inject a fake.
function M._runner(args)
  local cmd = vim.list_extend({ "gh" }, args)
  local ok, res = pcall(function() return vim.system(cmd, { text = true }):wait() end)
  if not ok then
    vim.notify("gh: " .. tostring(res), vim.log.levels.ERROR)
    return nil
  end
  if res.code ~= 0 then
    local err = vim.trim(res.stderr or "")
    if err == "" then err = "gh exited " .. tostring(res.code) end
    vim.notify("gh: " .. err, vim.log.levels.ERROR)
    return nil
  end
  return res.stdout or ""
end

-- Parse a PR ref into { owner, repo, number }. Accepts:
--   https://github.com/OWNER/REPO/pull/N  → exact match
--   #N                                     → uses origin remote of cwd repo
local function parse_ref(ref)
  local o, r, n = ref:match(PR_URL)
  if o then return { owner = o, repo = r, number = n } end

  local num = ref:match("^#(%d+)$")
  if num then
    local origin = vim.fn.systemlist("git remote get-url origin")[1] or ""
    local oo, rr = origin:match("github%.com[:/]([%w%-_%.]+)/([%w%-_%.]+)")
    if oo and rr then
      rr = rr:gsub("%.git$", "")
      return { owner = oo, repo = rr, number = num }
    end
  end

  return nil
end

local function note_from_comment(c)
  if not c.path then return nil end
  local sl = c.start_line or c.line or c.original_line
  local el = c.line or c.original_line or sl
  if not sl then return nil end
  return {
    file = c.path,
    start_line = sl,
    end_line = el,
    text = c.body or "",
    pr_comment_id = c.id,
    in_reply_to_id = c.in_reply_to_id,
    author = c.user and c.user.login or nil,
  }
end

function M.parse(json_str)
  local ok, data = pcall(vim.json.decode, json_str, { luanil = { object = true, array = true } })
  if not ok or type(data) ~= "table" then return {} end
  local out = {}
  for _, c in ipairs(data) do
    local n = note_from_comment(c)
    if n then table.insert(out, n) end
  end
  return out
end

-- ── thread metadata via GraphQL ──────────────────────────────────────────

local THREAD_QUERY = [[
query($owner:String!, $repo:String!, $number:Int!) {
  repository(owner:$owner, name:$repo) {
    pullRequest(number:$number) {
      reviewThreads(first:100) {
        nodes {
          id
          isResolved
          comments(first:100) { nodes { databaseId } }
        }
      }
    }
  }
}
]]

-- Fetch a map of comment-id → { thread_id, resolved } via the GraphQL API.
-- Returns {} on any failure so callers can degrade gracefully.
function M.fetch_thread_metadata(parsed)
  local raw = M._runner({
    "api", "graphql",
    "-f", "query=" .. THREAD_QUERY,
    "-F", "owner=" .. parsed.owner,
    "-F", "repo=" .. parsed.repo,
    "-F", "number=" .. parsed.number,
  })
  if not raw or raw == "" then return {} end
  local ok, data = pcall(vim.json.decode, raw, { luanil = { object = true, array = true } })
  if not ok then return {} end
  local threads = ((((data or {}).data or {}).repository or {}).pullRequest or {}).reviewThreads
  if not threads or not threads.nodes then return {} end

  local meta = {}
  for _, t in ipairs(threads.nodes) do
    for _, c in ipairs((t.comments or {}).nodes or {}) do
      meta[c.databaseId] = { thread_id = t.id, resolved = t.isResolved == true }
    end
  end
  return meta
end

function M.resolve_thread(thread_id)
  if not thread_id or thread_id == "" then return false end
  local raw = M._runner({
    "api", "graphql",
    "-f", "query=mutation($t:ID!) { resolveReviewThread(input:{threadId:$t}) { thread { isResolved } } }",
    "-F", "t=" .. thread_id,
  })
  return raw ~= nil
end

function M.load(ref)
  local parsed = parse_ref(ref)
  if not parsed then return {} end
  local raw = M._runner({
    "api",
    string.format("repos/%s/%s/pulls/%s/comments", parsed.owner, parsed.repo, parsed.number),
    "--paginate",
  })
  if not raw then return {} end
  local notes = M.parse(raw)

  local meta = M.fetch_thread_metadata(parsed)
  for _, n in ipairs(notes) do
    local m = meta[n.pr_comment_id]
    if m then
      n.thread_id = m.thread_id
      n.resolved  = m.resolved
    end
  end
  return notes
end

return M
