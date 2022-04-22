local global = vim.o

vim.g.tokyonight_style = "day"
vim.g.tokyonight_italic_functions = true
vim.g.tokyonight_sidebars = { "qf", "vista_kind", "terminal", "packer" }
vim.g.tokyonight_colors = { hint = "orange", error = "#ff0000" }
vim.g.tokyonight_transparent = true
vim.g.tokyonight_transparent_sidebar = true

local colorbuddy = require('colorbuddy')
colorbuddy.colorscheme('tokyonight')
local Color, colors, Group, groups, styles = colorbuddy.setup()

-- Use Color.new(<name>, <#rrggbb>) to create new colors
-- They can be accessed through colors.<name>
Color.new('red',         '#cc6666')
Color.new('grey27',      '#a0a0a0')

-- Define highlights in relative terms of other colors
Group.new('Error', colors.red, nil, styles.bold)
Group.new('Comment', colors.red, nil, styles.bold)
Group.new('ColorColumn', colors.white, colors.red, styles.bold)

-- red comments and errors
vim.cmd("hi Comment ctermfg=darkred")
vim.cmd("hi SyntasticError ctermfg=144 ctermbg=9")
vim.cmd("hi SyntasticStyleError ctermfg=144 ctermbg=9")
vim.cmd("hi SyntasticStyleWarning ctermfg=144 ctermbg=9")
vim.cmd("hi SyntasticWarning ctermfg=144 ctermbg=9")

-- transparent background
vim.cmd("hi! NonText ctermbg=NONE guibg=NONE")
vim.cmd("hi! Normal ctermbg=NONE guibg=NONE")
vim.cmd('au VimEnter * hi! NonText ctermbg=NONE guibg=NONE')
vim.cmd('au VimEnter * hi! Normal ctermbg=NONE guibg=NONE')

-- blame line
Group.new('BlameLine', colors.grey27)
