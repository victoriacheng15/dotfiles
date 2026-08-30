#!/usr/bin/env bash

# ==============================================================================
# 🚀 DEV ENVIRONMENT BOOTSTRAP ORCHESTRATOR
# ==============================================================================
# Overhauled: August 30, 2026
# Features: Zsh, NVM, K3s, Helm, OpenTofu, K9s, jq, yq, and Bare Dotfiles Repo.
# ==============================================================================

set -euo pipefail

# Fedora package group reference:
# Copy/paste later if you want to install more Fedora groups manually.
# Fedora Desktop default:
# sudo dnf group install -y c-development container-management development-tools domain-client editors rpm-development-tools
#
# Fedora Server only:
# sudo dnf group install -y headless-management
#
# AI agent CLI reference (Antigravity & OpenAI Codex):
# Antigravity Reference: https://antigravity.google/docs/cli/reference
# OpenAI Codex Reference: https://github.com/openai/codex
#
# curl -fsSL https://antigravity.google/cli/install.sh | bash
# npm install -g @openai/codex
#
# K9s reference:
# https://github.com/derailed/k9s/releases

# --- 1. CONFIGURATION & LOGGING ---
export DRY_RUN=false
export SERVER_MODE=false
NVM_VERSION="v0.40.3"
OS_ID=""
OS_NAME=""
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

# --- 3. RUN OS-SPECIFIC SETUP SCRIPTS ---
run_os_setup() {
    if [[ "$PKG_MGR" == "apt" ]]; then
        info "Running Ubuntu-specific setup..."
        execute "bash setup-ubuntu.sh"
    elif [[ "$PKG_MGR" == "dnf" ]]; then
        info "Running Fedora-specific setup..."
        execute "bash setup-fedora.sh"
    fi
}

# --- 4. INSTALL COMMON SHELL TOOLS (OH MY ZSH & BASH SWITCH) ---
install_shell_tools() {
    if [[ "$SERVER_MODE" == "true" ]]; then
        info "Skipping Zsh shell setup (Server Mode)"
        return
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
}

# --- 5. INSTALL COMMON RUNTIMES (NVM) ---
install_runtimes() {
    if [[ ! -d "$HOME/.nvm" ]]; then
        info "Installing NVM..."
        execute "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/$NVM_VERSION/install.sh | bash"
    else
        info "NVM already installed"
    fi
}

# --- 6. INSTALL KUBERNETES STACK (K3s, HELM) ---
install_k8s() {
    info "Installing Kubernetes stack (K3s, Helm)..."
    # K3s
    if ! command -v k3s >/dev/null 2>&1; then
        execute "curl -sfL https://get.k3s.io | sh -"
    fi
    # Helm
    if ! command -v helm >/dev/null 2>&1; then
        execute "curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash"
    fi
}

# --- 7. INSTALL DEVOPS TOOLS (OPENTOFU, K9S, JQ, YQ) ---
install_devops_tools() {
    info "Installing DevOps tools..."

    # Install jq (on Fedora if not already installed by helper, since Ubuntu helper installs it)
    if ! command -v jq >/dev/null 2>&1 && [[ "$PKG_MGR" == "dnf" ]]; then
        execute "sudo dnf install -y jq"
    fi

    # Install OpenTofu
    if ! command -v tofu >/dev/null 2>&1; then
        info "Installing OpenTofu..."
        if [[ "$PKG_MGR" == "apt" ]]; then
            execute "curl --proto '=https' --tlsv1.2 -fsSL https://get.opentofu.org/install.sh | sh -s -- --install-method deb"
        elif [[ "$PKG_MGR" == "dnf" ]]; then
            execute "curl --proto '=https' --tlsv1.2 -fsSL https://get.opentofu.org/install.sh | sh -s -- --install-method rpm"
        fi
    else
        info "OpenTofu already installed"
    fi

    # Install K9s
    if ! command -v k9s >/dev/null 2>&1; then
        local k9s_dir="$HOME/.local/bin"
        execute "mkdir -p \"$k9s_dir\""
        local latest_ver
        latest_ver=$(curl -s https://api.github.com/repos/derailed/k9s/releases/latest | grep tag_name | cut -d '"' -f 4)
        info "Downloading K9s $latest_ver..."
        execute "curl -fsSL -o /tmp/k9s.tar.gz \"https://github.com/derailed/k9s/releases/download/${latest_ver}/k9s_Linux_amd64.tar.gz\""
        execute "tar -xzf /tmp/k9s.tar.gz -C /tmp"
        execute "mv /tmp/k9s \"$k9s_dir/k9s\""
        execute "chmod +x \"$k9s_dir/k9s\""
        execute "rm -f /tmp/k9s.tar.gz"
    else
        info "K9s already installed"
    fi

    # Install yq (on Ubuntu if not installed, Fedora helper installs it via DNF)
    if ! command -v yq >/dev/null 2>&1 && [[ "$PKG_MGR" == "apt" ]]; then
        info "Installing yq..."
        local yq_dir="$HOME/.local/bin"
        execute "mkdir -p \"$yq_dir\""
        local latest_yq
        latest_yq=$(curl -s https://api.github.com/repos/mikefarah/yq/releases/latest | grep tag_name | cut -d '"' -f 4)
        execute "curl -fsSL -o \"$yq_dir/yq\" \"https://github.com/mikefarah/yq/releases/download/${latest_yq}/yq_linux_amd64\""
        execute "chmod +x \"$yq_dir/yq\""
    fi
}

# --- 8. SETUP GIT BARE REPOSITORY DOTFILES ---
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

# --- 9. MAIN ORCHESTRATION ---
main() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run) export DRY_RUN=true; shift ;;
            --server) export SERVER_MODE=true; shift ;;
            *) error "Unknown option: $1"; exit 1 ;;
        esac
    done

    [[ "$DRY_RUN" == "true" ]] && info "🔍 RUNNING IN DRY-RUN MODE"
    [[ "$SERVER_MODE" == "true" ]] && info "🖥️ RUNNING IN SERVER MODE (Skipping desktop shell setup)"

    detect_os
    run_os_setup
    install_shell_tools
    install_runtimes
    install_k8s
    install_devops_tools
    setup_dotfiles

    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "\n${GREEN}Dry run completed successfully.${NC}"
        info "No packages, repositories, services, or dotfiles were changed."
        return
    fi

    echo -e "\n${GREEN}🎉 Installation is completed!${NC}"
    info "---------------------------------"
    info "🚀 Tool Verification:"
    command -v az >/dev/null && info "  Azure CLI: $(az --version | head -n 1)"
    command -v gh >/dev/null && info "  GitHub CLI: $(gh --version | head -n 1)"
    command -v docker >/dev/null && info "  Docker:    $(docker --version)"
    command -v tofu >/dev/null && info "  OpenTofu:  $(tofu --version | head -n 1)"
    command -v kubectl >/dev/null && info "  Kubectl:   $(kubectl version --client --short 2>/dev/null || kubectl version --client | head -n 1)"
    [[ -s "$HOME/.nvm/nvm.sh" ]] && source "$HOME/.nvm/nvm.sh" && command -v node >/dev/null && info "  Node.js:   $(node --version)"
    info "---------------------------------"
    info "📝 Next Steps:"
    info "  ✔️ Run: 'reload-shell' to apply changes"
    info "  ✔️ Run: 'gh auth login' to enable GitHub Copilot"
}

main "$@"
