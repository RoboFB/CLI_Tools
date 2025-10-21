#!/bin/bash

# --- detect script directory (where me.json, loc.json, and quack live) ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MEFILE="$SCRIPT_DIR/me.json"
LOCFILE="$SCRIPT_DIR/loc.json"
QUACK="$SCRIPT_DIR/quack"
MAX_AGE=300   # seconds (5 minutes)

# --- helper: get file modification time safely ---
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

# --- current timestamp ---
NOW=$(date +%s)

# --- ensure me.json exists and is recent ---
ME_MOD_TIME=$(get_mtime "$MEFILE")
ME_AGE=$(( NOW - ME_MOD_TIME ))

if [ ! -f "$MEFILE" ]; then
  echo "📄 No me.json found — fetching..."
  "$QUACK" -o "$MEFILE" "/v2/me" 2>/dev/null || {
    echo "❌ Failed to fetch /v2/me"
    exit 1
  }
elif [ $ME_AGE -gt $MAX_AGE ]; then
  echo "🔄 Refreshing stale me.json ($ME_AGE seconds old)..."
  "$QUACK" -o "$MEFILE" "/v2/me" 2>/dev/null || {
    echo "❌ Failed to refresh /v2/me"
    exit 1
  }
else
  echo "✅ Using cached me.json ($MEFILE, ${ME_AGE}s old)"
fi

# --- extract user ID ---
USER_ID=$(jq -r '.id // empty' "$MEFILE")
if [ -z "$USER_ID" ]; then
  echo "❌ Could not extract user ID from $MEFILE"
  exit 1
fi

# --- ensure loc.json is up-to-date ---
LOC_MOD_TIME=$(get_mtime "$LOCFILE")
LOC_AGE=$(( NOW - LOC_MOD_TIME ))

if [ ! -f "$LOCFILE" ] || [ $LOC_AGE -gt $MAX_AGE ]; then
  echo "🔄 Fetching fresh location data..."
  "$QUACK" -o "$LOCFILE" "/v2/users/$USER_ID/locations" 2>/dev/null || {
    echo "❌ Failed to fetch location data"
    exit 1
  }
else
  echo "✅ Using cached location data ($LOCFILE, ${LOC_AGE}s old)"
fi

# --- colors ---
GREEN=$'\033[1;32m'
YELLOW=$'\033[1;33m'
RED=$'\033[1;31m'
RESET=$'\033[0m'
BOLD=$'\033[1m'

# --- time range ---
ONE_WEEK_AGO=$(date -d '7 days ago' +%s 2>/dev/null || date -v-7d +%s)
TODAY=$(date +%Y-%m-%d)

echo "🕓 Logtime summary (last 7 days):"
echo "──────────────────────────────────────────────"

jq -r --argjson weekago "$ONE_WEEK_AGO" '
  map(select(.begin_at != null and .end_at != null)) |
  map({
    begin: (.begin_at | sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601),
    end: (.end_at | sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601)
  }) |
  map(select(.begin > $weekago)) |
  map({
    day: (.begin | strftime("%Y-%m-%d")),
    duration: ((.end - .begin) / 3600)
  }) |
  group_by(.day) |
  map({
    day: .[0].day,
    total: (map(.duration) | add)
  }) |
  sort_by(.day) |
  .[]
  | "\(.day)\t\(.total)"
' "$LOCFILE" | while IFS=$'\t' read -r day total; do
  hours=$(printf "%.2f" "$total")
  color="$GREEN"
  if (( $(echo "$hours < 2" | bc -l) )); then
    color="$YELLOW"
  fi
  if (( $(echo "$hours < 0.5" | bc -l) )); then
    color="$RED"
  fi

  # Bold today's row
  if [[ "$day" == "$TODAY" ]]; then
    printf "${BOLD}%-12s ${color}%6.2f hrs${RESET}\n" "$day" "$hours"
  else
    printf "%-12s ${color}%6.2f hrs${RESET}\n" "$day" "$hours"
  fi
done