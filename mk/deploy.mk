MODULE := $(notdir $(CURDIR))
OS     ?= $(shell uname -s | tr '[:upper:]' '[:lower:]')
PROFILE ?= personal
EFFECTIVE_SKIP ?=
DEPS ?=
POST_INSTALL ?=
DOTCTL := python3 ../scripts/dotctl.py

ACTIVE := 1
ifneq ($(strip $(PLATFORMS)),)
  ifeq ($(filter $(OS),$(PLATFORMS)),)
    ACTIVE :=
  endif
endif
ifneq ($(strip $(PROFILES)),)
  ifeq ($(filter $(PROFILE),$(PROFILES)),)
    ACTIVE :=
  endif
endif
ifneq ($(filter $(MODULE),$(EFFECTIVE_SKIP)),)
  ACTIVE :=
endif

.PHONY: describe status plan install uninstall deps post-install

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
	@if [ -n "$(ACTIVE)" ]; then $(MAKE) post-install; fi

uninstall:
	@$(DOTCTL) uninstall --module "$(MODULE)" --profile "$(PROFILE)" \
		--platform "$(OS)" --platforms "$(PLATFORMS)" \
		--profiles "$(PROFILES)" --skip "$(EFFECTIVE_SKIP)" \
		--home "$(HOME)"

deps:
	@$(if $(DEPS),$(DEPS),:)

post-install:
	@$(if $(POST_INSTALL),$(POST_INSTALL),:)
