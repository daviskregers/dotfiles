MODULE := $(notdir $(CURDIR))
OS     ?= $(shell uname -s | tr '[:upper:]' '[:lower:]')
PROFILE ?= personal
EFFECTIVE_SKIP ?=
DOTCTL := python3 ../scripts/dotctl.py

.PHONY: describe

describe:
	@$(DOTCTL) describe --module "$(MODULE)" --profile "$(PROFILE)" \
		--platform "$(OS)" --platforms "$(PLATFORMS)" \
		--profiles "$(PROFILES)" --skip "$(EFFECTIVE_SKIP)"
