all:
	git submodule update --init --recursive
	find . -maxdepth 1 -mindepth 1 -type d -not -name .git -exec basename {} \; | xargs -I {} stow -vv {}
