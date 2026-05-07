#!/bin/bash
# Custom statusline: caveman badge + context usage + rate limits
# Receives JSON on stdin from Claude Code

INPUT=$(cat)

# --- Context usage ---
CTX_PCT=$(echo "$INPUT" | jq -r '.context_window.used_percentage // 0' 2>/dev/null | cut -d. -f1)
CTX_TOTAL=$(echo "$INPUT" | jq -r '.context_window.context_window_size // 0' 2>/dev/null)
INPUT_TOK=$(echo "$INPUT" | jq -r '.context_window.total_input_tokens // 0' 2>/dev/null)
OUTPUT_TOK=$(echo "$INPUT" | jq -r '.context_window.total_output_tokens // 0' 2>/dev/null)

# Colour context percentage: green <50, yellow 50-80, red >80
if [ "$CTX_PCT" -gt 80 ] 2>/dev/null; then
  CTX_COLOR='\033[31m'
elif [ "$CTX_PCT" -gt 50 ] 2>/dev/null; then
  CTX_COLOR='\033[33m'
else
  CTX_COLOR='\033[32m'
fi

# Format token counts (K/M)
format_tokens() {
  local n=$1
  if [ "$n" -ge 1000000 ] 2>/dev/null; then
    printf "%.1fM" "$(echo "scale=1; $n/1000000" | bc)"
  elif [ "$n" -ge 1000 ] 2>/dev/null; then
    printf "%.0fK" "$(echo "scale=0; $n/1000" | bc)"
  else
    printf "%d" "$n"
  fi
}

IN_FMT=$(format_tokens "$INPUT_TOK")
OUT_FMT=$(format_tokens "$OUTPUT_TOK")
CTX_SIZE_FMT=$(format_tokens "$CTX_TOTAL")

CONTEXT="${CTX_COLOR}ctx:${CTX_PCT}%\033[0m (${IN_FMT}in/${OUT_FMT}out of ${CTX_SIZE_FMT})"

# --- Rate limits ---
LIMITS=""
FIVE_H=$(echo "$INPUT" | jq -r '.rate_limits.five_hour.used_percentage // empty' 2>/dev/null)
SEVEN_D=$(echo "$INPUT" | jq -r '.rate_limits.seven_day.used_percentage // empty' 2>/dev/null)

FIVE_RESET=$(echo "$INPUT" | jq -r '.rate_limits.five_hour.resets_at // empty' 2>/dev/null)

if [ -n "$FIVE_H" ]; then
  FIVE_H_INT=$(printf '%.0f' "$FIVE_H")
  if [ "$FIVE_H_INT" -gt 80 ] 2>/dev/null; then
    FIVE_COLOR='\033[31m'
  elif [ "$FIVE_H_INT" -gt 50 ] 2>/dev/null; then
    FIVE_COLOR='\033[33m'
  else
    FIVE_COLOR='\033[32m'
  fi
  FIVE_RESET_STR=""
  if [ -n "$FIVE_RESET" ]; then
    NOW=$(date +%s)
    SECS_LEFT=$((FIVE_RESET - NOW))
    if [ "$SECS_LEFT" -gt 0 ] 2>/dev/null; then
      HOURS=$((SECS_LEFT / 3600))
      MINS=$(((SECS_LEFT % 3600) / 60))
      if [ "$HOURS" -gt 0 ]; then
        FIVE_RESET_STR="(${HOURS}h${MINS}m)"
      else
        FIVE_RESET_STR="(${MINS}m)"
      fi
    fi
  fi
  LIMITS=" | ${FIVE_COLOR}5h:${FIVE_H_INT}%${FIVE_RESET_STR}\033[0m"
fi

SEVEN_RESET=$(echo "$INPUT" | jq -r '.rate_limits.seven_day.resets_at // empty' 2>/dev/null)

if [ -n "$SEVEN_D" ]; then
  SEVEN_D_INT=$(printf '%.0f' "$SEVEN_D")
  if [ "$SEVEN_D_INT" -gt 80 ] 2>/dev/null; then
    SEVEN_COLOR='\033[31m'
  elif [ "$SEVEN_D_INT" -gt 50 ] 2>/dev/null; then
    SEVEN_COLOR='\033[33m'
  else
    SEVEN_COLOR='\033[32m'
  fi
  SEVEN_RESET_STR=""
  if [ -n "$SEVEN_RESET" ]; then
    NOW=$(date +%s)
    SECS_LEFT=$((SEVEN_RESET - NOW))
    if [ "$SECS_LEFT" -gt 0 ] 2>/dev/null; then
      DAYS=$((SECS_LEFT / 86400))
      HOURS=$(((SECS_LEFT % 86400) / 3600))
      if [ "$DAYS" -gt 0 ]; then
        SEVEN_RESET_STR="(${DAYS}d${HOURS}h)"
      else
        MINS=$(((SECS_LEFT % 3600) / 60))
        if [ "$HOURS" -gt 0 ]; then
          SEVEN_RESET_STR="(${HOURS}h${MINS}m)"
        else
          SEVEN_RESET_STR="(${MINS}m)"
        fi
      fi
    fi
  fi
  LIMITS="${LIMITS} | ${SEVEN_COLOR}7d:${SEVEN_D_INT}%${SEVEN_RESET_STR}\033[0m"
fi

# --- Cost ---
COST=$(echo "$INPUT" | jq -r '.cost.total_cost_usd // empty' 2>/dev/null)
COST_STR=""
if [ -n "$COST" ] && [ "$COST" != "0" ]; then
  COST_STR=" | \$$(printf '%.2f' "$COST")"
fi

# --- Model ---
MODEL=$(echo "$INPUT" | jq -r '.model.display_name // empty' 2>/dev/null)
MODEL_STR=""
[ -n "$MODEL" ] && MODEL_STR="[${MODEL}] "

# --- Output ---
printf '%b' "${MODEL_STR}${CONTEXT}${LIMITS}${COST_STR}"
