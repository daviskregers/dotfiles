-- code-agents: editor-anchored parallel LLM agents.
-- Spec/status: .dk-notes/plans/code-agents-status.md
local M = require("code-agents.core")
require("code-agents.keymaps")
pcall(require("code-agents.permission").load_allow_rules) -- reuse claude's pre-approvals
vim.schedule(function() pcall(M.reattach) end) -- resume prior agents' worktrees after restart
return M
