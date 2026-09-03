-- Where the note files live on disk. The only part of the plugin that writes
-- to the filesystem.

local issues = require("dk.linear.issues")

local M = {}

local DIR = ".dk-notes"

--- One notes directory per repository: `.dk-notes` at the git root, or in
--- `start_dir` itself when there is no repository. Searching for an existing
--- `.dk-notes` instead would let a stray nested one split an issue's notes
--- across two files depending on where nvim was opened.
--- Created on demand by `ensure`, not here.
--- @param start_dir string
--- @return string
function M.root(start_dir)
    -- No `type` filter: worktrees and submodules mark their root with a `.git`
    -- file rather than a directory.
    local git = vim.fs.find(".git", { path = start_dir, upward = true })[1]
    local base = git and vim.fs.dirname(git) or start_dir
    return base .. "/" .. DIR
end

--- A directory already claimed by this issue, whatever slug it was created
--- with. Matches the identifier exactly or followed by a dash, so EDU-12 never
--- claims EDU-123's directory.
--- @param root string
--- @param identifier string
--- @return string?
local function claimed_dir(root, identifier)
    if vim.fn.isdirectory(root) == 0 then
        return nil
    end
    for name, type in vim.fs.dir(root) do
        if type == "directory" and (name == identifier or vim.startswith(name, identifier .. "-")) then
            return name
        end
    end
    return nil
end

--- Path to an issue's notes, created empty if this is the first time. Reuses an
--- existing directory for the issue rather than making a second one when the
--- title has been reworded in Linear since.
--- @param root string
--- @param issue table
--- @return string path
function M.ensure(root, issue)
    local dirname = claimed_dir(root, issue.identifier)
        or issues.notes_dirname(issue.identifier, issue.branch)
    local path = issues.notes_path(root, dirname)
    if vim.fn.filereadable(path) == 1 then
        return path
    end
    vim.fn.mkdir(vim.fs.dirname(path), "p")
    vim.fn.writefile(issues.notes_template(issue.identifier), path)
    return path
end

return M
