#!/usr/bin/env bash
set -e  # exit if anything fails

# Color variables
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "🚀 Setting up dev environment..."

# --- Detect Package Manager ---
if command -v apt >/dev/null 2>&1; then
    PKG_MANAGER="apt"
    UPDATE_CMD="sudo apt update && sudo apt upgrade -y"
    INSTALL_CMD="sudo apt install -y"
elif command -v dnf >/dev/null 2>&1; then
    PKG_MANAGER="dnf"
    UPDATE_CMD="sudo dnf upgrade --refresh -y"
    INSTALL_CMD="sudo dnf install -y"
else
    echo "❌ No supported package manager found (apt or dnf). Exiting."
    exit 1
fi

echo "📦 Detected package manager: $PKG_MANAGER"
eval "$UPDATE_CMD"

# --- Install Dev Tools group (Fedora only) ---
if [ "$PKG_MANAGER" = "dnf" ]; then
    echo -e "${GREEN}📦 Installing Fedora Development Tools...${NC}"
    sudo dnf group install development-tools
fi

# Install Nix package manager
install_nix() {
    if command -v nix >/dev/null 2>&1; then
        info "Nix already installed."
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
    echo -e "${GREEN}📦 Installing Zsh...${NC}"
      eval "$INSTALL_CMD zsh"
  else
    echo -e "${GREEN}✔️ Zsh already installed${NC}"
  fi

  if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo -e "${GREEN}📦 Installing Oh My Zsh...${NC}"
      RUNZSH=no CHSH=no sh -c \
          "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  else
    echo -e "${GREEN}✔️ Oh My Zsh already installed${NC}"
  fi
}

install_docker() {
  local PKG_MANAGER="$1"

  if ! command -v docker >/dev/null 2>&1; then
      echo -e "${GREEN}📦 Installing Docker...${NC}"
      if [ "$PKG_MANAGER" = "apt" ]; then
          sudo apt remove -y docker docker-engine docker.io containerd runc || true
          sudo apt install -y ca-certificates curl gnupg lsb-release
          sudo mkdir -p /etc/apt/keyrings
          curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
          echo \
            "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
            $(lsb_release -cs) stable" | \
            sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
          sudo apt update
          sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
      elif [ "$PKG_MANAGER" = "dnf" ]; then
          sudo dnf -y remove docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine || true
          sudo dnf -y install dnf-plugins-core
          sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
          sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
          sudo systemctl enable --now docker
      else
          echo -e "${YELLOW}⚠️ Docker installation not supported for this package manager.${NC}"
      fi
  else
      echo -e "${GREEN}✔️ Docker already installed${NC}"
  fi
}

install_gh_cli() {
  local INSTALL_CMD="$1"

  if ! command -v gh >/dev/null 2>&1; then
    echo -e "${GREEN}📦 Installing GitHub CLI (gh)...${NC}"
      eval "$INSTALL_CMD gh" || echo -e "${YELLOW}⚠️ Failed to install GitHub CLI from package manager${NC}"
  else
    echo -e "${GREEN}✔️ GitHub CLI already installed${NC}"
  fi
}

install_jq() {
  local INSTALL_CMD="$1"

  if ! command -v jq >/dev/null 2>&1; then
    echo -e "${GREEN}📦 Installing jq...${NC}"
      eval "$INSTALL_CMD jq" || echo -e "${YELLOW}⚠️ Failed to install jq from package manager${NC}"
  else
    echo -e "${GREEN}✔️ jq already installed${NC}"
  fi
}

# --- Main setup routine ---
main() {
    install_nix
    install_zsh "$INSTALL_CMD"
    install_docker "$PKG_MANAGER"
    install_gh_cli "$INSTALL_CMD"
    install_jq "$INSTALL_CMD"

    # --- Setup Git config ---
    read -p "Do you want to configure git (name, email, etc)? [y/N]: " SETUP_GIT
    if [[ "$SETUP_GIT" =~ ^[Yy]$ ]]; then
        read -p "Enter your git user.name: " GIT_NAME
        read -p "Enter your git user.email: " GIT_EMAIL
        git config --global user.name "$GIT_NAME"
        git config --global user.email "$GIT_EMAIL"
        echo -e "${GREEN}✔️ Git config set${NC}"
    else
        echo -e "${YELLOW}⚠️ Skipping git config${NC}"
    fi

    # --- Setup SSH key ---
    read -p "Do you want to generate a new SSH key for Git/GitHub? [y/N]: " SETUP_SSH
    if [[ "$SETUP_SSH" =~ ^[Yy]$ ]]; then
        if [ -f "$HOME/.ssh/id_ed25519" ] || [ -f "$HOME/.ssh/id_rsa" ]; then
            echo -e "${YELLOW}⚠️ SSH key already exists in ~/.ssh${NC}"
        else
            read -p "Enter your email for SSH key: " SSH_EMAIL
            ssh-keygen -t ed25519 -C "$SSH_EMAIL" -f "$HOME/.ssh/id_ed25519" -N ""
            echo -e "${GREEN}✔️ SSH key generated at ~/.ssh/id_ed25519${NC}"
            echo -e "${BLUE}Your public key:${NC}"
            cat "$HOME/.ssh/id_ed25519.pub"
        fi
    else
        echo -e "${YELLOW}⚠️ Skipping SSH key setup${NC}"
    fi

    # --- Symlink dotfiles ---
    read -p "Do you want to symlink your dotfiles to your home directory? [y/N]: " LINK_DOTFILES
    if [[ "$LINK_DOTFILES" =~ ^[Yy]$ ]]; then
        echo -e "${GREEN}📦 Symlinking dotfiles...${NC}"
        ln -sf "$PWD/.zshrc" "$HOME/.zshrc"
        ln -sf "$PWD/.gitconfig" "$HOME/.gitconfig"
        ln -sf "$PWD/flake.nix" "$HOME/flake.nix"
        # Add more dotfiles or folders here as needed
        echo -e "${GREEN}✔️ Dotfiles symlinked${NC}"
    else
        echo -e "${YELLOW}⚠️ Skipping dotfile symlinking${NC}"
    fi
}

# Call main setup
main
echo "🎉 Setup complete! Restart your terminal or run: exec zsh"