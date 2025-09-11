#!/bin/bash

# Cycle pane script for tmux with multiple commands
# Usage: cycle-pane.sh

# Get session and window from environment variables (set by keybinding) or current context
if [ -n "$TMUX_SESSION" ] && [ -n "$TMUX_WINDOW" ]; then
    # Use environment variables set by the keybinding
    SESSION_NAME="$TMUX_SESSION"
    WINDOW_NAME="$TMUX_WINDOW"
else
    # Fall back to current tmux context
    SESSION_NAME=$(tmux display-message -p '#S' 2>/dev/null || echo "")
    WINDOW_NAME=$(tmux display-message -p '#W' 2>/dev/null || echo "")
fi

# Validate that we have valid session and window names
if [ -z "$SESSION_NAME" ] || [ -z "$WINDOW_NAME" ]; then
    echo "Error: Could not determine tmux session or window" >&2
    exit 1
fi

# Create hidden session name for this main session
HIDDEN_SESSION="_hidden_${SESSION_NAME}"
PANE_NAME="ai_tools"

# Function to ensure hidden session exists
ensure_hidden_session() {
    if ! tmux has-session -t "$HIDDEN_SESSION" 2>/dev/null; then
        # Create hidden session with a dummy window that we'll immediately kill
        tmux new-session -d -s "$HIDDEN_SESSION" -x 1 -y 1 2>/dev/null || true
        # Kill the default window
        tmux kill-window -t "$HIDDEN_SESSION:0" 2>/dev/null || true
    fi
}

# Function to show menu and get user choice
show_menu() {
    # Create a temporary script for the popup
    temp_script=$(mktemp)
    cat > "$temp_script" << 'EOF'
#!/bin/bash
echo "Choose an AI tool:"
echo ""
echo "1) claude"
echo "2) opencode"
echo "3) cursor-agent"
echo "4) Cancel"
echo ""
echo -n "Enter choice (1-4): "
read -n 1 choice
echo ""
echo "$choice"
EOF
    chmod +x "$temp_script"
    
    # Use tmux popup to show menu
    choice=$(tmux popup -y 20 -w 50 -h 10 -E "$temp_script")
    
    # Clean up temp file
    rm -f "$temp_script"
    
    # Clean up the choice (remove any extra whitespace/newlines)
    choice=$(echo "$choice" | tr -d '\n\r ' | tail -1)
    
    case "$choice" in
        1)
            COMMAND="claude"
            ;;
        2)
            COMMAND="opencode"
            ;;
        3)
            COMMAND="cursor-agent"
            ;;
        4|*)
            echo "Cancelled"
            exit 0
            ;;
    esac
}

# Check if pane already exists in current window
EXISTING_PANE=$(tmux list-panes -t "$SESSION_NAME:$WINDOW_NAME" -F "#{pane_id}:#{pane_title}" 2>/dev/null | grep ":$PANE_NAME$" | cut -d: -f1 | head -1)

if [ -n "$EXISTING_PANE" ]; then
    # Pane exists, hide it by moving it to the hidden session
    ensure_hidden_session
    
    # Break the pane into a window in the hidden session
    if tmux break-pane -s "$EXISTING_PANE" -d -t "$HIDDEN_SESSION" -n "$PANE_NAME" 2>/dev/null; then
        # Successfully moved to hidden session
        true
    fi
else
    # Check if pane exists in hidden session
    if tmux has-session -t "$HIDDEN_SESSION" 2>/dev/null; then
        HIDDEN_WINDOW=$(tmux list-windows -t "$HIDDEN_SESSION" -F "#{window_name}" 2>/dev/null | grep "^${PANE_NAME}$" | head -1)
        
        if [ -n "$HIDDEN_WINDOW" ]; then
            # Pane exists in hidden session, restore it
            if tmux join-pane -h -s "$HIDDEN_SESSION:${HIDDEN_WINDOW}.0" -t "$SESSION_NAME:$WINDOW_NAME" 2>/dev/null; then
                # Successfully restored, now kill the window in hidden session
                tmux kill-window -t "$HIDDEN_SESSION:${HIDDEN_WINDOW}" 2>/dev/null || true
            fi
        else
            # Pane doesn't exist anywhere, show menu and create it
            show_menu
            
            # Create new pane with selected command
            if tmux split-window -h -t "$SESSION_NAME:$WINDOW_NAME" -c "#{pane_current_path}" 2>/dev/null; then
                # Get the new pane ID by listing panes and finding the last one
                NEW_PANE=$(tmux list-panes -t "$SESSION_NAME:$WINDOW_NAME" -F "#{pane_id}" 2>/dev/null | tail -1)
                if [ -n "$NEW_PANE" ]; then
                    tmux send-keys -t "$NEW_PANE" "$COMMAND" Enter 2>/dev/null || true
                    tmux select-pane -t "$NEW_PANE" -T "$PANE_NAME" 2>/dev/null || true
                fi
            fi
        fi
    else
        # Hidden session doesn't exist, show menu and create new pane
        show_menu
        
        if tmux split-window -h -t "$SESSION_NAME:$WINDOW_NAME" -c "#{pane_current_path}" 2>/dev/null; then
            # Get the new pane ID by listing panes and finding the last one
            NEW_PANE=$(tmux list-panes -t "$SESSION_NAME:$WINDOW_NAME" -F "#{pane_id}" 2>/dev/null | tail -1)
            if [ -n "$NEW_PANE" ]; then
                tmux send-keys -t "$NEW_PANE" "$COMMAND" Enter 2>/dev/null || true
                tmux select-pane -t "$NEW_PANE" -T "$PANE_NAME" 2>/dev/null || true
            fi
        fi
    fi
fi