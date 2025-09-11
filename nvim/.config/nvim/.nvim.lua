AI_SNIPPETS = {
}

CONFIG_TEST_COMMANDS = {
    ["*"] = {
        build = "go build .",
        clean = "go clean",
        lint = "go golangci-lint run",
        run = "go run .",
        test = "go test -v ./...",
        watch = "gowatch test",
        format = "go fmt .",
    }
}
