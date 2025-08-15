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
    sudo dnf group install -y "Development Tools"
fi

source scripts/install_zsh.sh
source scripts/install_nvm.sh
source scripts/install_go.sh
source scripts/install_gh_cli.sh
source scripts/install_python_and_pip.sh
source scripts/install_jq.sh
source scripts/install_docker.sh

# --- Zsh and oh my zsh Installation ---
install_zsh "$INSTALL_CMD"
# --- Install NVM ---
install_nvm "$INSTALL_CMD"
# --- Install Go ---
install_go "$INSTALL_CMD"
# --- Install GitHub CLI ---
install_gh_cli "$INSTALL_CMD"
# --- Install Python3 and pip ---
install_python_and_pip "$INSTALL_CMD"
# --- Install jq ---
install_jq "$INSTALL_CMD"
# --- Install Docker ---
install_docker "$PKG_MANAGER"

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
    ln -sf "$PWD/.zsh" "$HOME/.zsh"
    # Add more dotfiles or folders here as needed
    echo -e "${GREEN}✔️ Dotfiles symlinked${NC}"
else
    echo -e "${YELLOW}⚠️ Skipping dotfile symlinking${NC}"
fi

echo "🎉 Setup complete! Restart your terminal or run: exec zsh"