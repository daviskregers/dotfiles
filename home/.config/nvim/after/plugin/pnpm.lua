local ok, telescope = pcall(require, 'telescope')

if not ok then
	print "Failed loading plugin 'telescope', skipping pnpm setup..."
	return
end

telescope.load_extension('pnpm')
