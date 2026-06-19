-- Output provider: posts notes to a PR.
--   kind=original  → skipped (already on server)
--   kind=reply     → individual POST to /pulls/N/comments/<id>/replies
--   kind=local/loaded/nil → batched into one `gh pr review --comment`
--
-- Tests inject `_runner` to fake `gh`.

local M = {}

local PR_URL = "^https://github%.com/([%w%-_%.]+)/([%w%-_%.]+)/pull/(%d+)"

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

local function parse_pr(ref)
  local owner, repo, n = (ref or ""):match(PR_URL)
  if not owner then return nil end
  return { owner = owner, repo = repo, number = n }
end

local function post_reply(parsed, note)
  return M._runner({
    "api",
    string.format("repos/%s/%s/pulls/%s/comments/%s/replies",
      parsed.owner, parsed.repo, parsed.number, tostring(note.replies_to_id)),
    "-X", "POST",
    "-f", "body=" .. (note.text or ""),
  })
end

-- Resolve the PR's head commit SHA. Required by the inline-comment endpoint.
local function fetch_head_sha(pr_ref)
  local out = M._runner({ "pr", "view", pr_ref, "--json", "headRefOid", "-q", ".headRefOid" })
  if not out then return nil end
  local sha = vim.trim(out)
  if sha == "" then return nil end
  return sha
end

-- Post a single inline comment via /pulls/N/comments. Supports line/side
-- (the modern API), unlike the batched /reviews endpoint which uses legacy
-- diff `position`.
local function post_inline_comment(parsed, sha, note)
  local args = {
    "api",
    string.format("repos/%s/%s/pulls/%s/comments", parsed.owner, parsed.repo, parsed.number),
    "-X", "POST",
    "-f", "commit_id=" .. sha,
    "-f", "path=" .. note.file,
    "-f", "body=" .. (note.text or ""),
    "-f", "side=RIGHT",
    "-F", "line=" .. tostring(note.end_line or note.start_line),
  }
  if note.start_line and note.end_line and note.start_line ~= note.end_line then
    table.insert(args, "-F"); table.insert(args, "start_line=" .. tostring(note.start_line))
    table.insert(args, "-f"); table.insert(args, "start_side=RIGHT")
  end
  return M._runner(args)
end

-- Fallback: post a single issue-level PR comment with all notes concatenated.
-- Used when the inline-review POST fails (typically because some note's
-- file:line isn't part of the PR's diff).
local function post_issue_comment(parsed, notes)
  local lines = { "## Review notes", "" }
  for _, n in ipairs(notes) do
    local range = (n.start_line == n.end_line)
      and tostring(n.start_line)
      or string.format("%d-%d", n.start_line, n.end_line)
    table.insert(lines, string.format("- `%s:%s` — %s", n.file, range, n.text or ""))
  end
  local body_path = vim.fn.tempname() .. ".md"
  local f, err = io.open(body_path, "w")
  if not f then return nil, err end
  f:write(table.concat(lines, "\n")); f:close()
  local out = M._runner({
    "api",
    string.format("repos/%s/%s/issues/%s/comments", parsed.owner, parsed.repo, parsed.number),
    "-X", "POST",
    "-F", "body=@" .. body_path,
  })
  vim.fn.delete(body_path)
  return out
end


local function parse_response_id(raw)
  if not raw or raw == "" then return nil end
  local ok, data = pcall(vim.json.decode, raw, { luanil = { object = true, array = true } })
  if not ok or type(data) ~= "table" then return nil end
  return data.id
end

function M.push(notes, opts)
  opts = opts or {}
  if #notes == 0 then return { ok = true, count = 0, posted = {} } end
  if not opts.pr or opts.pr == "" then
    return { ok = false, count = 0, err = "missing pr URL/ref", posted = {} }
  end
  local parsed = parse_pr(opts.pr)
  if not parsed then return { ok = false, count = 0, err = "unparseable pr URL", posted = {} } end

  local replies, regulars = {}, {}
  for _, n in ipairs(notes) do
    if n.kind == "original" or n.pushed then
      -- skip — already on the server
    elseif n.kind == "reply" then
      table.insert(replies, n)
    else
      table.insert(regulars, n)
    end
  end

  local count = 0
  local errors = {}
  local posted = {}
  local failures = {}

  local function fail(note, reason)
    if note.id then failures[note.id] = reason end
  end

  for _, n in ipairs(replies) do
    local out = post_reply(parsed, n)
    if out then
      count = count + 1
      local new_id = parse_response_id(out)
      if n.id then
        posted[n.id] = { kind = "original", pr_comment_id = new_id }
      end
    else
      table.insert(errors, "reply to " .. tostring(n.replies_to_id) .. " failed")
      fail(n, "reply to comment " .. tostring(n.replies_to_id) .. " failed")
    end
  end

  if #regulars > 0 then
    local sha = fetch_head_sha(opts.pr)
    if sha then
      local inline_failed = {}
      for _, n in ipairs(regulars) do
        local out = post_inline_comment(parsed, sha, n)
        if out then
          count = count + 1
          local new_id = parse_response_id(out)
          if n.id then
            posted[n.id] = { kind = "original", pr_comment_id = new_id }
          end
        else
          table.insert(inline_failed, n)
        end
      end
      if #inline_failed > 0 then
        vim.notify(string.format(
          "Inline rejected for %d note(s) (likely line not in diff); falling back to issue comment",
          #inline_failed), vim.log.levels.WARN)
        local out = post_issue_comment(parsed, inline_failed)
        if out then
          count = count + #inline_failed
          for _, n in ipairs(inline_failed) do
            if n.id then posted[n.id] = { pushed = true } end
          end
        else
          table.insert(errors, string.format("review comments: %d failed", #inline_failed))
          for _, n in ipairs(inline_failed) do
            fail(n, "inline rejected and issue-fallback also failed")
          end
        end
      end
    else
      -- No head SHA → fall back to issue comment for everything
      local out = post_issue_comment(parsed, regulars)
      if out then
        count = count + #regulars
        for _, n in ipairs(regulars) do
          if n.id then posted[n.id] = { pushed = true } end
        end
      else
        table.insert(errors, "review comments failed (no head SHA, issue fallback rejected)")
        for _, n in ipairs(regulars) do
          fail(n, "no head SHA and issue-fallback rejected")
        end
      end
    end
  end

  if #errors > 0 then
    return {
      ok = false, count = count,
      err = table.concat(errors, "; "),
      posted = posted, failures = failures,
    }
  end
  return { ok = true, count = count, posted = posted, failures = failures }
end

return M
