#!/bin/bash

FILE="projects.json"
MAX_AGE=300   # seconds (5 minutes)

# Detect OS and get file modification time
if [ -f "$FILE" ]; then
  if stat --version >/dev/null 2>&1; then
    # GNU stat (Linux)
    MOD_TIME=$(stat -c %Y "$FILE")
  else
    # BSD / macOS stat
    MOD_TIME=$(stat -f %m "$FILE")
  fi
else
  MOD_TIME=0
fi

NOW=$(date +%s)
AGE=$(( NOW - MOD_TIME ))

if [ ! -f "$FILE" ] || [ $AGE -gt $MAX_AGE ]; then
  echo "🔄 Fetching fresh data..."
  ./quack -o "$FILE" "/v2/users/modiepge" 2> /dev/null
else
  echo "✅ Using cached data ($FILE, ${AGE}s old)"
fi

# Extract and print project names
jq -r '.projects_users[].project.name' "$FILE"