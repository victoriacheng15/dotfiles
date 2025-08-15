install_go() {
  local INSTALL_CMD="$1"

  if ! command -v go >/dev/null 2>&1; then
      echo "🟡 Installing Go..."
      eval "$INSTALL_CMD golang" || echo "⚠️ Failed to install Go from package manager"
  else
      echo "✔️ Go already installed"
  fi
}
