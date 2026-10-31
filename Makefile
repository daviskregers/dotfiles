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

.PHONY: all stow-all install uninstall deps setup list status plan legacy doctor install-packages install-packages-mac
.NOTPARALLEL:

all: stow-all

# Temporary Phase 2 installer. A targeted MODULE= run uses the new
# per-module install; a full `make install` still runs stow until Phase 5.
install:
	@if [ -n "$(MODULE)" ]; then \
		$(MAKE) -C $(MODULE) install; \
	else \
		$(MAKE) stow-all; \
	fi

uninstall:
	@for m in $(TARGETS); do $(MAKE) -C $$m uninstall || exit 1; done

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

status:
	@fail=0; for m in $(TARGETS); do \
		out=$$($(MAKE) -C $$m status 2>&1); rc=$$?; \
		printf '%s\n' "$$out" | grep -v '^make\[[0-9]*\]: \*\*\*'; \
		[ $$rc -eq 0 ] || fail=1; \
	done; exit $$fail

plan:
	@for m in $(TARGETS); do $(MAKE) -C $$m plan || exit 1; done

legacy:
	@python3 scripts/dotctl.py legacy --repo-root "$(CURDIR)" --home "$(HOME)" --non-modules "$(NON_MODULES)" $(if $(APPLY),--apply)

doctor:
	$(MAKE) -C clanker doctor

deps:
	@if [ -z "$(MODULE)" ]; then $(MAKE) -C clanker bootstrap; fi
	@for m in $(TARGETS); do $(MAKE) -C $$m deps || exit 1; done

setup: doctor deps install

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
