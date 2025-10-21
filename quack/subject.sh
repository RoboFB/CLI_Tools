#!/bin/bash
# Opens the 42 Intra subject page for a project.
# Works anywhere, even on macOS (no mapfile/select).

# --- detect script directory (where quack + me.json live) ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MEFILE="$SCRIPT_DIR/me.json"
QUACK="$SCRIPT_DIR/quack"

# --- ensure me.json exists ---
if [ ! -f "$MEFILE" ]; then
  echo "📄 No me.json found — fetching..."
  if [ -x "$QUACK" ]; then
    "$QUACK" -o "$MEFILE" "/v2/me" 2>/dev/null || {
      echo "❌ Failed to fetch /v2/me"
      exit 1
    }
  else
    echo "❌ quack executable not found in $SCRIPT_DIR"
    exit 1
  fi
fi

# --- determine project name ---
PROJECT_NAME="$1"

if [ -z "$PROJECT_NAME" ]; then
  PROJECT_NAME=$(basename "$PWD")
  PROJECT_NAME=$(echo "$PROJECT_NAME" | sed -E 's/[_-](bonus|final|v2|v3|project)$//I')
  echo "📁 Using current directory as project: $PROJECT_NAME"
fi

# --- try to find slug from me.json ---
SLUG=$(jq -r --arg name "$PROJECT_NAME" '
  .projects_users[]
  | select(.project.name | ascii_downcase == ($name | ascii_downcase))
  | .project.slug
' "$MEFILE")

# --- fallback: interactive picker if not found ---
if [ -z "$SLUG" ] || [ "$SLUG" = "null" ]; then
  echo "⚠️  Project '$PROJECT_NAME' not found. Listing ongoing projects..."

  PROJECTS=$(jq -r '
    .projects_users[]
    | select(.final_mark == null)
    | .project.name
  ' "$MEFILE" | sort -f)

  if [ -z "$PROJECTS" ]; then
    echo "✅ No ongoing projects found!"
    exit 0
  fi

  if command -v fzf >/dev/null 2>&1; then
    PROJECT_NAME=$(printf "%s\n" "$PROJECTS" | fzf --prompt="Select project: ")
  else
    echo "$PROJECTS" | nl -w2 -s') '
    printf "Select project number: "
    read -r choice
    PROJECT_NAME=$(echo "$PROJECTS" | sed -n "${choice}p")
  fi

  [ -z "$PROJECT_NAME" ] && { echo "❌ No project selected."; exit 1; }

  SLUG=$(jq -r --arg name "$PROJECT_NAME" '
    .projects_users[]
    | select(.project.name | ascii_downcase == ($name | ascii_downcase))
    | .project.slug
  ' "$MEFILE")
fi

# --- validate slug ---
if [ -z "$SLUG" ] || [ "$SLUG" = "null" ]; then
  echo "❌ Could not find slug for '$PROJECT_NAME'"
  exit 1
fi

# --- open subject page ---
URL="https://projects.intra.42.fr/projects/$SLUG"
echo "🔗 Opening subject page for '$PROJECT_NAME':"
echo "   $URL"

if command -v open >/dev/null 2>&1; then
  open "$URL"
elif command -v xdg-open >/dev/null 2>&1; then
  xdg-open "$URL" >/dev/null 2>&1 &
else
  echo -e "\033[1;34m$URL\033[0m"
fi