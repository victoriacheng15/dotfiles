#!/usr/bin/env bash
set -e  # exit if anything fails

# Color variables
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions for logging
info() { echo -e "${GREEN}[INFO] $*${NC}"; }
error() { echo -e "${YELLOW}[ERROR] $*${NC}" >&2; }

echo "🚀 Setting up dev environment..."

# --- Detect Package Manager ---
if command -v apt >/dev/null 2>&1; then
  PKG_MANAGER="apt"
  echo "Running: sudo apt update && sudo apt upgrade -y"
  sudo apt update >/dev/null 2>&1 && sudo apt upgrade -y >/dev/null 2>&1
  INSTALL_CMD="sudo apt install -y"
elif command -v dnf >/dev/null 2>&1; then
  PKG_MANAGER="dnf"
  echo "Running: sudo dnf upgrade --refresh -y"
  sudo dnf upgrade --refresh -y >/dev/null 2>&1
  INSTALL_CMD="sudo dnf install -y"
else
    echo "❌ No supported package manager found (apt or dnf). Exiting."
    exit 1
fi

echo "📦 Detected package manager: $PKG_MANAGER"

# --- Install Dev Tools group (Fedora only) ---
if [ "$PKG_MANAGER" = "dnf" ]; then
    echo -e "${GREEN}📦 Installing Fedora Development Tools...${NC}"
    sudo dnf group install development-tools
fi

# Install Nix package manager
install_nix() {
    if command -v nix >/dev/null 2>&1; then
        info "✔️ Nix already installed."
        return 0
    fi
    info "Installing Nix package manager..."
    # Official multi-user install, non-interactive
    sh <(curl -L https://nixos.org/nix/install) --daemon || {
        error "Nix installation failed. Please check logs or install manually."
        return 1
    }
    info "Nix installation complete. You may need to restart your shell or source /etc/profile.d/nix.sh."
}

install_zsh() {
  local INSTALL_CMD="$1"

  if ! command -v zsh >/dev/null 2>&1; then
    info "Installing Zsh..."
      eval "$INSTALL_CMD zsh"
  else
    info "✔️ Zsh already installed"
  fi

  if [ ! -d "$HOME/.oh-my-zsh" ]; then
    info "Installing Oh My Zsh..."
      RUNZSH=no CHSH=no sh -c \
          "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  else
    info "✔️ Oh My Zsh already installed"
  fi
}

install_docker() {
  local PKG_MANAGER="$1"

  if ! command -v docker >/dev/null 2>&1; then
      info "Installing Docker..."
      if [ "$PKG_MANAGER" = "apt" ]; then
          sudo apt remove -y docker docker-engine docker.io containerd runc || true
          sudo apt install -y ca-certificates curl gnupg lsb-release
          sudo mkdir -p /etc/apt/keyrings
          curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
          echo \
            "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
            $(lsb_release -cs) stable" | \
            sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
          sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
      elif [ "$PKG_MANAGER" = "dnf" ]; then
          sudo dnf -y remove docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine || true
          sudo dnf -y install dnf-plugins-core
          sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
          sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
          sudo systemctl enable --now docker
      else
          error "Docker installation not supported for this package manager."
      fi
  else
      info "✔️ Docker already installed"
  fi
}

install_gh_cli() {
  local INSTALL_CMD="$1"

  if ! command -v gh >/dev/null 2>&1; then
    info "Installing GitHub CLI (gh)..."
      eval "$INSTALL_CMD gh" || error "Failed to install GitHub CLI from package manager"
  else
    info "✔️ GitHub CLI already installed"
  fi
}

install_azure() {
  if command -v az >/dev/null 2>&1; then
    info "✔️ Azure CLI already installed"
    return
  fi
  if [ "$PKG_MANAGER" = "apt" ]; then
    sudo apt-get install -y ca-certificates curl gnupg lsb-release apt-transport-https
    curl -sL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | sudo tee /usr/share/keyrings/microsoft-archive-keyring.gpg >/dev/null
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/microsoft-archive-keyring.gpg] https://packages.microsoft.com/repos/azure-cli/ $(lsb_release -cs) main" \
      | sudo tee /etc/apt/sources.list.d/azure-cli.list
  sudo apt-get update >/dev/null 2>&1 && sudo apt-get install -y azure-cli
  elif [ "$PKG_MANAGER" = "dnf" ]; then
    sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
    sudo tee /etc/yum.repos.d/azure-cli.repo > /dev/null <<'EOF'
[azure-cli]
name=Azure CLI
baseurl=https://packages.microsoft.com/yumrepos/azure-cli
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF
    sudo dnf -y install azure-cli
  fi
}

install_aws() {
  echo "AWS installation function placeholder"
}

install_gcp() {
  echo "GCP installation function placeholder"
}

install_cockpit() {
  local INSTALL_CMD="$1"

  # Cockpit doesn't always have a CLI binary, so we check systemd instead
  if ! systemctl is-active --quiet cockpit 2>/dev/null; then
    info "Installing Cockpit..."
    eval "$INSTALL_CMD cockpit" || error "Failed to install Cockpit"

    # Enable/start cockpit via socket (preferred), fallback to service
    if command -v systemctl >/dev/null 2>&1; then
      systemctl enable --now cockpit.socket 2>/dev/null || \
      systemctl enable --now cockpit 2>/dev/null || \
      error "Failed to enable/start Cockpit"
    fi
  else
    info "✔️ Cockpit already installed"
  fi
}

install_jq() {
  local INSTALL_CMD="$1"

  if ! command -v jq >/dev/null 2>&1; then
    info "Installing jq..."
      eval "$INSTALL_CMD jq" || error "Failed to install jq from package manager"
  else
    info "✔️ jq already installed"
  fi
}

install_nvm() {
  # Only install if $HOME/.nvm does not exist
  if [ ! -d "$HOME/.nvm" ]; then
    info "Installing NVM (Node Version Manager)..."
    NVM_VERSION=$(curl -s https://api.github.com/repos/nvm-sh/nvm/releases/latest | jq -r .tag_name)
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/$NVM_VERSION/install.sh | bash
  else
    info "✔️ NVM already installed"
  fi
}

setup_ssh() {
  read -p "Do you want to generate a new SSH key for Git/GitHub? [y/N]: " SETUP_SSH
  if [[ "$SETUP_SSH" =~ ^[Yy]$ ]]; then
      if [ -f "$HOME/.ssh/id_ed25519" ] || [ -f "$HOME/.ssh/id_rsa" ]; then
          error "SSH key already exists in ~/.ssh"
      else
          read -p "Enter your email for SSH key: " SSH_EMAIL
          ssh-keygen -t ed25519 -C "$SSH_EMAIL" -f "$HOME/.ssh/id_ed25519" -N ""
          info "✔️ SSH key generated at ~/.ssh/id_ed25519"
          echo -e "${BLUE}Your public key:${NC}"
          cat "$HOME/.ssh/id_ed25519.pub"
      fi
  else
      error "Skipping SSH key setup"
  fi
}

setup_symlink(){
    read -p "Do you want to symlink your dotfiles to your home directory? [y/N]: " LINK_DOTFILES
    if [[ "$LINK_DOTFILES" =~ ^[Yy]$ ]]; then
      # Simple symlink check and log for each file
      for file in .zshrc .gitconfig; do
        if [ -L "$HOME/$file" ]; then
          info "$HOME/$file is a symlink."
        else
          info "$HOME/$file is NOT a symlink. Creating symlink..."
          ln -sf "$PWD/$file" "$HOME/$file"
          info "Linked $HOME/$file -> $PWD/$file"
        fi
      done
    else
      error "Skipping dotfile symlinking"
    fi
}

# --- Main setup routine ---
main() {
    install_nix
    install_zsh "$INSTALL_CMD"
    install_docker "$PKG_MANAGER"
    install_gh_cli "$INSTALL_CMD"
    install_azure
    install_jq "$INSTALL_CMD"
    install_nvm

  # --- Home server admin (Cockpit) ---
  read -p "Do you want to install Cockpit (web admin for home servers)? [y/N]: " INSTALL_COCKPIT
  if [[ "$INSTALL_COCKPIT" =~ ^[Yy]$ ]]; then
    install_cockpit "$INSTALL_CMD"
  fi

    setup_ssh
    setup_symlink
}

# Call main setup
main
echo "🎉 Setup complete! Restart your terminal"

