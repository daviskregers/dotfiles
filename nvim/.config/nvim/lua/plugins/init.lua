vim.pack.add({
    'https://github.com/nvim-lua/plenary.nvim',
})

require("plugins.mini")
require("plugins.treesitter")
require("plugins.blink")
require("plugins.lsp")
require("plugins.oil")
require("plugins.telescope")
require("plugins.harpoon")
require("plugins.todo")
require("plugins.snacks")
require("plugins.mermaid")
require("plugins.notifications")
require("plugins.indentation-guides")
require("plugins.whichkey")
require("plugins.undotree")
require("plugins.local-config")
require("plugins.terminal")
require("plugins.diffview")
require("plugins.neogit")
require("plugins.gitsigns")
require("plugins.colorscheme")
require("plugins.http")

-- Kept (in use): agents = C-/ terminal hub · review-notes = <leader>r*.
require("agents")
require("review-notes")

-- code-agents / worktree-agents / llm-agent superseded by clank.nvim
-- (~/projects/productivity/clank.nvim), loaded below. Folders now orphaned — safe to delete.
require("plugins.clank")

vim.api.nvim_create_user_command("PackUpdate", ":lua vim.pack.update()<CR>", {})
