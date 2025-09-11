#!/bin/bash

# Test script to understand tmux variables and cursor position

echo "=== TMUX VARIABLES TEST ==="
echo "Current pane: $(tmux display-message -p '#{pane_id}')"
echo "Copy cursor X: $(tmux display-message -p '#{copy_cursor_x}')"
echo "Copy cursor Y: $(tmux display-message -p '#{copy_cursor_y}')"
echo "Pane height: $(tmux display-message -p '#{pane_height}')"
echo "Pane width: $(tmux display-message -p '#{pane_width}')"
echo "Scroll position: $(tmux display-message -p '#{scroll_position}')"
echo "History size: $(tmux display-message -p '#{history_size}')"

echo ""
echo "=== PANE CONTENT TEST ==="
echo "Visible content (first 5 lines):"
tmux capture-pane -p | head -5

echo ""
echo "Full history (first 5 lines):"
tmux capture-pane -p -J | head -5

echo ""
echo "Full history (last 5 lines):"
tmux capture-pane -p -J | tail -5

echo ""
echo "=== LINE AT CURSOR POSITION ==="
cursor_y=$(tmux display-message -p '#{copy_cursor_y}')
echo "Cursor Y: $cursor_y"

echo "Line at cursor position from visible content:"
visible_content=$(tmux capture-pane -p)
echo "$visible_content" | sed -n "$((cursor_y + 1))p"

echo "Line at cursor position from full history:"
full_content=$(tmux capture-pane -p -J)
echo "$full_content" | sed -n "$((cursor_y + 1))p"