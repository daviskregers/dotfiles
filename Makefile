.PHONY: all install-packages install-packages-mac

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

# Install macOS packages referenced by the dotfiles (WM, keyboard, terminal, CLI).
# karabiner-elements runs a pkg installer, so brew will ask for the sudo password.
install-packages-mac:
	brew install --cask nikitabobko/tap/aerospace karabiner-elements ghostty \
		font-fira-code-nerd-font 1password claude-code@latest
	brew install stow tmux neovim fzf ripgrep zsh tree-sitter-cli opencode
