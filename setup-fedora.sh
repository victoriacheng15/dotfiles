#!/usr/bin/env bash

# ==============================================================================
# PROFESSIONAL DEV ENVIRONMENT SETUP (FEDORA)
# ==============================================================================
# Overhauled: Monday, February 16, 2026
# Targets: Fedora
# Features: Zsh, K3s, Helm, GitHub CLI, Azure CLI, and desktop runtimes.
# ==============================================================================
# USAGE:
#   Daily Driver:  bash setup-fedora.sh
#   Lean Server:   bash setup-fedora.sh --server (Skips Zsh/Desktop shell setup)
#   Dry Run:       bash setup-fedora.sh --dry-run (Verify logic without installing)
# ==============================================================================
# TESTING IN ISOLATION (PODMAN):
# Fedora:
# podman run -it --rm -v "$(pwd):/root/dotfiles:Z" -w /root/dotfiles fedora:39 bash -c "dnf install -y sudo && bash setup-fedora.sh"
# ==============================================================================

set -euo pipefail

# Fedora package group reference:
# Copy/paste later if you want to install more Fedora groups manually.
# Fedora Desktop default:
# sudo dnf group install -y c-development container-management development-tools editors rpm-development-tools
#
# Fedora Server only:
# sudo dnf group install -y headless-management
#
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

    if [[ "$OS_ID" != "fedora" ]]; then
        error "This script is for Fedora only. Detected: $OS_NAME ($OS_ID)"
        exit 1
    fi

    if ! command -v dnf >/dev/null 2>&1; then
        error "dnf is required for this script."
        exit 1
    fi

    info "Detected OS: $OS_NAME ($OS_ID)"
}

setup_repos() {
    info "Setting up external repositories..."

    execute "sudo curl -fsSL https://cli.github.com/packages/rpm/gh-cli.repo -o /etc/yum.repos.d/gh-cli.repo"

    execute "sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc"
    execute "sudo tee /etc/yum.repos.d/azure-cli.repo <<EOF
[azure-cli]
name=Azure CLI
baseurl=https://packages.microsoft.com/yumrepos/azure-cli
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF"
}

install_shell_tools() {
    if [[ "$SERVER_MODE" == "true" ]]; then
        info "Skipping Zsh shell setup (Server Mode)"
        return
    fi

    info "Installing desktop shell..."
    if ! command -v zsh >/dev/null 2>&1; then
        execute "sudo dnf install -y zsh"
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
    execute "sudo dnf install -y golang rust cargo gh azure-cli"

    if [[ ! -d "$HOME/.nvm" ]]; then
        info "Installing NVM..."
        execute "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/$NVM_VERSION/install.sh | bash"
    else
        info "NVM already installed"
    fi
}

install_containers() {
    info "Skipping Docker installation on Fedora."
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
