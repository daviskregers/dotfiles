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

-- LEGACY / slop — to rewrite. Each is independent; delete the line + its lua/ folder to drop.
require("agents")
require("review-notes")
require("worktree-agents")

vim.api.nvim_create_user_command("PackUpdate", ":lua vim.pack.update()<CR>", {})
