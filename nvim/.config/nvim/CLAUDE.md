# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a personal Neovim configuration built on top of the Lazy.nvim plugin manager. The configuration is structured as a modular setup with custom plugins, key bindings, and development workflows.

## Architecture

### Core Structure
- `init.lua` - Entry point that loads settings, remaps, and lazy plugin manager
- `lua/settings.lua` - Core Neovim settings and options
- `lua/remaps.lua` - Custom key mappings
- `lua/config/lazy.lua` - Lazy.nvim plugin manager configuration
- `lua/plugins/` - Individual plugin configurations organized by functionality
- `plugin/toggle-terminal.lua` - Custom terminal management system
- `snippets/` - Custom code snippets for various languages

### Plugin Organization
Each plugin is configured in its own file under `lua/plugins/`:
- `lsp.lua` - LSP configuration with Mason, Blink completion, and language servers
- `telescope.lua` - Fuzzy finder with custom multigrep functionality
- `file-explorer.lua` - Oil.nvim file management
- `git.lua` - Git integration with Neogit and Gitsigns  
- `ai.lua` - AI-powered coding assistance
- `harpoon.lua` - Quick file navigation
- `treesitter.lua` - Syntax highlighting and parsing
- `trouble.lua` - Diagnostics and error management

### Key Features
- **Lazy Loading**: Uses lazy.nvim for optimized plugin loading
- **LSP Integration**: Configured language servers for Lua, Go, PHP, and C#
- **Custom Terminal System**: Multi-terminal management with floating and split terminals
- **Dynamic Test Commands**: Language-specific test/build/lint commands via local config
- **Local Configuration**: Support for project-specific settings via nvim-config-local

## Development Commands

### Terminal System
The configuration includes a sophisticated terminal management system accessible via:
- `<leader>ts` - Toggle scratch terminal (split window)
- `<leader>tS` - Toggle floating terminal
- `<leader>tg` - Toggle LazyGit terminal

### Language-Specific Commands  
Dynamic key bindings are created based on filetype:
- `<leader>te` - Run tests
- `<leader>tl` - Run linter
- `<leader>tr` - Run application
- `<leader>tb` - Build project
- `<leader>tw` - Watch mode
- `<leader>tc` - Clean build
- `<leader>tf` - Format code

Use uppercase versions (e.g., `<leader>tE`) to set additional arguments for commands.

### Default Test Commands
- **Go**: `go test`, `go run .`
- **TypeScript/JavaScript**: `pnpm test`, `pnpm lint`
- **PHP**: `composer test %`
- **Docker**: `docker build .`

## LSP Configuration

### Configured Language Servers
- **lua_ls** - Lua language server with lazydev.nvim for Neovim API
- **gopls** - Go language server
- **intelephense** - PHP language server  
- **omnisharp** - C# language server with extensive configuration

### LSP Key Bindings
- `gd` - Go to definition
- `grr` - Find references
- `grn` - Rename symbol
- `gca` - Code actions
- `K` - Hover documentation
- `<C-h>` - Signature help (insert mode)
- `[d`/`]d` - Navigate diagnostics
- `<leader>f` - Format buffer
- `<leader>dl` - Toggle LSP lines diagnostic display

## Important Settings
- Leader key: `<space>`
- Local leader: `\`
- 4-space indentation
- Relative line numbers enabled
- Persistent undo with ~/.vim/undodir
- Auto-formatting on save (can be disabled with `CONFIG_DISABLE_FORMATTING`)
- Custom colorcolumn configuration via `custom/colorcolumn.lua`

## Tmux Integration
The configuration integrates with tmux panes for AI and test functionality:
- **AI Commands**: Route to `toggle_ai_tools` pane (found by title, not hardcoded ID)
- **Test Commands**: Route to `toggle_zsh_t` pane (found by title, not hardcoded ID)
- **Dynamic Detection**: Pane IDs are discovered at runtime for reliability
- **Command Escaping**: Uses single quotes to prevent shell interpretation issues

## Local Configuration Support
Projects can override settings by placing a `.nvim.lua` file in the project root. This file can define:
- `CONFIG_TEST_COMMANDS` - Custom test/build/lint commands per filetype
- `CONFIG_DISABLE_FORMATTING` - Disable auto-formatting
- `AI_SNIPPETS` - Project-specific AI prompt snippets
- Other project-specific configurations

### AI Snippets
Project-specific AI snippets can be defined in `.nvim.lua`:
```lua
AI_SNIPPETS = {
  ["Debug this function"] = "Please help me debug this function. Look for potential issues with error handling, edge cases, and performance.",
  ["Add tests"] = "Please write comprehensive tests for this code including unit tests and edge cases.",
  ["Review architecture"] = "Please review this code's architecture and suggest improvements for maintainability and scalability."
}
```

### AI Snippet Commands
Pre-defined AI prompts can be quickly inserted into terminals:
- `:AISnippet` - Open telescope picker to select snippet
- `:AISnippet <name>` - Insert specific snippet directly (supports tab completion)
- `:AISnippetAdd` - Add new global snippet with category selection
- `<leader>zi` - Open AI snippet picker (auto-submit) - automatically sends selected snippet to AI
- `<leader>zI` - Open AI snippet picker (no auto-submit) - inserts snippet without sending to AI
- Global snippets stored in `~/.config/nvim/ai-snippets/*.txt`
- Project snippets defined via `AI_SNIPPETS` in `.nvim.lua`

## Code Quality Standards
The configuration follows these quality standards:
- **Security First**: Path traversal protection, command injection prevention, file validation
- **Error Handling**: Centralized error reporting with `handle_error()` function
- **Performance**: Optimized caching with race condition protection
- **Maintainability**: Constants for magic numbers, refactored complex functions
- **Reliability**: Dynamic pane detection, proper resource cleanup

## Snippets
Custom snippets are available for Go, Lua, and PHP in VSCode-compatible JSON format under the `snippets/` directory.