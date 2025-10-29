# Tmux Toggle Panes

A simple, reliable system for creating toggleable panes in tmux with state preservation.

## Overview

Toggle panes are additional panes that can be shown/hidden with a single keypress. When hidden, they preserve their state (history, running processes, etc.) and can be restored later exactly as they were.

Each tmux window gets 4 independent toggle slots, accessible via the tmux prefix followed by `H/J/K/L` (Shift+hjkl).

## Keybindings

| Key | Toggle Slot |
|-----|-------------|
| `C-a H` | Toggle 1 |
| `C-a J` | Toggle 2 |
| `C-a K` | Toggle 3 (AI pane) |
| `C-a L` | Toggle 4 |

### Behavior

**From main pane:**
- First press: Creates toggle pane (30% width, right side)
- Second press: Hides toggle pane
- Third press: Restores toggle pane with preserved state

**From toggle pane:**
- Same key: Hides itself
- Different key: Creates that toggle (scoped to parent window)

**Example workflow:**
```
[main] → C-a H → [main][toggle-1]
                 C-a J → [main][toggle-1][toggle-2]
                 C-a H → [main][toggle-2]          (toggle-1 hidden)
                 C-a J → [main]                    (toggle-2 hidden)
                 C-a H → [main][toggle-1]          (restored with state)
```

## How It Works

### Marker Names

Each toggle pane is tracked using a marker name:
```
toggle_${SESSION_NUM}_${WINDOW_NUM}_${TOGGLE_ID}
```

**Example:** `toggle_5_54_1`
- Session: `5` (from session ID `$5`)
- Window: `54` (from window ID `@54`)
- Toggle: `1` (C-a H keybinding)

### Technical Implementation

1. **User Options**: Each toggle pane has a `@toggle_marker` user option set
2. **Hidden Session**: When hidden, panes are moved to `_toggle_hidden` session
3. **Window Scoping**: Toggles are scoped to windows, not panes (pane IDs change when splitting)
4. **Dimension Preservation**: Width/height stored in `@toggle_width` and `@toggle_height`

## Sending Commands to Toggle Panes

### Method 1: Using Marker Names Directly

If you know the marker name:
```bash
tmux send-keys -t ":toggle_5_54_1.0" "npm test" Enter
```

### Method 2: Construct Marker Name Dynamically

From a script or vim:
```bash
# Get current context
SESSION_ID=$(tmux display-message -p '#{session_id}')
WINDOW_ID=$(tmux display-message -p '#{window_id}')

# Strip special characters
SESSION_NUM=$(echo "$SESSION_ID" | tr -d '$@%')
WINDOW_NUM=$(echo "$WINDOW_ID" | tr -d '$@%')

# Construct marker for toggle 1
MARKER="toggle_${SESSION_NUM}_${WINDOW_NUM}_1"

# Send command
tmux send-keys -t ":${MARKER}.0" "npm test" Enter
```

### Method 3: From Vim Keybinding

Add to your `.vimrc` or neovim config:

```vim
" Run tests in toggle pane 1 (C-a H)
nnoremap <leader>tt :call RunInToggle(1, "npm test")<CR>

function! RunInToggle(toggle_id, command)
    " Get tmux context
    let session_id = system("tmux display-message -p '#{session_id}'")
    let window_id = system("tmux display-message -p '#{window_id}'")

    " Strip special chars
    let session_num = substitute(session_id, '[$@%\n]', '', 'g')
    let window_num = substitute(window_id, '[$@%\n]', '', 'g')

    " Construct marker
    let marker = 'toggle_' . session_num . '_' . window_num . '_' . a:toggle_id

    " Send command
    let cmd = 'tmux send-keys -t ":' . marker . '.0" "' . a:command . '" Enter'
    call system(cmd)
endfunction
```

### Method 4: Helper Script

Create `~/.local/bin/tmux-send-to-toggle`:

```bash
#!/bin/sh
# Usage: tmux-send-to-toggle <toggle_id> <command>
# Example: tmux-send-to-toggle 1 "npm test"

TOGGLE_ID="$1"
shift
COMMAND="$*"

# Get current context
SESSION_ID=$(tmux display-message -p '#{session_id}')
WINDOW_ID=$(tmux display-message -p '#{window_id}')

# Strip special characters
SESSION_NUM=$(echo "$SESSION_ID" | tr -d '$@%')
WINDOW_NUM=$(echo "$WINDOW_ID" | tr -d '$@%')

# Construct marker
MARKER="toggle_${SESSION_NUM}_${WINDOW_NUM}_${TOGGLE_ID}"

# Send command
tmux send-keys -t ":${MARKER}.0" "$COMMAND" Enter
```

Make it executable:
```bash
chmod +x ~/.local/bin/tmux-send-to-toggle
```

Usage:
```bash
tmux-send-to-toggle 1 "npm test"
tmux-send-to-toggle 2 "tail -f app.log"
```

## Common Use Cases

### Test Runner
```bash
# Create toggle 1, send test command
tmux-send-to-toggle 1 "npm test -- --watch"
```

### Log Viewer
```bash
# Create toggle 2, tail logs
tmux-send-to-toggle 2 "tail -f /var/log/app.log"
```

### Build Output
```bash
# Create toggle 3, run build
tmux-send-to-toggle 3 "npm run build -- --watch"
```

### REPL/Shell
```bash
# Create toggle 4, start interactive shell
tmux-send-to-toggle 4 "python"
```

## Advanced Usage

### Ensure Toggle Exists Before Sending

```bash
# Check if toggle exists (is visible)
check_toggle_exists() {
    TOGGLE_ID="$1"
    SESSION_ID=$(tmux display-message -p '#{session_id}')
    WINDOW_ID=$(tmux display-message -p '#{window_id}')
    SESSION_NUM=$(echo "$SESSION_ID" | tr -d '$@%')
    WINDOW_NUM=$(echo "$WINDOW_ID" | tr -d '$@%')
    MARKER="toggle_${SESSION_NUM}_${WINDOW_NUM}_${TOGGLE_ID}"

    # Check if any pane has this marker
    for pane in $(tmux list-panes -F '#{pane_id}'); do
        marker=$(tmux show-option -pqv -t "$pane" @toggle_marker 2>/dev/null || true)
        if [ "$marker" = "$MARKER" ]; then
            return 0  # Exists
        fi
    done
    return 1  # Doesn't exist
}

# Use it
if ! check_toggle_exists 1; then
    echo "Toggle 1 doesn't exist. Press C-a H to create it first."
    exit 1
fi

tmux-send-to-toggle 1 "npm test"
```

### Show Toggle If Hidden

```bash
# If toggle is hidden, show it by sending the keybind
show_toggle() {
    TOGGLE_ID="$1"

    if ! check_toggle_exists "$TOGGLE_ID"; then
        # Simulate the keybinding (C-a followed by Shift+hjkl)
        case "$TOGGLE_ID" in
            1) tmux send-keys C-a H ;;
            2) tmux send-keys C-a J ;;
            3) tmux send-keys C-a K ;;
            4) tmux send-keys C-a L ;;
        esac
        sleep 0.1  # Wait for toggle to appear
    fi
}

# Use it
show_toggle 1
tmux-send-to-toggle 1 "npm test"
```

## Troubleshooting

### Toggle panes not hiding properly
- Reload tmux config: `Prefix + R` (requires reopening tmux session for new keybindings)
- Check markers: `tmux list-panes -F '#{pane_id}:#{@toggle_marker}'`

### Commands not reaching toggle pane
- Verify toggle exists: `tmux list-panes -F '#{pane_id}:#{@toggle_marker}'`
- Check marker name matches what you're targeting
- Ensure toggle is visible (not hidden)

### Dimension not preserved
- User options `@toggle_width` and `@toggle_height` may not be set
- Check: `tmux show-option -pqv -t PANE_ID @toggle_width`

## Debug Mode

Enable debug logging:
```bash
DEBUG=1 ~/.local/bin/tmux-toggle 1
cat /tmp/tmux-toggle-debug.log
```

Or enable for all keybindings by editing `.tmux.conf`:
```tmux
bind-key 'H' run-shell "DEBUG=1 ~/.local/bin/tmux-toggle 1"
```

## Files

- `~/.local/bin/tmux-toggle` - Main toggle script
- `~/.tmux.conf` - Keybindings (lines 47-51)
- Session `_toggle_hidden` - Hidden toggles storage

## Implementation Details

### Why Window-Level Scoping?

Initially, toggles were scoped to panes, but **tmux reassigns pane IDs when splitting**. This caused markers to become invalid. Window-level scoping is more stable and simpler.

### Why Not Use Pane Titles?

Pane titles change automatically based on running commands (vim, shell, etc.). User options (`@toggle_marker`) are persistent and never change.

### Hidden Session Architecture

When toggles are hidden, they're moved to the `_toggle_hidden` session as windows. This keeps your main session clean and allows easy cleanup:

```bash
# View hidden toggles
tmux attach -t _toggle_hidden

# Clean up all hidden toggles
tmux kill-session -t _toggle_hidden
```
