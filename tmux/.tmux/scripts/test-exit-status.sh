#!/bin/bash

# Test script to verify that toggle-pane.sh works with hidden sessions
echo "Testing toggle-pane.sh with hidden session approach..."

# Test with a simple command that should work
echo "Test 1: Creating a test pane"
~/.dotfiles/tmux/toggle-pane.sh "echo 'Test pane created'" "test-hidden-session"

sleep 1

echo "Test 2: Toggling pane off (should move to hidden session)"
~/.dotfiles/tmux/toggle-pane.sh "echo 'Test pane created'" "test-hidden-session"

sleep 1

echo "Test 3: Toggling pane back on (should restore from hidden session)"
~/.dotfiles/tmux/toggle-pane.sh "echo 'Test pane created'" "test-hidden-session"

sleep 1

echo "Test 4: Toggling pane off again"
~/.dotfiles/tmux/toggle-pane.sh "echo 'Test pane created'" "test-hidden-session"

sleep 1

echo "Test 5: Toggling pane back on again"
~/.dotfiles/tmux/toggle-pane.sh "echo 'Test pane created'" "test-hidden-session"

echo ""
echo "All tests completed. Check your tmux session for any exit status messages."
echo "You can also check for hidden sessions with: tmux list-sessions | grep _hidden_"
echo "If you see no exit status messages, the fix is working correctly."