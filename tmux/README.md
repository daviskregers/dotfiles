# Tmux Toggle Panes

This configuration adds toggleable panes to your tmux setup with state preservation.

## Features

- **State Preservation**: When you toggle a pane off and back on, it maintains its previous state
- **Multiple Terminal Types**: Different keybinds for different monitoring tools
- **Right-side Panes**: All panes appear on the right side of your current window

## Keybinds

| Key Combination | Function | Description |
|----------------|----------|-------------|
| `Alt+A` | Toggle htop | System process monitor |
| `Alt+S` | Toggle btop | Modern system monitor |
| `Alt+T` | Toggle clock | Live date/time display |
| `Alt+W` | Toggle files | File system watcher |
| `Alt+N` | Toggle network | Network connections monitor |
| `Alt+P` | Toggle processes | Top processes by CPU usage |

## How It Works

1. **First Toggle**: Creates a new pane on the right side with the specified command
2. **Toggle Off**: Moves the pane to a hidden session (preserving its state)
3. **Toggle On**: Restores the pane from the hidden session (maintaining its state)

### Hidden Session Architecture

- Each main session gets its own hidden session named `_hidden_<session_name>`
- Toggle panes are stored as separate windows within the hidden session
- This provides better isolation between different tmux sessions
- Hidden sessions are automatically created when needed

## Usage

1. Start tmux
2. Press any of the Alt key combinations above
3. The pane will appear on the right side
4. Press the same key combination to hide the pane
5. Press it again to restore the pane with its preserved state

## Files

- `toggle-pane.sh`: Main script that handles pane toggling logic with hidden sessions
- `test-toggle.sh`: Test script to verify functionality
- `test-exit-status.sh`: Test script for the hidden session approach
- `cleanup-hidden-sessions.sh`: Script to clean up orphaned hidden sessions
- `.tmux.conf`: Updated tmux configuration with new keybinds

## Testing

Run the test script to verify everything works:

```bash
~/.dotfiles/tmux/test-toggle.sh
```

Or test the hidden session approach specifically:

```bash
~/.dotfiles/tmux/test-exit-status.sh
```

## Cleanup

To clean up orphaned hidden sessions (e.g., when main sessions were killed without proper cleanup):

```bash
~/.dotfiles/tmux/cleanup-hidden-sessions.sh
```

You can also manually check for hidden sessions:

```bash
tmux list-sessions | grep _hidden_
```

## Customization

To add your own toggle panes, add a new keybind to `.tmux.conf`:

```bash
bind-key -n M-x run-shell "~/.dotfiles/tmux/toggle-pane.sh 'your-command' 'pane-name'"
```

Replace `M-x` with your desired Alt key combination and `your-command` with the command you want to run.