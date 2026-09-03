local notes = require("dk.linear.notes")
local issues = require("dk.linear.issues")

local function tmpdir()
    local dir = vim.fn.tempname()
    vim.fn.mkdir(dir, "p")
    return dir
end

local function read(path)
    return table.concat(vim.fn.readfile(path), "\n")
end

describe("notes.root", function()
    it("uses the git repository root, however deep in the tree I started", function()
        local repo = tmpdir()
        vim.fn.mkdir(repo .. "/.git", "p")
        vim.fn.mkdir(repo .. "/src/deep", "p")

        assert.are.equal(repo .. "/.dk-notes", notes.root(repo .. "/src/deep"))
    end)

    it("ignores a .dk-notes lying around below the repo root", function()
        -- One notes directory per repo. A stray nested one must not win, or the
        -- same issue gets two note files depending on where nvim was opened.
        local repo = tmpdir()
        vim.fn.mkdir(repo .. "/.git", "p")
        vim.fn.mkdir(repo .. "/src/.dk-notes", "p")

        assert.are.equal(repo .. "/.dk-notes", notes.root(repo .. "/src"))
    end)

    it("treats a .git file as a repo root too, so worktrees and submodules work", function()
        -- git worktrees and submodules get a `.git` *file* pointing at the real
        -- gitdir, not a directory.
        local worktree = tmpdir()
        vim.fn.writefile({ "gitdir: /elsewhere/.git/worktrees/x" }, worktree .. "/.git")
        vim.fn.mkdir(worktree .. "/src", "p")

        assert.are.equal(worktree .. "/.dk-notes", notes.root(worktree .. "/src"))
    end)

    it("uses the starting directory when there is no repository at all", function()
        local orphan = tmpdir()
        assert.are.equal(orphan .. "/.dk-notes", notes.root(orphan))
    end)
end)

describe("notes.ensure", function()
    it("creates <identifier>-<slug>/notes.md seeded with the template", function()
        local root = tmpdir() .. "/.dk-notes"

        local path = notes.ensure(root, { identifier = "EDU-123", branch = "davis/edu-123-fix-the-thing" })

        assert.are.equal(root .. "/EDU-123-fix-the-thing/notes.md", path)
        assert.are.equal(1, vim.fn.filereadable(path))
        assert.are.same(issues.notes_template("EDU-123"), vim.fn.readfile(path))
    end)

    it("leaves notes I already wrote alone", function()
        local root = tmpdir() .. "/.dk-notes"
        local issue = { identifier = "EDU-123", branch = "davis/edu-123-fix-the-thing" }
        local path = notes.ensure(root, issue)
        vim.fn.writefile({ "already thought about this" }, path)

        notes.ensure(root, issue)

        assert.are.equal("already thought about this", read(path))
    end)

    it("reuses the existing directory when the Linear title has been reworded", function()
        -- Otherwise a rename in Linear silently orphans every note I took: the
        -- slug changes, a fresh empty directory appears, the old one is lost.
        local root = tmpdir() .. "/.dk-notes"
        local path = notes.ensure(root, { identifier = "EDU-123", branch = "davis/edu-123-fix-the-thing" })
        vim.fn.writefile({ "notes from before the rename" }, path)

        local after = notes.ensure(root, { identifier = "EDU-123", branch = "davis/edu-123-completely-different" })

        assert.are.equal(path, after)
        assert.are.equal("notes from before the rename", read(after))
    end)

    it("does not mistake EDU-12 for EDU-123 when matching an existing directory", function()
        local root = tmpdir() .. "/.dk-notes"
        notes.ensure(root, { identifier = "EDU-123", branch = "davis/edu-123-the-big-one" })

        local short = notes.ensure(root, { identifier = "EDU-12", branch = "davis/edu-12-the-small-one" })

        assert.are.equal(root .. "/EDU-12-the-small-one/notes.md", short)
    end)
end)

describe("issues.render", function()
    local issue = {
        identifier = "ENG-7",
        title = "Fix the thing",
        url = "https://linear.app/acme/issue/ENG-7",
        branch = "dk/eng-7-fix-the-thing",
        state_name = "In Progress",
        description = "First paragraph.\n\nSecond paragraph.",
    }

    it("heads the buffer with the identifier and title", function()
        assert.are.equal("# ENG-7 Fix the thing", issues.render(issue)[1])
    end)

    it("carries status, branch and link", function()
        local text = table.concat(issues.render(issue), "\n")
        assert.is_truthy(text:find("In Progress", 1, true))
        assert.is_truthy(text:find("dk/eng-7-fix-the-thing", 1, true))
        assert.is_truthy(text:find("https://linear.app/acme/issue/ENG-7", 1, true))
    end)

    it("splits the description on newlines, since set_lines rejects embedded ones", function()
        for _, line in ipairs(issues.render(issue)) do
            assert.is_nil(line:find("\n", 1, true))
        end
        local text = table.concat(issues.render(issue), "\n")
        assert.is_truthy(text:find("First paragraph.", 1, true))
        assert.is_truthy(text:find("Second paragraph.", 1, true))
    end)

    it("says so when the issue has no description, rather than trailing off blank", function()
        -- Not tbl_extend: `description = nil` in a literal is simply an absent
        -- key, so it would never overwrite anything.
        local bare = vim.deepcopy(issue)
        bare.description = nil
        local text = table.concat(issues.render(bare), "\n")
        assert.is_truthy(text:lower():find("no description", 1, true))
    end)
end)
