#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WRAPPER="$SCRIPT_DIR/quack-wrapper.sh"

# Detect shell and rc file
if [[ $SHELL == *zsh ]]; then
  RC_FILE="$HOME/.zshrc"
elif [[ $SHELL == *bash ]]; then
  RC_FILE="$HOME/.bashrc"
else
  RC_FILE="$HOME/.profile"
fi

# --- Functions ---

install_quack() {
  # Create unified wrapper
  cat > "$WRAPPER" <<'EOF'
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUBCMD="$1"
shift || true

case "$SUBCMD" in
  me)
    "$SCRIPT_DIR/quack" -o "$SCRIPT_DIR/me.json" "/v2/me" "$@"
    ;;
  projects)
    "$SCRIPT_DIR/projects.sh" "$@"
    ;;
  logtime)
    "$SCRIPT_DIR/logtime.sh" "$@"
    ;;
  subject)
    "$SCRIPT_DIR/subject.sh" "$@"
    ;;
  raw)
    if [ -z "$1" ]; then
      echo "Usage: quack raw /v2/some/endpoint"
      exit 1
    fi
    "$SCRIPT_DIR/quack" -o "$SCRIPT_DIR/tmp.json" "$@"
    ;;
  *)
    echo "🐤 Quack CLI — available commands:"
    echo "  quack me           → fetch /v2/me"
    echo "  quack projects     → list projects & grades"
    echo "  quack logtime      → show recent logtime"
    echo "  quack subject NAME → open project subject"
    echo "  quack raw /v2/...  → fetch arbitrary endpoint"
    ;;
esac
EOF

  chmod +x "$WRAPPER"

  # Add alias
  if ! grep -q "# --- 42Quack unified alias ---" "$RC_FILE" 2>/dev/null; then
    {
      echo ""
      echo "# --- 42Quack unified alias ---"
      echo "alias quack='$WRAPPER'"
    } >> "$RC_FILE"
    echo "✅ Installed alias 'quack' into $RC_FILE"
  else
    echo "✅ Alias 'quack' already present in $RC_FILE"
  fi

  # Ensure executables
  chmod +x "$SCRIPT_DIR/quack" "$SCRIPT_DIR"/*.sh 2>/dev/null || true

  # --- Check for existing session ---
  SESSION_FILE="$SCRIPT_DIR/.quack_session"
  if [ ! -f "$SESSION_FILE" ]; then
    echo "🚀 No active session detected."
    echo "Running initial login — this will open your authorization URL:"
    echo ""
    "$SCRIPT_DIR/quack" "/v2/me" || true
    echo ""
    echo "✅ Once you see 'Authorized!' above, you can safely use:"
    echo "   quack me"
    echo "   quack projects"
    echo ""
  else
    echo "✅ Existing session detected in $SESSION_FILE"
  fi

  echo "🔧 Done! Run:"
  echo "  source $RC_FILE"
  echo "or open a new terminal."
}

uninstall_quack() {
  echo "🧹 Uninstalling Quack CLI..."

  # Remove alias block
  if grep -q "# --- 42Quack unified alias ---" "$RC_FILE" 2>/dev/null; then
    sed -i.bak '/# --- 42Quack unified alias ---/,+1d' "$RC_FILE"
    echo "🗑️  Removed alias from $RC_FILE"
  else
    echo "ℹ️  No alias block found in $RC_FILE"
  fi

  # Remove wrapper script
  if [ -f "$WRAPPER" ]; then
    rm -f "$WRAPPER"
    echo "🗑️  Removed $WRAPPER"
  fi

  # Optionally remove session file
  SESSION_FILE="$SCRIPT_DIR/.quack_session"
  if [ -f "$SESSION_FILE" ]; then
    read -p "🗑️  Delete session file (.quack_session)? [y/N] " yn
    case "$yn" in
      [Yy]*) rm -f "$SESSION_FILE"; echo "✅ Session removed." ;;
      *) echo "⏭️  Session kept." ;;
    esac
  fi

  echo "✅ Uninstall complete."
}

# --- Entry point ---
case "$1" in
  uninstall)
    uninstall_quack
    ;;
  reinstall)
    uninstall_quack
    install_quack
    ;;
  *)
    install_quack
    ;;
esac