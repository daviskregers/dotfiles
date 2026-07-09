local core = require("worktree-agents.core")

describe("current_default_provider", function()
  it("prefers the project .dk-notes/.agent like the C-/ picker", function()
    local cwd = vim.fn.getcwd()
    local root = vim.fn.tempname()
    local notes = root .. "/.dk-notes"
    vim.fn.mkdir(notes, "p")
    vim.fn.writefile({ "opencode" }, notes .. "/.agent")
    core.default_agent_file = nil
    vim.cmd("cd " .. vim.fn.fnameescape(root))
    assert.are.equal("opencode", core.current_default_provider())
    vim.cmd("cd " .. vim.fn.fnameescape(cwd))
    vim.fn.delete(root, "rf")
  end)

  it("reads opencode from the shared .agent file", function()
    local p = vim.fn.tempname()
    vim.fn.writefile({ "opencode" }, p)
    core.default_agent_file = p
    assert.are.equal("opencode", core.current_default_provider())
    vim.fn.delete(p)
    core.default_agent_file = nil
  end)

  it("maps claude-family agent names like haiku back to the claude provider", function()
    local p = vim.fn.tempname()
    vim.fn.writefile({ "haiku" }, p)
    core.default_agent_file = p
    assert.are.equal("claude", core.current_default_provider())
    vim.fn.delete(p)
    core.default_agent_file = nil
  end)
end)
