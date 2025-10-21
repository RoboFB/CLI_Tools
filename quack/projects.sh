#!/bin/bash

# --- Script setup ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FILE="$SCRIPT_DIR/me.json"
QUACK="$SCRIPT_DIR/quack"
MAX_AGE=300   # seconds (5 minutes)
FILTER="${1:-all}"   # can be "ongoing", "failed", "passed", or "all"

# --- Helper: get modification time cross-platform ---
get_mtime() {
  if [ -f "$1" ]; then
    if stat --version >/dev/null 2>&1; then
      stat -c %Y "$1"   # GNU
    else
      stat -f %m "$1"   # BSD/macOS
    fi
  else
    echo 0
  fi
}

# --- Check freshness of me.json ---
NOW=$(date +%s)
MOD_TIME=$(get_mtime "$FILE")
AGE=$(( NOW - MOD_TIME ))

if [ ! -f "$FILE" ]; then
  echo "📄 No me.json found — fetching..."
  "$QUACK" -o "$FILE" "/v2/me" 2>/dev/null || {
    echo "❌ Failed to fetch /v2/me"
    exit 1
  }
elif [ $AGE -gt $MAX_AGE ]; then
  echo "🔄 Refreshing stale me.json ($AGE seconds old)..."
  "$QUACK" -o "$FILE" "/v2/me" 2>/dev/null || {
    echo "❌ Failed to refresh /v2/me"
    exit 1
  }
else
  echo "✅ Using cached data ($FILE, ${AGE}s old)"
fi

# --- Colors ---
GREEN=$'\033[1;32m'
RED=$'\033[1;31m'
YELLOW=$'\033[1;33m'
RESET=$'\033[0m'

# --- Parse and display projects ---
jq -r '.projects_users[] | [.project.name, (.final_mark // "ongoing")] | @tsv' "$FILE" |
while IFS=$'\t' read -r name grade; do
  # Determine status and color
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

  # Filter by argument
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