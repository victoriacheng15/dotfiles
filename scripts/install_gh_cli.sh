install_gh_cli() {
  local INSTALL_CMD="$1"
  
  if ! command -v gh >/dev/null 2>&1; then
      echo "🔵 Installing GitHub CLI (gh)..."
      eval "$INSTALL_CMD gh" || echo "⚠️ Failed to install GitHub CLI from package manager"
  else
      echo "✔️ GitHub CLI already installed"
  fi
}
