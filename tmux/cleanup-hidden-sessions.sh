#!/bin/bash

# Cleanup script for hidden sessions
# This script can be run manually or integrated into session cleanup

echo "Cleaning up hidden sessions..."

# Get all hidden sessions
HIDDEN_SESSIONS=$(tmux list-sessions -F "#{session_name}" 2>/dev/null | grep "^_hidden_" || true)

if [ -z "$HIDDEN_SESSIONS" ]; then
    echo "No hidden sessions found."
    exit 0
fi

echo "Found hidden sessions:"
echo "$HIDDEN_SESSIONS"
echo

# Ask for confirmation before cleanup
read -p "Do you want to clean up all hidden sessions? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "$HIDDEN_SESSIONS" | while read -r session; do
        echo "Killing hidden session: $session"
        tmux kill-session -t "$session" 2>/dev/null || true
    done
    echo "Cleanup completed."
else
    echo "Cleanup cancelled."
fi