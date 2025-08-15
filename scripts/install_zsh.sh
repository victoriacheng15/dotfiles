install_zsh() {
  local INSTALL_CMD="$1"

  if ! command -v zsh >/dev/null 2>&1; then
      echo "🌀 Installing Zsh..."
      eval "$INSTALL_CMD zsh"
  else
      echo "✔️ Zsh already installed"
  fi

  if [ ! -d "$HOME/.oh-my-zsh" ]; then
      echo "✨ Installing Oh My Zsh..."
      RUNZSH=no CHSH=no sh -c \
          "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  else
      echo "✔️ - Oh My Zsh already installed"
  fi
}