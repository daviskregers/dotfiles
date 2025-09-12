#!/bin/bash

# Toggle pane script for tmux with state preservation using hidden sessions
# Usage: toggle-pane.sh <command> [pane_name]
# Example: toggle-pane.sh "htop" "htop"
#          toggle-pane.sh "watch -n 1 'date'" "clock"

# Error handling: suppress error messages and handle failures gracefully

COMMAND="$1"
PANE_NAME="${2:-$(basename "$COMMAND")}"

# Debug mode - create /tmp/toggle-pane-debug to enable
DEBUG_FILE="/tmp/toggle-pane-debug"
if [ -f "$DEBUG_FILE" ]; then
    DEBUG=1
    DEBUG_LOG="/tmp/toggle-pane-debug.log"
else
    DEBUG=0
fi

debug_log() {
    if [ "$DEBUG" = "1" ]; then
        echo "$(date '+%H:%M:%S') [$$] $*" >> "$DEBUG_LOG"
    fi
}

# Get session and window from environment variables (set by keybinding) or current context
if [ -n "$TMUX_SESSION" ] && [ -n "$TMUX_WINDOW" ]; then
    # Use environment variables set by the keybinding
    SESSION_NAME="$TMUX_SESSION"
    WINDOW_NAME="$TMUX_WINDOW"
    debug_log "Using env vars: SESSION=$SESSION_NAME, WINDOW=$WINDOW_NAME"
else
    # Fall back to current tmux context
    SESSION_NAME=$(tmux display-message -p '#S' 2>/dev/null || echo "")
    WINDOW_NAME=$(tmux display-message -p '#{window_id}' 2>/dev/null || echo "")
    debug_log "Using current context: SESSION=$SESSION_NAME, WINDOW=$WINDOW_NAME"
fi

# Validate that we have valid session and window names
if [ -z "$SESSION_NAME" ] || [ -z "$WINDOW_NAME" ]; then
    debug_log "ERROR: Missing session or window name"
    echo "Error: Could not determine tmux session or window" >&2
    exit 1
fi

debug_log "Toggle request: COMMAND='$COMMAND', PANE_NAME='$PANE_NAME', SESSION=$SESSION_NAME, WINDOW=$WINDOW_NAME"

# Create hidden session name for this main session
HIDDEN_SESSION="_hidden_${SESSION_NAME}"
PANE_ID="toggle_${PANE_NAME}"

# Function to ensure hidden session exists
ensure_hidden_session() {
    if ! tmux has-session -t "$HIDDEN_SESSION" 2>/dev/null; then
        # Create hidden session with a dummy window that we'll immediately kill
        tmux new-session -d -s "$HIDDEN_SESSION" -x 1 -y 1 2>/dev/null || true
        # Kill the default window
        tmux kill-window -t "$HIDDEN_SESSION:0" 2>/dev/null || true
    fi
}

# Check if pane already exists in current window
EXISTING_PANE=$(tmux list-panes -t "$SESSION_NAME:$WINDOW_NAME" -F "#{pane_id}:#{pane_title}" 2>/dev/null | grep ":$PANE_ID$" | cut -d: -f1 | head -1)

debug_log "Checking for existing pane with title '$PANE_ID' in $SESSION_NAME:$WINDOW_NAME"
debug_log "Existing pane found: '$EXISTING_PANE'"

if [ -n "$EXISTING_PANE" ]; then
    # Pane exists in current window, hide it by moving it to the hidden session
    ensure_hidden_session
    
    # Create a unique window name in hidden session that includes the original window
    HIDDEN_WINDOW_NAME="${PANE_ID}_${WINDOW_NAME}"
    
    # Break the pane into a window in the hidden session
    debug_log "Moving pane $EXISTING_PANE to hidden session window: $HIDDEN_WINDOW_NAME"
    if tmux break-pane -s "$EXISTING_PANE" -d -t "$HIDDEN_SESSION" -n "$HIDDEN_WINDOW_NAME" 2>/dev/null; then
        debug_log "Successfully moved pane to hidden session"
    else
        debug_log "Failed to move pane to hidden session"
    fi
else
    # Check if pane exists in hidden session for this specific window
    ensure_hidden_session
    HIDDEN_WINDOW_NAME="${PANE_ID}_${WINDOW_NAME}"
    HIDDEN_WINDOW=$(tmux list-windows -t "$HIDDEN_SESSION" -F "#{window_name}" 2>/dev/null | grep "^${HIDDEN_WINDOW_NAME}$" | head -1)
    
    debug_log "Looking for hidden window: $HIDDEN_WINDOW_NAME"
    debug_log "Hidden window found: '$HIDDEN_WINDOW'"
    
    if [ -n "$HIDDEN_WINDOW" ]; then
        # Pane exists in hidden session for this window, restore it
        if tmux join-pane -h -s "$HIDDEN_SESSION:${HIDDEN_WINDOW}.0" -t "$SESSION_NAME:$WINDOW_NAME" 2>/dev/null; then
            # Successfully restored, now kill the window in hidden session
            tmux kill-window -t "$HIDDEN_SESSION:${HIDDEN_WINDOW}" 2>/dev/null || true
        fi
    else
        # Pane doesn't exist anywhere for this window, create it
        if tmux split-window -h -t "$SESSION_NAME:$WINDOW_NAME" -c "#{pane_current_path}" 2>/dev/null; then
            # Get the new pane ID by listing panes and finding the last one
            NEW_PANE=$(tmux list-panes -t "$SESSION_NAME:$WINDOW_NAME" -F "#{pane_id}" 2>/dev/null | tail -1)
            if [ -n "$NEW_PANE" ]; then
                tmux send-keys -t "$NEW_PANE" "$COMMAND" Enter 2>/dev/null || true
                tmux select-pane -t "$NEW_PANE" -T "$PANE_ID" 2>/dev/null || true
            fi
        fi
    fi
fi
