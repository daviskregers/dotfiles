MODULE := $(notdir $(CURDIR))
OS     ?= $(shell uname -s | tr '[:upper:]' '[:lower:]')
PROFILE ?= personal
EFFECTIVE_SKIP ?=
DOTCTL := python3 ../scripts/dotctl.py

.PHONY: describe status plan install uninstall

describe:
	@$(DOTCTL) describe --module "$(MODULE)" --profile "$(PROFILE)" \
		--platform "$(OS)" --platforms "$(PLATFORMS)" \
		--profiles "$(PROFILES)" --skip "$(EFFECTIVE_SKIP)"

status:
	@$(DOTCTL) status --module "$(MODULE)" --profile "$(PROFILE)" \
		--platform "$(OS)" --platforms "$(PLATFORMS)" \
		--profiles "$(PROFILES)" --skip "$(EFFECTIVE_SKIP)" \
		--home "$(HOME)"

plan:
	@$(DOTCTL) plan --module "$(MODULE)" --profile "$(PROFILE)" \
		--platform "$(OS)" --platforms "$(PLATFORMS)" \
		--profiles "$(PROFILES)" --skip "$(EFFECTIVE_SKIP)" \
		--home "$(HOME)"

install:
	@$(DOTCTL) install --module "$(MODULE)" --profile "$(PROFILE)" \
		--platform "$(OS)" --platforms "$(PLATFORMS)" \
		--profiles "$(PROFILES)" --skip "$(EFFECTIVE_SKIP)" \
		--home "$(HOME)"

uninstall:
	@$(DOTCTL) uninstall --module "$(MODULE)" --profile "$(PROFILE)" \
		--platform "$(OS)" --platforms "$(PLATFORMS)" \
		--profiles "$(PROFILES)" --skip "$(EFFECTIVE_SKIP)" \
		--home "$(HOME)"
