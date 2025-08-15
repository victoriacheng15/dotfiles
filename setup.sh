#!/usr/bin/env bash
set -e  # exit if anything fails

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
    echo "🛠 Installing Fedora Development Tools..."
    sudo dnf group install -y "Development Tools"
fi

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

echo "🎉 Setup complete! Restart your terminal or run: exec zsh"