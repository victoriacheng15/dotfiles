#!/usr/bin/env bash

# ==============================================================================
# 🚀 PROFESSIONAL DEV ENVIRONMENT SETUP (UBUNTU & FEDORA)
# ==============================================================================
# Overhauled: Monday, February 16, 2026
# Targets: Ubuntu/Debian & Fedora
# Features: Zsh, Docker, OpenTofu, K3s, K9s, Helm, Nix, NVM, and modern CLI tools.
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

set -eo pipefail # Exit on error, handle pipe failures

# --- 1. ENGINE: CONFIGURATION & LOGGING ---
DRY_RUN=false
SERVER_MODE=false
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info() { echo -e "${GREEN}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "\033[0;31m[ERROR]\033[0m $*" >&2; }

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
        OS_LIKE="${ID_LIKE:-$ID}"
        info "Detected OS: $NAME ($OS_ID)"
    else
        error "Cannot detect OS. /etc/os-release missing."
        exit 1
    fi

    if command -v apt >/dev/null 2>&1; then
        PKG_MGR="apt"
        INSTALL_CMD="sudo apt install -y"
        UPDATE_CMD="sudo apt update"
    elif command -v dnf >/dev/null 2>&1; then
        PKG_MGR="dnf"
        INSTALL_CMD="sudo dnf install -y"
        UPDATE_CMD="sudo dnf check-update || true"
    else
        error "Unsupported package manager (need apt or dnf)."
        exit 1
    fi
}

pkg_install() {
    local tool=$1
    local pkg_name=$tool
    
    # 1. Map Package Names (where package != tool name)
    case "$tool" in
        fd) pkg_name="fd-find" ;;
        go) [[ "$PKG_MGR" == "apt" ]] && pkg_name="golang-go" || pkg_name="golang" ;;
    esac

    # 2. Smart Binary Check (handles Ubuntu-specific suffixes like 'fdfind' or 'batcat')
    local is_installed=false
    if command -v "$tool" >/dev/null 2>&1; then
        is_installed=true
    elif [[ "$tool" == "fd" ]] && command -v "fdfind" >/dev/null 2>&1; then
        is_installed=true
    elif [[ "$tool" == "bat" ]] && command -v "batcat" >/dev/null 2>&1; then
        is_installed=true
    fi

    if [[ "$is_installed" == "false" ]]; then
        info "Installing $tool..."
        execute "$INSTALL_CMD $pkg_name"
    else
        info "✔️ $tool already installed"
    fi
}

# --- 3. REPOSITORIES & CORE BUILD TOOLS ---
setup_repos() {
    info "Setting up external repositories..."
    if [[ "$PKG_MGR" == "apt" ]]; then
        execute "sudo apt update && sudo apt install -y ca-certificates curl gnupg"
        # Docker
        execute "sudo install -m 0755 -d /etc/apt/keyrings"
        execute "curl -fsSL https://download.docker.com/linux/$OS_ID/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg --yes"
        execute "echo \"deb [arch=\$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$OS_ID \$(lsb_release -cs) stable\" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null"
        # GitHub CLI
        execute "curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg"
        execute "echo \"deb [arch=\$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main\" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null"
        execute "sudo apt update"
    elif [[ "$PKG_MGR" == "dnf" ]]; then
        # Docker
        execute "sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo"
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
    info "Installing modern shell utilities..."
    local tools=(jq ripgrep bat eza btop direnv gh stow)
    for t in "${tools[@]}"; do pkg_install "$t"; done

    if [[ "$SERVER_MODE" == "false" ]]; then
        pkg_install "zsh"
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
    # Nix
    if ! command -v nix >/dev/null 2>&1; then
        info "Installing Nix..."
        execute "curl -L https://nixos.org/nix/install | sh -s -- --daemon"
    fi
    # NVM (Dynamic Version Lookup)
    if [[ ! -d "$HOME/.nvm" ]]; then
        info "Fetching latest NVM version..."
        local latest_nvm="v0.39.7" # Default fallback
        if command -v jq >/dev/null 2>&1 && [[ "$DRY_RUN" == "false" ]]; then
            latest_nvm=$(curl -s https://api.github.com/repos/nvm-sh/nvm/releases/latest | jq -r .tag_name)
        fi
        info "Installing NVM $latest_nvm..."
        execute "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/$latest_nvm/install.sh | bash"
        
        # Automate Node LTS and Gemini CLI
        info "Installing Node.js LTS and Gemini CLI..."
        execute "source \$HOME/.nvm/nvm.sh && nvm install --lts && npm install -g @google/gemini-cli"
    fi
    
    # OpenTofu (Official Multi-OS Installer)
    if ! command -v tofu >/dev/null 2>&1; then
        info "Installing OpenTofu..."
        execute "curl --proto '=https' --tlsv1.2 -fsSL https://get.opentofu.org/install-opentofu.sh | sh -s -- --install-method standalone"
    fi

    # Go (Native Package)
    pkg_install "go"

    # FUTURE ROADMAP: Placeholder for Rust
    # info "For Go (Golang): https://go.dev/doc/install"
    # info "For Rust (rustup): curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
}

install_containers() {
    info "Installing Docker suite..."
    if [[ "$PKG_MGR" == "apt" ]]; then
        execute "sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin"
    else
        execute "sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin"
        # Only enable/start if systemd is active (avoids errors in Docker containers)
        # Check if PID 1 is systemd without relying on the 'ps' command
        if [[ -f /proc/1/comm ]] && [[ "$(cat /proc/1/comm)" == "systemd" ]]; then
            execute "sudo systemctl enable --now docker"
        fi
    fi
    warn "Adding $USER to docker group..."
    execute "sudo usermod -aG docker $USER"
}

install_k8s() {
    info "Installing Kubernetes stack (K3s, K9s, Helm)..."
    # K3s (Self-updating installer)
    if ! command -v k3s >/dev/null 2>&1; then
        execute "curl -sfL https://get.k3s.io | sh -"
    fi
    # Helm (Self-updating installer)
    if ! command -v helm >/dev/null 2>&1; then
        execute "curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash"
    fi
    # K9s (Dynamic Binary Fetch)
    if ! command -v k9s >/dev/null 2>&1; then
        info "Fetching latest K9s binary..."
        local k9s_url="https://github.com/derailed/k9s/releases/latest/download/k9s_Linux_amd64.tar.gz" # Default fallback
        if command -v jq >/dev/null 2>&1 && [[ "$DRY_RUN" == "false" ]]; then
            k9s_url=$(curl -s https://api.github.com/repos/derailed/k9s/releases/latest | jq -r '.assets[] | select(.name | contains("Linux_amd64.tar.gz")) | .browser_download_url')
        fi
        execute "curl -L $k9s_url | tar xz && sudo mv k9s /usr/local/bin/ && rm LICENSE README.md"
    fi
}

install_ai_extensions() {
    info "Installing GitHub Copilot CLI extension..."
    # Note: Requires gh auth login to be functional
    if command -v gh >/dev/null 2>&1; then
        execute "gh extension install github/gh-copilot || true"
    fi
}

# --- 5. FINALIZATION ---
setup_symlinks() {
    info "Symlinking dotfiles with GNU Stow..."
    
    # Stow fails if the target exists and is not a symlink.
    # We backup existing regular files to ensure a clean Stow operation.
    for f in .zshrc .gitconfig; do
        if [[ -f "$HOME/$f" && ! -L "$HOME/$f" ]]; then
            warn "Existing file $HOME/$f found. Backing up to $f.backup"
            execute "mv \"$HOME/$f\" \"$HOME/$f.backup\""
        fi
    done

    # -R (restow): Prunes obsolete links and creates new ones.
    # -t (target): Directs symlinks to the home directory.
    # --ignore: Prevents metadata and scripts from being symlinked.
    execute "stow -R -t \"$HOME\" --ignore='setup.sh|README.md' ."
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
    install_ai_extensions
    setup_symlinks

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
    info "  ✔️ Run: 'k9s' to manage your K3s cluster"
}

main "$@"
