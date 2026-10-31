OS      ?= $(shell uname -s | tr '[:upper:]' '[:lower:]')
PROFILE ?= personal
SKIP    ?=
-include config.mk
-include packages/packages.mk

MAKEFLAGS += --no-print-directory

NON_MODULES := clanker
INFRA       := mk scripts packages
ALL         := $(patsubst %/Makefile,%,$(wildcard */Makefile))
DEPLOYABLE  := $(filter-out $(NON_MODULES),$(ALL))
MODULES     := $(filter-out $(SKIP),$(DEPLOYABLE))
IGNORED     := $(filter-out $(ALL) $(INFRA),$(patsubst %/,%,$(wildcard */)))
TARGETS     := $(if $(MODULE),$(MODULE),$(DEPLOYABLE))
NEED_GEN    := $(filter claude opencode,$(TARGETS))

# A targeted MODULE= run ignores SKIP.
EFFECTIVE_SKIP := $(if $(MODULE),,$(SKIP))
export PROFILE EFFECTIVE_SKIP FORCE APPLY

.PHONY: all stow-all install uninstall deps setup gen check list status plan legacy packages doctor install-packages install-packages-mac
.NOTPARALLEL:

all: install

install: $(if $(NEED_GEN),gen)
	@for m in $(TARGETS); do $(MAKE) -C $$m install || exit 1; done

uninstall:
	@for m in $(TARGETS); do $(MAKE) -C $$m uninstall || exit 1; done

# Manual rollback to the old stow layout. Not part of the normal flow.
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

gen:
	@command -v go >/dev/null || { echo "MISSING go — cannot regenerate; run make doctor"; exit 1; }
	$(MAKE) -C clanker gen

setup: doctor deps install

check: status
	@python3 scripts/dotctl.py check --repo-root "$(CURDIR)" --non-modules "$(NON_MODULES)"
	$(MAKE) -C clanker check
	@python3 -m unittest discover -s scripts/tests -p 'test_*.py'
	@bash scripts/check-home.sh

packages:
	@echo "arch: $(PKGS_ARCH)"
	@echo "aur: $(PKGS_AUR)"
	@echo "mac: $(PKGS_MAC)"
	@echo "mac-cask: $(PKGS_MAC_CASK)"

# Install Arch packages referenced by the dotfiles (WM, bar, apps). Requires sudo.
# hyprshade and wlogout are AUR-only; paru handles those.
install-packages:
	sudo pacman -S --needed $(PKGS_ARCH)
	paru -S --needed $(PKGS_AUR)

# Install macOS packages referenced by the dotfiles (WM, keyboard, terminal, CLI).
# karabiner-elements runs a pkg installer, so brew will ask for the sudo password.
install-packages-mac:
	brew install --cask $(PKGS_MAC_CASK)
	brew install $(PKGS_MAC)
