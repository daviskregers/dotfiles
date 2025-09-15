# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a personal dotfiles repository containing configurations for various development tools and applications. The repository uses GNU Stow for managing symlinks and git submodules for external dependencies.

## Repository Structure

The repository is organized into tool-specific directories, each containing configuration files that will be symlinked to the appropriate locations in the home directory:

- `nvim/` - Neovim configuration with Lazy.nvim plugin manager
- `tmux/` - Tmux configuration with custom toggle panes and AI integration
- `zsh/` - Zsh shell configuration with Oh My Zsh
- `git/` - Git configuration
- `wezterm/` - WezTerm terminal emulator configuration
- `common/` - Shared shell functions and environment variables
- `aerospace/` - AeroSpace tiling window manager (macOS)
- `i3/` - i3 window manager configuration
- `lazygit/` - LazyGit TUI configuration
- `dunst/` - Dunst notification daemon configuration
- `gtk/` - GTK theme and appearance settings
- `albert/` - Albert launcher configuration
- `xmonad/` - XMonad window manager configuration
- `opencode/` - OpenCode configuration
- `claude/` - Claude Code specific configurations

## Installation and Setup Commands

### Initial Setup
```bash
# Install GNU Stow (package manager dependent)
sudo pacman -S stow  # Arch Linux
brew install stow    # macOS

# Clone and setup dotfiles
git clone git@github.com:daviskregers/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
make
```

### Management Commands
```bash
# Install all configurations
make

# Update git submodules and reinstall
git submodule update --init --recursive
make

# Install specific configuration
stow nvim      # Install only Neovim config
stow tmux      # Install only Tmux config
stow -D nvim   # Remove Neovim config symlinks
```

## Architecture and Key Features

### Stow-based Management
- Each directory represents a "package" that gets stowed to `$HOME`
- Files maintain their relative directory structure when symlinked
- Example: `nvim/.config/nvim/init.lua` → `~/.config/nvim/init.lua`

### Git Submodules
- `tmux/.tmux/plugins/tpm` - Tmux Plugin Manager for tmux plugins

### Shared Components
- `common/.functions` - Shared shell functions across shells
- `common/.variables` - Environment variables and PATH configurations
- `common/.bin/` - Custom utility scripts

### Tmux Integration Features
- **Toggle Panes**: Alt+key combinations for monitoring tools (htop, btop, etc.)
- **AI Tools Integration**: Alt+A for AI assistance pane
- **State Preservation**: Hidden session architecture maintains pane state
- **Custom Scripts**: Session management and cheat sheet integration

### Neovim Configuration
- **Lazy.nvim**: Modern plugin manager with lazy loading
- **LSP Integration**: Language servers for Lua, Go, PHP, C#
- **Custom Terminal System**: Multi-terminal management
- **AI Integration**: Project-specific AI snippets and tools
- **Local Configuration**: Project-specific settings via `.nvim.lua`

## Development Workflow

### Tmux Workflow
- Start with `tmux` or use `tmux-sessionizer` (prefix + f)
- Use Alt+A for AI tools, Alt+T for monitoring
- Toggle panes preserve state when hidden/restored

### Neovim Development
- Language-specific commands: `<leader>te` (test), `<leader>tl` (lint), `<leader>tr` (run)
- LSP navigation: `gd` (definition), `grr` (references), `grn` (rename)
- AI snippets: `<leader>zi` (auto-submit), `<leader>zI` (insert only)

### Shell Environment
- Zsh with Oh My Zsh and custom theme
- FastFetch system info on shell startup
- Task Master aliases: `tm`, `taskmaster`
- Environment sourced from `~/.variables` and `~/.functions`

## Configuration Notes

### Path Management
- OpenCode binary: `/Users/daviskregers/.opencode/bin`
- Custom functions sourced from `~/.functions`
- Variables sourced from `~/.variables`

### Platform-Specific Configurations
- **macOS**: AeroSpace, WezTerm
- **Linux**: i3, dunst, X11-based tools
- **Cross-platform**: Neovim, tmux, zsh, git

### Security Considerations
- No sensitive data should be committed to this public repository
- API keys and tokens should be stored in separate, non-tracked files
- Local environment variables should go in `~/.variables` (not tracked if sensitive)

## Customization

### Adding New Configurations
1. Create new directory with tool name
2. Add configuration files in appropriate subdirectory structure
3. Run `stow <tool-name>` to install
4. Add to Makefile if needed for automated installation

### Local Overrides
- Neovim: Use `.nvim.lua` in project roots for project-specific settings
- Shell: Local variables in `~/.variables` (sourced by zsh)
- Tmux: Local session management via tmux-sessionizer

This repository follows a modular approach where each tool's configuration is self-contained and can be installed independently while sharing common utilities and functions.