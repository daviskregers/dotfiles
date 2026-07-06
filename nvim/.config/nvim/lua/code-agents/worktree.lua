-- Git worktree lifecycle for background command agents. Each agent works in a
-- throwaway worktree seeded from your LIVE state, so it never touches your real
-- files until you accept its diff. Pure arg/path builders are tested; the git
-- calls are the thin impure shell.
local M = {}

M.branch_prefix = "code-agents/"

-- Unique id for an agent's worktree/branch — collision-proof across nvim
-- restarts (unlike a per-process counter). uuidgen, else time+random hex.
function M.uuid()
  if vim.fn.executable("uuidgen") == 1 then
    local out = vim.trim(vim.fn.system("uuidgen"))
    if out ~= "" then return out:lower() end -- full UUID: valid for claude --session-id
  end
  return string.format("%x-%x-%x", os.time(), math.random(0, 0xffffff), math.random(0, 0xffffff))
end

function M.path(root, repo, id)
  return table.concat({ root, repo, id }, "/")
end

-- Create a branch at `seed` (a commit ref capturing live state) in the worktree.
function M.add_args(path, branch, seed)
  return { "worktree", "add", "-b", branch, path, seed }
end

function M.remove_args(path)
  return { "worktree", "remove", "--force", path }
end

-- Diff the worktree's current state against its seed base.
function M.diff_args(seed)
  return { "diff", "--no-color", seed }
end

-- ── impure lifecycle (git) ───────────────────────────────────────────────────

local function git(cwd, args)
  return vim.system(vim.list_extend({ "git" }, args), { cwd = cwd, text = true }):wait()
end

-- Commit ref capturing current LIVE (tracked) state — `git stash create` makes
-- the object without touching your stash/index. Falls back to HEAD if clean.
-- NOTE: untracked files aren't captured (stash create limitation).
function M.seed_ref(cwd)
  local res = git(cwd, { "stash", "create" })
  local sha = vim.trim(res.stdout or "")
  if res.code == 0 and sha ~= "" then return sha end
  return "HEAD"
end

-- Create a worktree at `path` on a fresh `branch` seeded from live state.
-- Returns ok(bool), seed(ref).
function M.create(cwd, path, branch)
  local seed = M.seed_ref(cwd)
  vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
  local res = git(cwd, M.add_args(path, branch, seed))
  return res.code == 0, seed
end

function M.discard(cwd, path)
  git(cwd, M.remove_args(path))
  git(cwd, { "branch", "-D", M.branch_prefix .. vim.fn.fnamemodify(path, ":t") }) -- no leaked branch
end

-- Clear stale worktree registrations (dirs removed out-of-band, e.g. killed nvim).
function M.prune(repo)
  git(repo, { "worktree", "prune" })
end

-- Reset a worktree to the repo's CURRENT live state (discarding the agent's
-- stale attempt) so it can redo after a merge conflict. Returns the new seed.
function M.reseed(repo, worktree)
  local seed = M.seed_ref(repo)
  git(worktree, { "reset", "--hard", seed })
  git(worktree, { "clean", "-fd" })
  return seed
end

-- The agent's full change set vs its seed, as a unified patch (staging -A so new
-- files are included). `seed` defaults to the worktree's own tracked baseline.
function M.diff(worktree, seed)
  git(worktree, { "add", "-A" })
  local res = git(worktree, { "diff", "--cached", "--binary", seed or "HEAD" })
  return res.stdout or ""
end

-- Merge the agent's worktree changes into the live tree. Checks FIRST — if the
-- patch won't apply cleanly (your tree diverged since seed), returns "conflict"
-- and leaves the live tree untouched (caller sends the agent back to redo).
-- Otherwise applies and returns "applied". "" patch → "applied" (nothing to do).
function M.apply(repo, worktree, seed)
  local patch = M.diff(worktree, seed)
  if vim.trim(patch) == "" then return "applied" end
  local tmp = vim.fn.tempname()
  local f = io.open(tmp, "w"); f:write(patch); f:close()
  local check = git(repo, { "apply", "--check", "--whitespace=nowarn", tmp })
  if check.code ~= 0 then vim.fn.delete(tmp); return "conflict" end
  git(repo, { "apply", "--whitespace=nowarn", tmp })
  vim.fn.delete(tmp)
  return "applied"
end

return M
