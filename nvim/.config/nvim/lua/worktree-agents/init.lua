-- LEGACY / to-rewrite. Worktree agents (<leader>w*).
-- Remove this folder + its require() line in plugins/init.lua to drop it.
local M = require("worktree-agents.core")
require("worktree-agents.keymaps")
return M
