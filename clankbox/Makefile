.PHONY: build install setup policy test clean help

help:
	@echo "make install  symlink the clankbox CLI into ~/.bin"
	@echo "make setup    one-time host prep: init default-deny policy + allowlist"
	@echo "make build    build the sandbox image and load it into sbx"
	@echo "make policy   re-apply the default network allowlist to sbx"
	@echo "make test     run the shell-seam tests (no sbx needed)"
	@echo "make clean    remove the built image tar"

install:
	./clankbox install

setup:
	./clankbox setup

build:
	./clankbox build

policy:
	./clankbox policy

test:
	bash test/seams.sh

clean:
	rm -f clankbox-image.tar
