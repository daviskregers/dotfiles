local wt = require("code-agents.worktree")

describe("path", function()
  it("nests id under repo under root", function()
    assert.are.equal("/cache/wt/myrepo/agent-3", wt.path("/cache/wt", "myrepo", "agent-3"))
  end)
end)

describe("uuid", function()
  it("produces non-empty, distinct ids (no collisions across nvim restarts)", function()
    local a, b = wt.uuid(), wt.uuid()
    assert.is_true(#a > 0)
    assert.are_not.equal(a, b)
  end)
end)

describe("add_args", function()
  it("creates a branch at the seed ref in the worktree path", function()
    assert.are.same({ "worktree", "add", "-b", "code-agents/agent-3", "/wt/agent-3", "abc123" },
      wt.add_args("/wt/agent-3", "code-agents/agent-3", "abc123"))
  end)
end)

describe("remove_args", function()
  it("force-removes the worktree", function()
    assert.are.same({ "worktree", "remove", "--force", "/wt/agent-3" }, wt.remove_args("/wt/agent-3"))
  end)
end)

describe("diff_args", function()
  it("diffs the worktree against its seed base, no color", function()
    assert.are.same({ "diff", "--no-color", "abc123" }, wt.diff_args("abc123"))
  end)
end)

describe("diff (integration)", function()
  local function fresh_repo()
    local repo = vim.fn.tempname(); vim.fn.mkdir(repo, "p")
    local function git(...) vim.system({ "git", ... }, { cwd = repo }):wait() end
    git("init", "-q"); git("config", "user.email", "t@t"); git("config", "user.name", "t")
    vim.fn.writefile({ "original" }, repo .. "/f.txt"); git("add", "-A"); git("commit", "-qm", "init")
    return repo
  end

  it("returns ok=true with a real patch when the seed resolves and the worktree changed", function()
    local repo = fresh_repo()
    local wtpath = repo .. "/.wt/agent-1"
    wt.create(repo, wtpath, "code-agents/agent-1") -- seed = HEAD
    vim.fn.writefile({ "agent-edited" }, wtpath .. "/f.txt")

    local patch, ok = wt.diff(wtpath, "HEAD")
    assert.is_true(ok)
    assert.is_truthy(patch:find("agent-edited", 1, true))

    wt.discard(repo, wtpath); vim.fn.delete(repo, "rf")
  end)

  it("signals ok=false when the seed can't be resolved (NOT mistaken for 'no changes')", function()
    local repo = fresh_repo()
    local wtpath = repo .. "/.wt/agent-1"
    wt.create(repo, wtpath, "code-agents/agent-1")
    vim.fn.writefile({ "agent-edited" }, wtpath .. "/f.txt") -- real changes exist

    local _, ok = wt.diff(wtpath, "deadbeefdeadbeefdeadbeefdeadbeefdeadbeef") -- GC'd/lost seed
    assert.is_false(ok) -- must not report empty-patch success → callers won't discard the work

    wt.discard(repo, wtpath); vim.fn.delete(repo, "rf")
  end)
end)

describe("create (integration)", function()
  it("seeds the worktree from LIVE state — uncommitted changes are present", function()
    local repo = vim.fn.tempname(); vim.fn.mkdir(repo, "p")
    local function git(...) vim.system({ "git", ... }, { cwd = repo }):wait() end
    git("init", "-q"); git("config", "user.email", "t@t"); git("config", "user.name", "t")
    vim.fn.writefile({ "line1" }, repo .. "/f.txt"); git("add", "-A"); git("commit", "-qm", "init")
    vim.fn.writefile({ "line1", "line2-uncommitted" }, repo .. "/f.txt") -- live, not committed

    local wtpath = repo .. "/.wt/agent-1"
    local ok = wt.create(repo, wtpath, "code-agents/agent-1")
    assert.is_true(ok)
    assert.are.same({ "line1", "line2-uncommitted" }, vim.fn.readfile(wtpath .. "/f.txt"))

    wt.discard(repo, wtpath); vim.fn.delete(repo, "rf")
  end)

  it("apply merges the agent's worktree edits into the live tree", function()
    local repo = vim.fn.tempname(); vim.fn.mkdir(repo, "p")
    local function git(...) vim.system({ "git", ... }, { cwd = repo }):wait() end
    git("init", "-q"); git("config", "user.email", "t@t"); git("config", "user.name", "t")
    vim.fn.writefile({ "original" }, repo .. "/f.txt"); git("add", "-A"); git("commit", "-qm", "init")

    local wtpath = repo .. "/.wt/agent-1"
    wt.create(repo, wtpath, "code-agents/agent-1")
    vim.fn.writefile({ "agent-edited" }, wtpath .. "/f.txt")       -- agent's change in its worktree
    vim.fn.writefile({ "brand new" }, wtpath .. "/new.txt")        -- and a new file

    assert.are.equal("applied", wt.apply(repo, wtpath))
    assert.are.same({ "agent-edited" }, vim.fn.readfile(repo .. "/f.txt")) -- merged into live
    assert.are.same({ "brand new" }, vim.fn.readfile(repo .. "/new.txt"))

    wt.discard(repo, wtpath); vim.fn.delete(repo, "rf")
  end)

  it("prune clears a stale worktree registration (dir removed out-of-band)", function()
    local repo = vim.fn.tempname(); vim.fn.mkdir(repo, "p")
    local function git(...) return vim.system({ "git", "-C", repo, ... }, {}):wait() end
    git("init", "-q"); git("config", "user.email", "t@t"); git("config", "user.name", "t")
    vim.fn.writefile({ "x" }, repo .. "/f.txt"); git("add", "-A"); git("commit", "-qm", "init")

    local wtpath = repo .. "/.wt/agent-1"
    wt.create(repo, wtpath, "code-agents/agent-1")
    vim.fn.delete(wtpath, "rf")                                  -- dir vanishes (killed nvim, etc.)
    assert.is_truthy(git("worktree", "list").stdout:find("agent-1", 1, true)) -- still registered (stale)

    wt.prune(repo)
    assert.is_nil(git("worktree", "list").stdout:find("agent-1", 1, true))    -- registration cleared
    vim.fn.delete(repo, "rf")
  end)

  it("discard removes the worktree AND deletes its branch (no leak)", function()
    local repo = vim.fn.tempname(); vim.fn.mkdir(repo, "p")
    local function git(...) return vim.system({ "git", "-C", repo, ... }, {}):wait() end
    git("init", "-q"); git("config", "user.email", "t@t"); git("config", "user.name", "t")
    vim.fn.writefile({ "x" }, repo .. "/f.txt"); git("add", "-A"); git("commit", "-qm", "init")

    local wtpath = repo .. "/.wt/agent-1"
    wt.create(repo, wtpath, "code-agents/agent-1")
    assert.is_truthy(vim.trim(git("branch", "--list", "code-agents/agent-1").stdout) ~= "")

    wt.discard(repo, wtpath)
    assert.are.equal("", vim.trim(git("branch", "--list", "code-agents/agent-1").stdout)) -- branch gone
    vim.fn.delete(repo, "rf")
  end)

  it("reseed resets the worktree to the current live state (for redo after a conflict)", function()
    local repo = vim.fn.tempname(); vim.fn.mkdir(repo, "p")
    local function git(...) vim.system({ "git", ... }, { cwd = repo }):wait() end
    git("init", "-q"); git("config", "user.email", "t@t"); git("config", "user.name", "t")
    vim.fn.writefile({ "original" }, repo .. "/f.txt"); git("add", "-A"); git("commit", "-qm", "init")

    local wtpath = repo .. "/.wt/agent-1"
    wt.create(repo, wtpath, "code-agents/agent-1")
    vim.fn.writefile({ "agent-attempt" }, wtpath .. "/f.txt")  -- agent's (now-stale) work
    vim.fn.writefile({ "current-live" }, repo .. "/f.txt")     -- your newer live state

    wt.reseed(repo, wtpath)
    assert.are.same({ "current-live" }, vim.fn.readfile(wtpath .. "/f.txt")) -- worktree now matches live

    wt.discard(repo, wtpath); vim.fn.delete(repo, "rf")
  end)

  it("apply reports 'conflict' and leaves the live tree UNTOUCHED (agent will redo)", function()
    local repo = vim.fn.tempname(); vim.fn.mkdir(repo, "p")
    local function git(...) vim.system({ "git", ... }, { cwd = repo }):wait() end
    git("init", "-q"); git("config", "user.email", "t@t"); git("config", "user.name", "t")
    vim.fn.writefile({ "original" }, repo .. "/f.txt"); git("add", "-A"); git("commit", "-qm", "init")

    local wtpath = repo .. "/.wt/agent-1"
    wt.create(repo, wtpath, "code-agents/agent-1")               -- seed = HEAD (original)
    vim.fn.writefile({ "agent-edited" }, wtpath .. "/f.txt")      -- agent's change (vs original)
    vim.fn.writefile({ "you-diverged" }, repo .. "/f.txt")       -- your live change since seed

    assert.are.equal("conflict", wt.apply(repo, wtpath))
    assert.are.same({ "you-diverged" }, vim.fn.readfile(repo .. "/f.txt")) -- live untouched, no markers

    wt.discard(repo, wtpath); vim.fn.delete(repo, "rf")
  end)

  it("apply returns 'error' (NOT 'applied') when the diff fails — never silently discards", function()
    local repo = vim.fn.tempname(); vim.fn.mkdir(repo, "p")
    local function git(...) vim.system({ "git", ... }, { cwd = repo }):wait() end
    git("init", "-q"); git("config", "user.email", "t@t"); git("config", "user.name", "t")
    vim.fn.writefile({ "original" }, repo .. "/f.txt"); git("add", "-A"); git("commit", "-qm", "init")

    local wtpath = repo .. "/.wt/agent-1"
    wt.create(repo, wtpath, "code-agents/agent-1")
    vim.fn.writefile({ "agent-edited" }, wtpath .. "/f.txt") -- real work exists in the worktree

    -- Seed unresolvable (GC'd) → the diff command FAILS. It must NOT read as an empty
    -- patch → "applied" (which makes the caller discard the worktree). Surface "error".
    assert.are.equal("error", wt.apply(repo, wtpath, "deadbeefdeadbeefdeadbeefdeadbeefdeadbeef"))

    wt.discard(repo, wtpath); vim.fn.delete(repo, "rf")
  end)
end)
