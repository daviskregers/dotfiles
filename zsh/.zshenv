# Ensure nix profile binaries are available in all zsh shells
# (including non-interactive ones used by Neovim plugins)
export PATH="$HOME/.nix-profile/bin:$PATH"
