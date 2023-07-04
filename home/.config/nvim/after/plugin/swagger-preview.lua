local ok, swagger = pcall(require, 'swagger-preview')

if not ok then
	print "Failed to load plugin 'swagger-preview', skipping setup..."
	return
end

swagger.setup({
    port = 44556,
    host = "localhost",
})
