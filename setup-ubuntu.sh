#!/usr/bin/env bash

# ==============================================================================
# PROFESSIONAL DEV ENVIRONMENT SETUP (UBUNTU/DEBIAN)
# ==============================================================================
# Overhauled: Monday, February 16, 2026
# Targets: Ubuntu/Debian
# Features: Zsh, Docker, K3s, Helm, GitHub CLI, Azure CLI, and desktop runtimes.
# ==============================================================================
# USAGE:
#   Daily Driver:  bash setup-ubuntu.sh
#   Lean Server:   bash setup-ubuntu.sh --server (Skips Zsh/Desktop shell setup)
#   Dry Run:       bash setup-ubuntu.sh --dry-run (Verify logic without installing)
# ==============================================================================
# TESTING IN ISOLATION (DOCKER):
# Ubuntu:
# docker run -it --rm -v "$(pwd):/root/dotfiles" -w /root/dotfiles ubuntu:22.04 bash -c "apt update && apt install -y sudo && bash setup-ubuntu.sh"
# ==============================================================================

set -euo pipefail

# AI agent CLI reference:
# Run after NVM/Node is installed.
#
# npm install -g @google/gemini-cli
# npm install -g @openai/codex
# gh extension install github/gh-copilot
#
# K9s reference:
# https://github.com/derailed/k9s/releases

# --- 1. ENGINE: CONFIGURATION & LOGGING ---
DRY_RUN=false
SERVER_MODE=false
# Check latest NVM release: https://github.com/nvm-sh/nvm/releases
NVM_VERSION="v0.40.3"
OS_ID=""
OS_NAME=""
OS_CODENAME=""

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

info() { echo -e "${GREEN}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

execute() {
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${CYAN}[DRY-RUN]${NC} Would execute: $*"
    else
        eval "$@"
    fi
}

detect_os() {
    if [[ ! -f /etc/os-release ]]; then
        error "Cannot detect OS. /etc/os-release missing."
        exit 1
    fi

    . /etc/os-release
    OS_ID="$ID"
    OS_NAME="$NAME"
    OS_CODENAME="${VERSION_CODENAME:-}"

    if [[ "$OS_ID" != "ubuntu" && "$OS_ID" != "debian" ]]; then
        error "This script is for Ubuntu/Debian only. Detected: $OS_NAME ($OS_ID)"
        exit 1
    fi

    if [[ -z "$OS_CODENAME" ]]; then
        error "Cannot determine Ubuntu/Debian codename from /etc/os-release."
        exit 1
    fi

    if ! command -v apt >/dev/null 2>&1; then
        error "apt is required for this script."
        exit 1
    fi

    info "Detected OS: $OS_NAME ($OS_ID)"
}

setup_repos() {
    info "Setting up external repositories..."
    execute "sudo apt update && sudo apt install -y ca-certificates curl gnupg"
    execute "sudo mkdir -p /etc/apt/keyrings"

    execute "curl -fsSL https://download.docker.com/linux/$OS_ID/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg --yes"
    execute "echo \"deb [arch=\$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$OS_ID $OS_CODENAME stable\" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null"

    execute "curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo gpg --dearmor -o /etc/apt/keyrings/githubcli-archive-keyring.gpg --yes"
    execute "echo \"deb [arch=\$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main\" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null"

    execute "sudo apt update"
}

install_shell_tools() {
    if [[ "$SERVER_MODE" == "true" ]]; then
        info "Skipping Zsh shell setup (Server Mode)"
        return
    fi

    info "Installing desktop shell..."
    if ! command -v zsh >/dev/null 2>&1; then
        execute "sudo apt install -y zsh"
    else
        info "Zsh already installed"
    fi

    if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
        info "Installing Oh My Zsh..."
        execute "CHSH=no RUNZSH=no sh -c \"\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\""
    fi

    if [[ -f "$HOME/.bashrc" ]] && ! grep -q "exec zsh" "$HOME/.bashrc"; then
        info "Configuring .bashrc to auto-switch to Zsh..."
        execute "echo -e '\n# Auto-switch to Zsh\nif [ -x /usr/bin/zsh ]; then\n  exec zsh\nfi' >> $HOME/.bashrc"
    fi
}

install_runtimes() {
    info "Installing runtimes and CLIs..."
    execute "sudo apt install -y golang-go rustc cargo gh azure-cli"

    if [[ ! -d "$HOME/.nvm" ]]; then
        info "Installing NVM..."
        execute "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/$NVM_VERSION/install.sh | bash"
    else
        info "NVM already installed"
    fi
}

install_containers() {
    info "Installing Docker suite..."
    execute "sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin"

    if [[ -f /proc/1/comm ]] && [[ "$(cat /proc/1/comm)" == "systemd" ]]; then
        execute "sudo systemctl enable --now docker"
    fi

    warn "Adding $USER to docker group..."
    execute "sudo usermod -aG docker $USER"
}

install_k3s() {
    info "Installing K3s and Helm..."
    if ! command -v k3s >/dev/null 2>&1; then
        execute "curl -sfL https://get.k3s.io | sh -"
    fi

    if ! command -v helm >/dev/null 2>&1; then
        execute "curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash"
    fi
}

setup_dotfiles() {
    info "Setting up Git bare repository for dotfiles..."

    local dot_dir="$HOME/.dotfiles"

    if [[ ! -d "$dot_dir" ]]; then
        info "Initializing bare repository at $dot_dir..."
        execute "git clone --bare . \"$dot_dir\""
    else
        info "Bare repository already exists at $dot_dir. Updating configuration..."
        # Update the bare repository from the current directory
        execute "git --git-dir=\"$dot_dir\" remote set-url origin \".\" 2>/dev/null || true"
        execute "git --git-dir=\"$dot_dir\" fetch origin main:main 2>/dev/null || true"
    fi

    # Configure local bare repository
    execute "git --git-dir=\"$dot_dir\" --work-tree=\"$HOME\" config --local status.showUntrackedFiles no"

    # Enable sparse-checkout to keep home directory clean
    info "Configuring sparse-checkout to keep home directory clean..."
    execute "git --git-dir=\"$dot_dir\" --work-tree=\"$HOME\" sparse-checkout init --cone"
    execute "git --git-dir=\"$dot_dir\" --work-tree=\"$HOME\" sparse-checkout set .zshrc .gitconfig .gemini"

    # Backup existing non-symlink config files if they differ
    for f in .zshrc .gitconfig; do
        if [[ -f "$HOME/$f" && ! -L "$HOME/$f" ]]; then
            warn "Existing file $HOME/$f found. Backing up to $f.backup"
            execute "mv \"$HOME/$f\" \"$HOME/$f.backup\""
        fi
    done

    # Checkout the files into the home directory
    info "Checking out dotfiles from bare repository..."
    execute "git --git-dir=\"$dot_dir\" --work-tree=\"$HOME\" checkout -f"
}

print_verification() {
    echo -e "\n${GREEN}Installation is completed!${NC}"
    info "---------------------------------"
    info "Tool Verification:"
    command -v az >/dev/null && info "  Azure CLI: $(az --version | head -n 1)"
    command -v gh >/dev/null && info "  GitHub CLI: $(gh --version | head -n 1)"
    command -v docker >/dev/null && info "  Docker:    $(docker --version)"
    command -v tofu >/dev/null && info "  OpenTofu:  $(tofu --version | head -n 1)"
    command -v kubectl >/dev/null && info "  Kubectl:   $(kubectl version --client --short 2>/dev/null || kubectl version --client | head -n 1)"
    [[ -s "$HOME/.nvm/nvm.sh" ]] && source "$HOME/.nvm/nvm.sh" && command -v node >/dev/null && info "  Node.js:   $(node --version)"
    info "---------------------------------"
    info "Next Steps:"
    info "  Run: 'reload-shell' to apply changes"
    info "  Run: 'gh auth login' to enable GitHub Copilot"
}

main() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run) DRY_RUN=true; shift ;;
            --server) SERVER_MODE=true; shift ;;
            *) error "Unknown option: $1"; exit 1 ;;
        esac
    done

    [[ "$DRY_RUN" == "true" ]] && info "RUNNING IN DRY-RUN MODE"
    [[ "$SERVER_MODE" == "true" ]] && info "RUNNING IN SERVER MODE (Skipping desktop shell setup)"

    detect_os
    setup_repos
    install_shell_tools
    install_runtimes
    install_containers
    install_k3s
    setup_dotfiles

    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "\n${GREEN}Dry run completed successfully.${NC}"
        info "No packages, repositories, services, or dotfiles were changed."
        return
    fi

    print_verification
}

main "$@"
