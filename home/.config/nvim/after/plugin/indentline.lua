local status_ok, indent_blankline = pcall(require, "ibl")
if not status_ok then
    print "Failed loading plugin 'indent_blankline', skipping setup..."
    return
end

indent_blankline.setup({
})
