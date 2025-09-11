#!/bin/bash

# Test script for toggle pane functionality
echo "Testing toggle pane functionality..."

# Test 1: Create a simple test pane
echo "Test 1: Creating test pane with 'echo hello'"
~/.dotfiles/tmux/toggle-pane.sh "echo 'Hello from test pane!'" "test"

sleep 2

# Test 2: Toggle it off
echo "Test 2: Toggling pane off"
~/.dotfiles/tmux/toggle-pane.sh "echo 'Hello from test pane!'" "test"

sleep 2

# Test 3: Toggle it back on (should preserve state)
echo "Test 3: Toggling pane back on (should preserve state)"
~/.dotfiles/tmux/toggle-pane.sh "echo 'Hello from test pane!'" "test"

echo "Test completed. Check your tmux session for the test pane."