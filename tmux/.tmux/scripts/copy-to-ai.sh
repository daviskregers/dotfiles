#!/bin/bash

# Copy selected text to AI pane script
# Usage: Run from tmux copy mode with text selected

# Debug mode - create /tmp/copy-to-ai-debug to enable
DEBUG_FILE="/tmp/copy-to-ai-debug"
if [ -f "$DEBUG_FILE" ]; then
    DEBUG=1
    DEBUG_LOG="/tmp/copy-to-ai-debug.log"
else
    DEBUG=0
fi

debug_log() {
    if [ "$DEBUG" = "1" ]; then
        echo "$(date '+%H:%M:%S') [$$] $*" >> "$DEBUG_LOG"
    fi
}

# Get current session and window
SESSION_NAME=$(tmux display-message -p '#S' 2>/dev/null || echo "")
WINDOW_ID=$(tmux display-message -p '#{window_id}' 2>/dev/null || echo "")

if [ -z "$SESSION_NAME" ] || [ -z "$WINDOW_ID" ]; then
    debug_log "ERROR: Could not determine tmux session or window"
    tmux display-message "Error: Could not determine tmux session or window"
    exit 1
fi

debug_log "Copy-to-AI request: SESSION=$SESSION_NAME, WINDOW=$WINDOW_ID"

# Check if we're in copy mode
if [[ "$(tmux display-message -p '#{pane_mode}')" != "copy-mode" ]]; then
    debug_log "ERROR: Not in copy mode"
    tmux display-message "Not in copy mode. Enter copy mode first (prefix + [)"
    exit 1
fi

# Get the selected text using the same method as file-jump
selected_text=""

# Save current clipboard content
old_buffer=$(tmux show-buffer 2>/dev/null || echo "")

# Try to copy current selection
tmux send-keys -X copy-selection 2>/dev/null || true

# Get the new buffer content
new_buffer=$(tmux show-buffer 2>/dev/null || echo "")

# If buffer changed, we had a selection
if [[ "$new_buffer" != "$old_buffer" ]] && [[ -n "$new_buffer" ]]; then
    selected_text="$new_buffer"
    debug_log "Found selected text (${#selected_text} chars): ${selected_text:0:100}..."
    # Restore old buffer if we had one
    if [[ -n "$old_buffer" ]]; then
        echo "$old_buffer" | tmux load-buffer -
    fi
else
    debug_log "ERROR: No text selected"
    tmux display-message "No text selected. Select text first in copy mode."
    exit 1
fi

# Find or create AI pane
AI_PANE_NAME="ai_tools"
BASE_PANE_ID="toggle_${AI_PANE_NAME}"
# Use same title format as toggle-pane.sh
AI_PANE_TITLE="[${WINDOW_ID}_${BASE_PANE_ID}]"

# Check if AI pane already exists in current window
# Escape brackets for grep since they're special regex characters
ESCAPED_AI_PANE_TITLE=$(echo "$AI_PANE_TITLE" | sed 's/\[/\\[/g; s/\]/\\]/g')
EXISTING_AI_PANE=$(tmux list-panes -t "$SESSION_NAME:$WINDOW_ID" -F "#{pane_id}:#{pane_title}" 2>/dev/null | grep ":$ESCAPED_AI_PANE_TITLE$" | cut -d: -f1 | head -1)

if [ -n "$EXISTING_AI_PANE" ]; then
    debug_log "Found existing AI pane: $EXISTING_AI_PANE"
    AI_PANE="$EXISTING_AI_PANE"
else
    debug_log "No AI pane found, creating one"
    # No AI pane exists, create it using the toggle script
    TMUX_SESSION="$SESSION_NAME" TMUX_WINDOW="$WINDOW_ID" ~/.tmux/scripts/toggle-pane.sh ~/.tmux/scripts/ai-menu-pane.sh ai_tools
    
    # Give it a moment to create
    sleep 0.1
    
    # Find the newly created AI pane
    AI_PANE=$(tmux list-panes -t "$SESSION_NAME:$WINDOW_ID" -F "#{pane_id}:#{pane_title}" 2>/dev/null | grep ":$ESCAPED_AI_PANE_TITLE$" | cut -d: -f1 | head -1)
    
    if [ -z "$AI_PANE" ]; then
        debug_log "ERROR: Failed to create AI pane"
        tmux display-message "Failed to create AI pane"
        exit 1
    fi
    debug_log "Created AI pane: $AI_PANE"
fi

# Send the selected text to the AI pane wrapped in console code block
# First clear any existing input
tmux send-keys -t "$AI_PANE" C-c 2>/dev/null || true
tmux send-keys -t "$AI_PANE" C-u 2>/dev/null || true

# Send the selected text wrapped in console code block
formatted_text=$'```console\n'"$selected_text"$'\n```'
tmux send-keys -t "$AI_PANE" "$formatted_text" 2>/dev/null || true

# Switch to the AI pane
tmux select-pane -t "$AI_PANE"

debug_log "Successfully sent text to AI pane $AI_PANE"
tmux display-message "Sent selected text to AI pane"