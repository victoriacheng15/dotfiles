install_jq() {
  local INSTALL_CMD="$1"

  if ! command -v jq >/dev/null 2>&1; then
      echo "🔶 Installing jq..."
      eval "$INSTALL_CMD jq" || echo "⚠️ Failed to install jq from package manager"
  else
      echo "✔️ jq already installed"
  fi
}
