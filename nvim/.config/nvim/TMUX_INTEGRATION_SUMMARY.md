# Tmux Integration Summary

This document summarizes the changes made to integrate Neovim with tmux panes for AI and test functionality.

## Changes Made

### 1. Created tmux utility module (`lua/tmux.lua`)
- **Purpose**: Provides functions to interact with tmux panes
- **Key functions**:
  - `is_tmux()`: Check if running inside tmux
  - `send_to_ai_pane(command)`: Send commands to ALT+A pane
  - `send_to_test_pane(command)`: Send commands to ALT+T pane
  - `send_text_to_ai_pane(text)`: Send text to ALT+A pane without executing
  - `pane_exists(pane_id)`: Check if a tmux pane exists
  - `list_panes()`: List all available tmux panes

### 2. Modified AI terminal plugin (`lua/plugins/ai-terminal.lua`)
- **Changed from**: Internal Neovim terminals
- **Changed to**: tmux ALT+A pane
- **Key changes**:
  - Replaced terminal window creation with tmux pane checking
  - Updated AI state management to track active clients instead of terminal windows
  - Modified all AI interaction functions to use tmux commands
  - Updated cleanup functions to deactivate clients instead of closing terminals

### 3. Modified terminal system (`plugin/toggle-terminal.lua`)
- **Changed from**: Internal terminals for test commands
- **Changed to**: tmux ALT+T pane with fallback to internal terminals
- **Key changes**:
  - Added tmux import
  - Modified `RunScratchCommand` to use tmux ALT+T pane when available
  - Maintained fallback to internal terminals when not in tmux

## Usage

### AI Commands (ALT+A pane)
- `<leader>zc` - Activate Claude AI client
- `<leader>zo` - Activate OpenCode AI client  
- `<leader>zg` - Activate Cursor Agent AI client
- `<leader>zs` - Send file context to AI (normal mode)
- `<leader>zs` - Send selected code to AI (visual mode)
- `<leader>zS` - Send to AI without auto-submit
- `<leader>zi` - Open AI snippet picker (auto-submit)
- `<leader>zI` - Open AI snippet picker (no auto-submit)
- `<leader>zX` - Cleanup all AI clients

### Test Commands (ALT+T pane)
- `<leader>te` - Run tests
- `<leader>tl` - Run linter
- `<leader>tr` - Run application
- `<leader>tb` - Build project
- `<leader>tw` - Watch mode
- `<leader>tc` - Clean build
- `<leader>tf` - Format code

## Requirements

1. **Tmux session**: Neovim must be running inside a tmux session
2. **ALT+A pane**: Must exist for AI functionality
3. **ALT+T pane**: Must exist for test commands (optional, falls back to internal terminal)

## Fallback Behavior

- If not running in tmux: Commands fall back to internal Neovim terminals
- If ALT+A pane doesn't exist: AI commands will show error messages
- If ALT+T pane doesn't exist: Test commands will use internal terminal

## Testing

Run the test script to verify integration:
```lua
:source test_tmux_integration.lua
```

This will check:
- Tmux module loading
- Tmux session detection
- Pane existence
- Available panes listing