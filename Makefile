.PHONY: all bootstrap

all: bootstrap
	git submodule update --init --recursive
	find . -maxdepth 1 -mindepth 1 -type d -not -name .git -not -name clanker -exec basename {} \; | xargs -I {} stow -vv --ignore='\.DS_Store' {}

# Build the Docker image for sandboxed AI chat (CodeCompanion + opencode/claude code).
bootstrap:
	@command -v docker >/dev/null || { echo "MISSING docker — chat container won't work"; exit 1; }
	docker build -f nvim/.config/nvim/docker/Dockerfile.chat -t dk-chat nvim/.config/nvim/docker/
