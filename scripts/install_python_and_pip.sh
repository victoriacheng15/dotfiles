install_python_and_pip() {
  local INSTALL_CMD="$1"

  if ! command -v python3 >/dev/null 2>&1; then
      echo "🐍 Installing Python3..."
      eval "$INSTALL_CMD python3" || echo "⚠️ Failed to install Python3 from package manager"
  else
      echo "✔️ Python3 already installed"
  fi

  if ! command -v pip3 >/dev/null 2>&1; then
      echo "📦 Installing pip3..."
      eval "$INSTALL_CMD python3-pip" || eval "$INSTALL_CMD pip" || echo "⚠️ Failed to install pip3 from package manager"
  else
      echo "✔️ pip3 already installed"
  fi
}
