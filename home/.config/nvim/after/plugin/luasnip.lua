-- be sure to load this first since it overwrites the snippets table.
local ok_s, snipmate = pcall(require, 'luasnip.loaders.from_snipmate')
local ok_v, vscode = pcall(require, 'luasnip.loaders.from_vscode')

if not ok_s then
	print "Failed loading plugin 'luasnip.loaders.from_snipmate', skipping setup..."
else
	snipmate.lazy_load()
	snipmate.load({ paths = './snippets'})
end

if not ok_v then
	print "Failed loading plugin 'luasnip.loaders.from_vscode', skipping setup..."
else
	vscode.lazy_load()
end
