OS      ?= $(shell uname -s | tr '[:upper:]' '[:lower:]')
PROFILE ?= personal
SKIP    ?=
-include config.mk

MAKEFLAGS += --no-print-directory

NON_MODULES := clanker
INFRA       := mk scripts
ALL         := $(patsubst %/Makefile,%,$(wildcard */Makefile))
DEPLOYABLE  := $(filter-out $(NON_MODULES),$(ALL))
MODULES     := $(filter-out $(SKIP),$(DEPLOYABLE))
IGNORED     := $(filter-out $(ALL) $(INFRA),$(patsubst %/,%,$(wildcard */)))
TARGETS     := $(if $(MODULE),$(MODULE),$(DEPLOYABLE))
NEED_GEN    := $(filter claude opencode,$(TARGETS))

# A targeted MODULE= run ignores SKIP.
EFFECTIVE_SKIP := $(if $(MODULE),,$(SKIP))
export PROFILE EFFECTIVE_SKIP FORCE APPLY

.PHONY: all stow-all list doctor install-packages install-packages-mac
.NOTPARALLEL:

all: stow-all

# Temporary Phase 1 installer. Stow stays in charge until the module
# migration reaches it; this still over-deploys docs/.dk-notes.
stow-all:
	git submodule update --init --recursive
	find . -maxdepth 1 -mindepth 1 -type d -not -name .git -not -name clanker -exec basename {} \; | xargs -I {} stow -vv --ignore='\.DS_Store' {}

list:
	@echo "profile=$(PROFILE) os=$(OS)"
	@for m in $(DEPLOYABLE); do $(MAKE) -C $$m describe || exit 1; done
	@echo "non-modules: $(NON_MODULES)"
	@echo "ignored: $(IGNORED)"

doctor:
	$(MAKE) -C clanker doctor

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
