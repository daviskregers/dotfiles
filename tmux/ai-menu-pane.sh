#!/bin/bash

# AI Menu pane script - runs menu then transitions to selected CLI
# Usage: ai-menu-pane.sh

echo "Choose an AI tool:"
echo ""
echo "1) claude"
echo "2) opencode"
echo "3) cursor-agent"
echo ""
echo -n "Enter choice (1-3): "
read -n 1 choice
echo ""

case "$choice" in
    1)
        echo "Starting claude..."
        exec claude
        ;;
    2)
        echo "Starting opencode..."
        exec opencode
        ;;
    3)
        echo "Starting cursor-agent..."
        exec cursor-agent
        ;;
    *)
        echo "Invalid choice. Starting claude by default..."
        exec claude
        ;;
esac