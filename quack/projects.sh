#!/bin/bash

FILE="me.json"
MAX_AGE=300   # seconds (5 minutes)
FILTER="${1:-all}"   # can be "ongoing", "failed", "passed", or "all"

# Detect OS and get file modification time
if [ -f "$FILE" ]; then
  if stat --version >/dev/null 2>&1; then
    MOD_TIME=$(stat -c %Y "$FILE")   # GNU stat
  else
    MOD_TIME=$(stat -f %m "$FILE")   # BSD/macOS stat
  fi
else
  MOD_TIME=0
fi

NOW=$(date +%s)
AGE=$(( NOW - MOD_TIME ))

if [ ! -f "$FILE" ] || [ $AGE -gt $MAX_AGE ]; then
  echo "🔄 Fetching fresh data..."
  ./quack -o "$FILE" "/v2/me" 2> /dev/null
else
  echo "✅ Using cached data ($FILE, ${AGE}s old)"
fi

# Define colors
GREEN=$'\033[1;32m'
RED=$'\033[1;31m'
YELLOW=$'\033[1;33m'
RESET=$'\033[0m'

# Extract and format
jq -r '.projects_users[] | [.project.name, (.final_mark // "ongoing")] | @tsv' "$FILE" |
while IFS=$'\t' read -r name grade; do
  # Determine type and color
  if [[ "$grade" == "ongoing" ]]; then
    status="ongoing"
    color="$YELLOW"
  elif [[ "$grade" =~ ^[0-9]+$ ]]; then
    if (( grade >= 80 )); then
      status="passed"
      color="$GREEN"
    else
      status="failed"
      color="$RED"
    fi
  else
    status="unknown"
    color="$RESET"
  fi

  # Apply filter
  case "$FILTER" in
    ongoing)
      [[ "$status" != "ongoing" ]] && continue
      ;;
    failed)
      [[ "$status" != "failed" ]] && continue
      ;;
    passed)
      [[ "$status" != "passed" ]] && continue
      ;;
  esac

  printf "%-35s %s%8s%s\n" "$name" "$color" "$grade" "$RESET"
done