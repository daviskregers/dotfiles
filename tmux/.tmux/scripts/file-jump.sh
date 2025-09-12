#!/bin/bash

# File jump script for tmux copy mode
# Supports both file:line and just file patterns
# Set DEBUG=1 to enable debug logging

# Check for debug flag file
debug_flag_file="/tmp/tmux-file-jump-debug-flag"
debug_log="/tmp/tmux-file-jump-debug.log"

if [[ -f "$debug_flag_file" ]]; then
    DEBUG=1
else
    DEBUG=0
fi

if [[ "$DEBUG" == "1" ]]; then
    echo "=== DEBUG SESSION $(date) ===" >> "$debug_log"
fi

# Get current pane info
current_pane_id="$(tmux display-message -p '#{pane_id}')"

if [[ "$DEBUG" == "1" ]]; then
    echo "Current pane: $current_pane_id" >> "$debug_log"
fi

# Check if we're in copy mode
if [[ "$(tmux display-message -p '#{pane_mode}')" != "copy-mode" ]]; then
    tmux display-message "Not in copy mode. Enter copy mode first (prefix + [)"
    exit 1
fi

# Try to get selected text using tmux copy buffer
selected_text=""

# Try to capture the current selection by temporarily copying it
# This works by sending copy command and then reading the buffer
if [[ "$DEBUG" == "1" ]]; then
    echo "Attempting to capture selection..." >> "$debug_log"
fi

# Save current clipboard content
old_buffer=$(tmux show-buffer 2>/dev/null || echo "")

# Try to copy current selection (this will fail silently if no selection)
tmux send-keys -X copy-selection 2>/dev/null || true

# Get the new buffer content
new_buffer=$(tmux show-buffer 2>/dev/null || echo "")

# If buffer changed, we had a selection
if [[ "$new_buffer" != "$old_buffer" ]] && [[ -n "$new_buffer" ]]; then
    selected_text="$new_buffer"
    if [[ "$DEBUG" == "1" ]]; then
        echo "Found visual selection: '$selected_text'" >> "$debug_log"
    fi
    # Restore old buffer if we had one
    if [[ -n "$old_buffer" ]]; then
        echo "$old_buffer" | tmux load-buffer -
    fi
else
    if [[ "$DEBUG" == "1" ]]; then
        echo "No visual selection detected" >> "$debug_log"
    fi
fi

# If no selection, fall back to cursor position
if [[ -z "$selected_text" ]]; then
    if [[ "$DEBUG" == "1" ]]; then
        echo "No selection found, using cursor position" >> "$debug_log"
    fi
    
    # Get the current line and extract the word at cursor position
    cursor_y=$(tmux display-message -p '#{copy_cursor_y}' 2>/dev/null || echo "0")
    cursor_x=$(tmux display-message -p '#{copy_cursor_x}' 2>/dev/null || echo "0")

    # Validate cursor position values
    if [[ ! "$cursor_y" =~ ^[0-9]+$ ]]; then
        cursor_y="0"
    fi
    if [[ ! "$cursor_x" =~ ^[0-9]+$ ]]; then
        cursor_x="0"
    fi

    if [[ "$DEBUG" == "1" ]]; then
        echo "Cursor position: X=$cursor_x, Y=$cursor_y" >> "$debug_log"
    fi
fi

# Use tmux's built-in variables to get the exact line at cursor
# Fallback for macOS compatibility
current_line=$(tmux display-message -p '#{copy_cursor_line}' 2>/dev/null || echo "")

# If copy_cursor_line is not available or empty, use capture-pane fallback
if [[ -z "$current_line" ]]; then
    if [[ "$DEBUG" == "1" ]]; then
        echo "copy_cursor_line not available, using capture-pane fallback" >> "$debug_log"
    fi
    
    # Capture the pane content and get the line at cursor position
    # cursor_y is 0-indexed from top of pane content
    pane_content=$(tmux capture-pane -p -t "$current_pane_id")
    current_line=$(echo "$pane_content" | sed -n "$((cursor_y + 1))p")
    
    if [[ "$DEBUG" == "1" ]]; then
        echo "Captured pane content (first 5 lines):" >> "$debug_log"
        echo "$pane_content" | head -5 >> "$debug_log"
        echo "Extracted line at cursor_y=$cursor_y: '$current_line'" >> "$debug_log"
    fi
fi

if [[ "$DEBUG" == "1" ]]; then
    echo "Line at cursor: '$current_line'" >> "$debug_log"
fi

# Clean the line and adjust cursor position
original_line="$current_line"
cleaned_line=$(echo "$current_line" | sed 's/^[[:space:]]*│[[:space:]]*//' | sed 's/[[:space:]]*│[[:space:]]*$//' | sed 's/\x1b\[[0-9;]*m//g')

# Detect OS for platform-specific handling
OS="$(uname -s)"

if [[ "$OS" == "Darwin" ]]; then
    # macOS: Simplified approach - don't adjust cursor position due to tmux differences
    adjusted_cursor_x=$cursor_x
    if [[ "$DEBUG" == "1" ]]; then
        echo "macOS detected: using original cursor position" >> "$debug_log"
    fi
else
    # Linux: Original logic for prefix removal
    prefix_removed=0
    while [[ $prefix_removed -lt ${#original_line} ]] && [[ $prefix_removed -lt ${#cleaned_line} ]]; do
        if [[ "${original_line:$prefix_removed:1}" == "${cleaned_line:$prefix_removed:1}" ]]; then
            ((prefix_removed++))
        else
            break
        fi
    done
    
    # Adjust cursor position to account for removed prefix
    adjusted_cursor_x=$((cursor_x - prefix_removed))
    if [[ "$DEBUG" == "1" ]]; then
        echo "Linux detected: adjusting cursor position by $prefix_removed chars" >> "$debug_log"
    fi
fi

if [[ "$DEBUG" == "1" ]]; then
    echo "Original line: '$original_line'" >> "$debug_log"
    echo "Cleaned line: '$cleaned_line'" >> "$debug_log"
    echo "Original cursor X: $cursor_x" >> "$debug_log"
    echo "Adjusted cursor X: $adjusted_cursor_x" >> "$debug_log"
fi

# Look for file patterns in the line at cursor position
file_pattern=""

# Function to find file pattern under cursor
find_file_pattern_at_cursor() {
    local cleaned_line="$1"
    local cursor_x="$2"
    file_pattern=""
    
    if [[ "$DEBUG" == "1" ]]; then
        echo "Looking for file pattern at cursor position $cursor_x in: '$cleaned_line'" >> "$debug_log"
    fi
    
    # Use a simpler approach: find all potential file patterns and check which one contains the cursor
    local line_length=${#cleaned_line}
    
    # Look for file:line patterns first (they take precedence)
    local pos=0
    while [[ $pos -lt $line_length ]]; do
        local remaining="${cleaned_line:$pos}"
        if [[ $remaining =~ ^([^[:space:]]+):([0-9]+) ]]; then
            local match="${BASH_REMATCH[1]}:${BASH_REMATCH[2]}"
            local match_start=$pos
            local match_end=$((pos + ${#match}))
            
            if [[ "$DEBUG" == "1" ]]; then
                echo "  Found file:line pattern '$match' at position $match_start-$match_end" >> "$debug_log"
            fi
            
            # Check if cursor is within this match
            if [[ $cursor_x -ge $match_start && $cursor_x -le $match_end ]]; then
                file_pattern="$match"
                if [[ "$DEBUG" == "1" ]]; then
                    echo "  ✓ Cursor is within this pattern: '$file_pattern'" >> "$debug_log"
                fi
                break
            fi
            
            pos=$match_end
        else
            ((pos++))
        fi
    done
    
    # If no file:line pattern found, look for files with extensions
    if [[ -z "$file_pattern" ]]; then
        pos=0
        local best_match=""
        local best_distance=999999
        
        while [[ $pos -lt $line_length ]]; do
            local remaining="${cleaned_line:$pos}"
            if [[ $remaining =~ ^([^[:space:]]+\.[a-zA-Z0-9]+) ]]; then
                local match="${BASH_REMATCH[1]}"
                local match_start=$pos
                local match_end=$((pos + ${#match}))
                
                if [[ "$DEBUG" == "1" ]]; then
                    echo "  Found file pattern '$match' at position $match_start-$match_end" >> "$debug_log"
                fi
                
                # Check if cursor is within this match
                if [[ $cursor_x -ge $match_start && $cursor_x -le $match_end ]]; then
                    # Calculate distance from cursor to center of match
                    local match_center=$((match_start + match_end) / 2)
                    local distance=$((cursor_x - match_center))
                    if [[ $distance -lt 0 ]]; then
                        distance=$((-distance))
                    fi
                    
                    if [[ "$DEBUG" == "1" ]]; then
                        echo "    Cursor distance from '$match' center: $distance" >> "$debug_log"
                    fi
                    
                    # Prefer this match if it's closer to cursor or if no match found yet
                    if [[ -z "$best_match" ]] || [[ $distance -lt $best_distance ]]; then
                        best_match="$match"
                        best_distance=$distance
                        if [[ "$DEBUG" == "1" ]]; then
                            echo "    New best match: '$best_match' (distance: $best_distance)" >> "$debug_log"
                        fi
                    fi
                fi
                
                pos=$match_end
            else
                ((pos++))
            fi
        done
        
        if [[ -n "$best_match" ]]; then
            file_pattern="$best_match"
            if [[ "$DEBUG" == "1" ]]; then
                echo "  ✓ Selected best match: '$file_pattern'" >> "$debug_log"
            fi
        fi
    fi
    
    # If still no pattern found, look for files without extensions (like README, Makefile, etc.)
    if [[ -z "$file_pattern" ]]; then
        # Look for common filenames without extensions
        local special_files=("README" "Makefile" "Dockerfile" "LICENSE" "CHANGELOG" "TODO" "CONTRIBUTING" "package.json" "tsconfig.json" ".gitignore" ".env" ".dockerignore")
        
        for special_file in "${special_files[@]}"; do
            local pos=0
            while [[ $pos -lt $line_length ]]; do
                local remaining="${cleaned_line:$pos}"
                if [[ $remaining =~ ^$special_file ]]; then
                    local match="$special_file"
                    local match_start=$pos
                    local match_end=$((pos + ${#match}))
                    
                    if [[ "$DEBUG" == "1" ]]; then
                        echo "  Found special file pattern '$match' at position $match_start-$match_end" >> "$debug_log"
                    fi
                    
                    # Check if cursor is within this match
                    if [[ $cursor_x -ge $match_start && $cursor_x -le $match_end ]]; then
                        file_pattern="$match"
                        if [[ "$DEBUG" == "1" ]]; then
                            echo "  ✓ Cursor is within this pattern: '$file_pattern'" >> "$debug_log"
                        fi
                        break 2
                    fi
                    
                    pos=$match_end
                else
                    ((pos++))
                fi
            done
        done
    fi
    
    # If still no pattern found, look for any word that might be a filename
    if [[ -z "$file_pattern" ]]; then
        # Split by spaces and check each word
        local words=($cleaned_line)
        local word_pos=0
        
        for word in "${words[@]}"; do
            local word_start=$word_pos
            local word_end=$((word_start + ${#word}))
            
            # Check if cursor is within this word
            if [[ $cursor_x -ge $word_start && $cursor_x -le $word_end ]]; then
                # Check if this word looks like a filename (contains dots, slashes, or is a common filename)
                if [[ $word =~ [./] ]] || [[ $word =~ ^(README|Makefile|Dockerfile|LICENSE|CHANGELOG|TODO|CONTRIBUTING)$ ]]; then
                    file_pattern="$word"
                    if [[ "$DEBUG" == "1" ]]; then
                        echo "  ✓ Cursor is within filename-like word: '$file_pattern'" >> "$debug_log"
                    fi
                    break
                fi
            fi
            
            word_pos=$((word_end + 1))  # +1 for space
        done
    fi
    
    if [[ -z "$file_pattern" ]]; then
        if [[ "$DEBUG" == "1" ]]; then
            echo "  ✗ No file pattern found under cursor" >> "$debug_log"
        fi
        return 1
    fi
    
    return 0
}

# Only do cursor-based pattern matching if we don't have a visual selection
if [[ -z "$selected_text" ]]; then
    # Use the cursor-aware pattern matching
    if find_file_pattern_at_cursor "$cleaned_line" "$adjusted_cursor_x"; then
        if [[ "$DEBUG" == "1" ]]; then
            echo "Found file pattern under cursor: '$file_pattern'" >> "$debug_log"
        fi
    else
        if [[ "$DEBUG" == "1" ]]; then
            echo "ERROR: No file pattern found under cursor in line: '$cleaned_line'" >> "$debug_log"
        fi
        tmux display-message "No file pattern found under cursor in current line"
        exit 1
    fi
fi

# If we don't already have selected text from visual selection, use the found file pattern
if [[ -z "$selected_text" ]]; then
    selected_text="$file_pattern"
    if [[ "$DEBUG" == "1" ]]; then
        echo "Selected file pattern from cursor: '$selected_text'" >> "$debug_log"
    fi
else
    if [[ "$DEBUG" == "1" ]]; then
        echo "Using visual selection: '$selected_text'" >> "$debug_log"
    fi
fi

# Parse the selected file pattern to extract file path and line number
if [[ $selected_text =~ ([^[:space:]]+):([0-9]+) ]]; then
    file_path="${BASH_REMATCH[1]}"
    line_number="${BASH_REMATCH[2]}"
    if [[ "$DEBUG" == "1" ]]; then
        echo "Predicted file: '$file_path:$line_number'" >> "$debug_log"
    fi
else
    # Single filename
    file_path="$selected_text"
    line_number="1"
    if [[ "$DEBUG" == "1" ]]; then
        echo "Predicted file: '$file_path' (line 1)" >> "$debug_log"
    fi
fi

# Find target pane (look for neovim first, then any other pane)
target_pane=""
panes=$(tmux list-panes -F "#{pane_id}:#{pane_current_command}")
if [[ "$DEBUG" == "1" ]]; then
    echo "Available panes: $panes" >> "$debug_log"
fi

# Look for neovim pane first
if [[ "$DEBUG" == "1" ]]; then
    echo "Looking for neovim pane..." >> "$debug_log"
fi
while IFS=: read -r pane_id pane_command; do
    if [[ "$DEBUG" == "1" ]]; then
        echo "Checking pane $pane_id with command '$pane_command'" >> "$debug_log"
    fi
    if [[ "$pane_id" != "$current_pane_id" ]] && [[ "$pane_command" == "nvim" ]]; then
        target_pane="$pane_id"
        if [[ "$DEBUG" == "1" ]]; then
            echo "Found neovim pane: $target_pane" >> "$debug_log"
        fi
        break
    fi
done <<< "$panes"

# If no neovim found, use any other pane
if [[ -z "$target_pane" ]]; then
    if [[ "$DEBUG" == "1" ]]; then
        echo "No neovim pane found, looking for any other pane..." >> "$debug_log"
    fi
    while IFS=: read -r pane_id pane_command; do
        if [[ "$DEBUG" == "1" ]]; then
            echo "Checking pane $pane_id with command '$pane_command'" >> "$debug_log"
        fi
        if [[ "$pane_id" != "$current_pane_id" ]]; then
            target_pane="$pane_id"
            if [[ "$DEBUG" == "1" ]]; then
                echo "Found target pane: $target_pane" >> "$debug_log"
            fi
            break
        fi
    done <<< "$panes"
fi

if [[ -z "$target_pane" ]]; then
    if [[ "$DEBUG" == "1" ]]; then
        echo "ERROR: No target pane found" >> "$debug_log"
    fi
    tmux display-message "No target pane found"
    exit 1
fi

# Let neovim handle file existence - no need to check here
if [[ "$DEBUG" == "1" ]]; then
    echo "Passing file to neovim: $file_path" >> "$debug_log"
fi

# Send commands to target pane (without exiting copy mode)
tmux send-keys -t "$target_pane" "C-c"
tmux send-keys -t "$target_pane" ":e $file_path" Enter
tmux send-keys -t "$target_pane" ":$line_number" Enter
tmux send-keys -t "$target_pane" "zz"

# Switch to target pane
tmux select-pane -t "$target_pane"

if [[ "$DEBUG" == "1" ]]; then
    echo "SUCCESS: Opened $file_path:$line_number in pane $target_pane" >> "$debug_log"
    echo "=== DEBUG COMPLETE ===" >> "$debug_log"
fi

tmux display-message "Opened $file_path:$line_number in pane $target_pane"