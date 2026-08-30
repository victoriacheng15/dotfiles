#!/usr/bin/env bash

# ==============================================================================
# 🚀 PROFESSIONAL DEV ENVIRONMENT SETUP (UBUNTU & FEDORA)
# ==============================================================================
# Overhauled: Monday, February 16, 2026
# Targets: Ubuntu/Debian & Fedora
# Features: Zsh, Docker on Ubuntu/Debian, K3s, Helm, GitHub CLI, and desktop runtimes.
# ==============================================================================
# 🚀 USAGE:
#   Daily Driver:  bash setup.sh
#   Lean Server:   bash setup.sh --server (Skips Zsh/Desktop shell setup)
#   Dry Run:       bash setup.sh --dry-run (Verify logic without installing)
# ==============================================================================
# 🧪 TESTING IN ISOLATION (DOCKER):
# Ubuntu: 
# docker run -it --rm -v "$(pwd):/root/dotfiles" -w /root/dotfiles ubuntu:22.04 bash -c "apt update && apt install -y sudo && bash setup.sh"
# Fedora: 
# docker run -it --rm -v "$(pwd):/root/dotfiles" -w /root/dotfiles fedora:39 bash -c "dnf install -y sudo && bash setup.sh"
# ==============================================================================

# Exit on error, unset vars, and pipe failures.
set -euo pipefail

# Fedora package group reference:
# Copy/paste later if you want to install more Fedora groups manually.
# Fedora Desktop default:
# sudo dnf group install -y c-development container-management development-tools domain-client editors rpm-development-tools
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
OS_LIKE=""
OS_CODENAME=""
PKG_MGR=""
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

# --- 2. ADAPTER: OS DETECTION ---
detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS_ID="$ID"
        OS_NAME="$NAME"
        OS_LIKE="${ID_LIKE:-$ID}"
        OS_CODENAME="${VERSION_CODENAME:-}"
        info "Detected OS: $OS_NAME ($OS_ID)"
    else
        error "Cannot detect OS. /etc/os-release missing."
        exit 1
    fi

    if command -v apt >/dev/null 2>&1; then
        PKG_MGR="apt"
    elif command -v dnf >/dev/null 2>&1; then
        PKG_MGR="dnf"
    else
        error "Unsupported package manager (need apt or dnf)."
        exit 1
    fi
}

# --- 3. REPOSITORIES & CORE BUILD TOOLS ---
setup_repos() {
    info "Setting up external repositories..."
    if [[ "$PKG_MGR" == "apt" ]]; then
        execute "sudo apt update && sudo apt install -y ca-certificates curl gnupg"
        execute "sudo mkdir -p /etc/apt/keyrings"

        if [[ -z "$OS_CODENAME" ]]; then
            error "Cannot determine Ubuntu/Debian codename from /etc/os-release."
            exit 1
        fi
        
        # Docker: Modern Signed-By approach
        execute "curl -fsSL https://download.docker.com/linux/$OS_ID/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg --yes"
        execute "echo \"deb [arch=\$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$OS_ID $OS_CODENAME stable\" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null"
        
        # GitHub CLI: Modern Signed-By approach
        execute "curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo gpg --dearmor -o /etc/apt/keyrings/githubcli-archive-keyring.gpg --yes"
        execute "echo \"deb [arch=\$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main\" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null"
        
        execute "sudo apt update"
    elif [[ "$PKG_MGR" == "dnf" ]]; then
        # GitHub CLI (Direct download for DNF5/Fedora 43 compatibility)
        execute "sudo curl -fsSL https://cli.github.com/packages/rpm/gh-cli.repo -o /etc/yum.repos.d/gh-cli.repo"

        # Azure CLI
        execute "sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc"
        execute "sudo tee /etc/yum.repos.d/azure-cli.repo <<EOF
[azure-cli]
name=Azure CLI
baseurl=https://packages.microsoft.com/yumrepos/azure-cli
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF"
    fi
}

# --- 4. MODULES: TOOL INSTALLERS ---
install_shell_tools() {
    if [[ "$SERVER_MODE" == "false" ]]; then
        info "Installing desktop shell..."
        if ! command -v zsh >/dev/null 2>&1; then
            if [[ "$PKG_MGR" == "apt" ]]; then
                execute "sudo apt install -y zsh"
            elif [[ "$PKG_MGR" == "dnf" ]]; then
                execute "sudo dnf install -y zsh"
            fi
        else
            info "Zsh already installed"
        fi

        # Oh My Zsh
        if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
            info "Installing Oh My Zsh..."
            execute "CHSH=no RUNZSH=no sh -c \"\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\""
        fi

        # Zsh Auto-switch logic
        if [[ -f "$HOME/.bashrc" ]] && ! grep -q "exec zsh" "$HOME/.bashrc"; then
            info "Configuring .bashrc to auto-switch to Zsh..."
            execute "echo -e '\n# Auto-switch to Zsh\nif [ -x /usr/bin/zsh ]; then\n  exec zsh\nfi' >> $HOME/.bashrc"
        fi
    else
        info "Skipping Zsh shell setup (Server Mode)"
    fi
}

install_runtimes() {
    info "Installing desktop runtimes..."

    if [[ "$PKG_MGR" == "dnf" ]]; then
        execute "sudo dnf install -y golang rust cargo"
    elif [[ "$PKG_MGR" == "apt" ]]; then
        execute "sudo apt install -y golang-go rustc cargo"
    fi

    if [[ ! -d "$HOME/.nvm" ]]; then
        info "Installing NVM..."
        execute "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/$NVM_VERSION/install.sh | bash"
    else
        info "NVM already installed"
    fi
}

install_containers() {
    if [[ "$PKG_MGR" == "apt" ]]; then
        info "Installing Docker suite..."
        execute "sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin"
    elif [[ "$PKG_MGR" == "dnf" ]]; then
        info "Skipping Docker installation on Fedora."
        return
    fi

    # Only enable/start if systemd is active (avoids errors in Docker containers)
    # Check if PID 1 is systemd without relying on the 'ps' command
    if [[ -f /proc/1/comm ]] && [[ "$(cat /proc/1/comm)" == "systemd" ]]; then
        execute "sudo systemctl enable --now docker"
    fi

    warn "Adding $USER to docker group..."
    execute "sudo usermod -aG docker $USER"
}

install_k8s() {
    info "Installing Kubernetes stack (K3s, Helm)..."
    # K3s (Self-updating installer)
    if ! command -v k3s >/dev/null 2>&1; then
        execute "curl -sfL https://get.k3s.io | sh -"
    fi
    # Helm (Self-updating installer)
    if ! command -v helm >/dev/null 2>&1; then
        execute "curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash"
    fi
}

# --- 5. FINALIZATION ---
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
    execute "git --git-dir=\"$dot_dir\" --work-tree=\"$HOME\" sparse-checkout init --no-cone"
    execute "(cd \"\$HOME\" && git --git-dir=\"$dot_dir\" --work-tree=\"\$HOME\" sparse-checkout set \"/.zshrc\" \"/.gitconfig\" \"/.gemini\")"

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

# --- 6. MAIN ORCHESTRATION ---
main() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run) DRY_RUN=true; shift ;;
            --server) SERVER_MODE=true; shift ;;
            *) error "Unknown option: $1"; exit 1 ;;
        esac
    done

    [[ "$DRY_RUN" == "true" ]] && info "🔍 RUNNING IN DRY-RUN MODE"
    [[ "$SERVER_MODE" == "true" ]] && info "🖥️ RUNNING IN SERVER MODE (Skipping desktop shell setup)"

    detect_os
    setup_repos
    install_shell_tools
    install_runtimes
    install_containers
    install_k8s
    setup_dotfiles

    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "\n${GREEN}Dry run completed successfully.${NC}"
        info "No packages, repositories, services, or dotfiles were changed."
        return
    fi

    echo -e "\n${GREEN}🎉 Installation is completed!${NC}"
    info "---------------------------------"
    info "🚀 Tool Verification:"
    [[ -x /usr/bin/az ]] || command -v az >/dev/null && info "  Azure CLI: $(az --version | head -n 1)"
    command -v docker >/dev/null && info "  Docker:    $(docker --version)"
    command -v tofu >/dev/null && info "  OpenTofu:  $(tofu --version | head -n 1)"
    command -v kubectl >/dev/null && info "  Kubectl:   $(kubectl version --client --short 2>/dev/null || kubectl version --client | head -n 1)"
    [[ -s "$HOME/.nvm/nvm.sh" ]] && source "$HOME/.nvm/nvm.sh" && info "  Node.js:   $(node --version)"
    info "---------------------------------"
    info "📝 Next Steps:"
    info "  ✔️ Run: 'reload-shell' to apply changes"
    info "  ✔️ Run: 'gh auth login' to enable GitHub Copilot"
}

main "$@"
