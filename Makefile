.PHONY: all bootstrap install-packages

all:
	git submodule update --init --recursive
	find . -maxdepth 1 -mindepth 1 -type d -not -name .git -not -name clanker -exec basename {} \; | xargs -I {} stow -vv --ignore='\.DS_Store' {}

# Install Arch packages referenced by the dotfiles (WM, bar, apps). Requires sudo.
# hyprshade and wlogout are AUR-only; paru handles those.
install-packages:
	sudo pacman -S --needed hyprland hypridle hyprlock hyprpaper waybar \
		wob hyprshot grim slurp swappy wl-clipboard \
		ghostty rofi nautilus playerctl pavucontrol brightnessctl \
		network-manager-applet power-profiles-daemon python-gobject imv mpv \
		gnome-calendar dunst pipewire pipewire-pulse wireplumber fzf
	paru -S --needed hyprshade wlogout oh-my-zsh-git ttf-firacode-nerd rofi-calc

# Build the Docker image for sandboxed AI chat (CodeCompanion + opencode/claude code).
bootstrap:
	@command -v docker >/dev/null || { echo "MISSING docker — chat container won't work"; exit 1; }
	docker build -f nvim/.config/nvim/docker/Dockerfile.chat -t dk-chat nvim/.config/nvim/docker/
