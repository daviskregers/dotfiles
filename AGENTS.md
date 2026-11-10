# dotfiles

## Packages

When a module needs a system package, add it to the lists in `packages/packages.mk` instead of installing it by hand:

- `PKGS_MAC` and `PKGS_MAC_CASK` are installed by `make install-packages-mac`.
- `PKGS_ARCH` and `PKGS_AUR` are installed by `make install-packages`.

A Homebrew formula from a third-party tap goes into `PKGS_MAC` with its fully qualified name (`owner/tap/formula`). If the tap repo isn't named `homebrew-*`, brew can't find it from that name alone, so also add an explicit `brew tap <name> <url>` line to `install-packages-mac` in the `Makefile`.
