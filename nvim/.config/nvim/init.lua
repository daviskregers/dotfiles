vim.loader.enable()

require("settings")
require("plugins.init")

require("dk.triage")
require("dk.linear")
require("dk.disk_reload").setup()
