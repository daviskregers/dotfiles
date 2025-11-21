#!/bin/bash

# Read JSON input from stdin
input=$(cat)

# Extract basic info
username=$(whoami)
hostname=$(hostname -s)
current_dir=$(basename "$(pwd)")

# Extract reliable metrics from JSON
lines_added=$(echo "$input" | jq -r '.cost.total_lines_added // empty' 2>/dev/null)
lines_removed=$(echo "$input" | jq -r '.cost.total_lines_removed // empty' 2>/dev/null)
total_cost=$(echo "$input" | jq -r '.cost.total_cost_usd // empty' 2>/dev/null)
api_duration_ms=$(echo "$input" | jq -r '.cost.total_api_duration_ms // empty' 2>/dev/null)

# Build metrics display
metrics=""

# Format lines added/removed
if [ -n "$lines_added" ] && [ "$lines_added" != "null" ] && [ -n "$lines_removed" ] && [ "$lines_removed" != "null" ]; then
    metrics="Lines: +$lines_added/-$lines_removed"
fi

# Format cost
if [ -n "$total_cost" ] && [ "$total_cost" != "null" ]; then
    cost_display=$(printf '$%.2f' "$total_cost")
    if [ -n "$metrics" ]; then
        metrics="$metrics | Cost: $cost_display"
    else
        metrics="Cost: $cost_display"
    fi
fi

# Format time
if [ -n "$api_duration_ms" ] && [ "$api_duration_ms" != "null" ]; then
    # Convert ms to seconds with one decimal place
    if (( $(echo "$api_duration_ms < 1000" | bc -l 2>/dev/null || echo 0) )); then
        time_display="${api_duration_ms}ms"
    else
        time_seconds=$(echo "scale=1; $api_duration_ms / 1000" | bc -l 2>/dev/null)
        time_display="${time_seconds}s"
    fi

    if [ -n "$metrics" ]; then
        metrics="$metrics | Time: $time_display"
    else
        metrics="Time: $time_display"
    fi
fi

# Output the status line
if [ -n "$metrics" ]; then
    printf '[%s@%s %s] | %s' \
        "$username" \
        "$hostname" \
        "$current_dir" \
        "$metrics"
else
    printf '[%s@%s %s]' \
        "$username" \
        "$hostname" \
        "$current_dir"
fi
