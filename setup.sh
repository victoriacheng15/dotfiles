#!/usr/bin/env bash

# ==============================================================================
# 🚀 DEV ENVIRONMENT BOOTSTRAP ORCHESTRATOR
# ==============================================================================

set -euo pipefail

# --- 1. CONFIGURATION & CENTRALIZED PACKAGE LISTS ---
export DRY_RUN=false
TARGET_OS="fedora"

# Centralized package definitions
FEDORA_PACKAGES=(
    zsh
    golang
    rust
    cargo
    gh
    azure-cli
    jq
    yq
    helm
    opentofu
    awscli2
)

# Todo check for ubuntu packages later
UBUNTU_PACKAGES=(
    zsh
    golang-go
    rustc
    cargo
    gh
    azure-cli
    jq
    yq
)

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

# --- 2. PACKAGE INSTALLATION ---
is_pkg_installed() {
    local pkg="$1"
    case "$pkg" in
        awscli2)   command -v aws >/dev/null 2>&1 ;;
        opentofu)  command -v tofu >/dev/null 2>&1 || command -v opentofu >/dev/null 2>&1 ;;
        golang*)   command -v go >/dev/null 2>&1 ;;
        rust*)     command -v rustc >/dev/null 2>&1 ;;
        azure-cli) command -v az >/dev/null 2>&1 ;;
        *)         command -v "$pkg" >/dev/null 2>&1 ;;
    esac
}

install_packages() {
    local pkgs=()
    local missing=()

    if [[ "$TARGET_OS" == "fedora" ]]; then
        pkgs=("${FEDORA_PACKAGES[@]}")
    elif [[ "$TARGET_OS" == "ubuntu" ]]; then
        pkgs=("${UBUNTU_PACKAGES[@]}")
    fi

    info "Checking required packages for $TARGET_OS..."
    for pkg in "${pkgs[@]}"; do
        if is_pkg_installed "$pkg"; then
            info "  $pkg is already installed."
        else
            missing+=("$pkg")
        fi
    done

    if [[ ${#missing[@]} -eq 0 ]]; then
        info "All required packages are already installed."
    else
        info "Installing missing packages via package manager: ${missing[*]}..."
        if [[ "$TARGET_OS" == "fedora" ]]; then
            execute "sudo dnf install -y ${missing[*]}"
        elif [[ "$TARGET_OS" == "ubuntu" ]]; then
            execute "sudo apt update && sudo apt install -y ${missing[*]}"
        fi
    fi

    # Report any packages that still could not be installed via package manager
    local still_missing=()
    for pkg in "${pkgs[@]}"; do
        if ! is_pkg_installed "$pkg"; then
            still_missing+=("$pkg")
        fi
    done

    if [[ ${#still_missing[@]} -gt 0 ]]; then
        echo ""
        warn "The following packages are not installed via $TARGET_OS package manager:"
        for pkg in "${still_missing[@]}"; do
            echo -e "  - ${YELLOW}$pkg${NC} (please install manually)"
        done
        echo ""
    fi
}

# --- 3. SHELL TOOLS (OH MY ZSH & BASH AUTO-SWITCH) ---
install_shell_tools() {
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

# --- 4. GIT BARE REPOSITORY DOTFILES ---
setup_dotfiles() {
    info "Setting up Git bare repository for dotfiles..."

    # Configure local Git credentials (ignored by main repository)
    local local_gitconfig="$HOME/.gitconfig.local"
    if [[ ! -f "$local_gitconfig" ]]; then
        if [[ "$DRY_RUN" == "true" ]]; then
            info "[DRY-RUN] Would configure local Git credentials in $local_gitconfig"
        elif [ -t 0 ]; then
            info "Setting up local Git credentials (these will not be pushed to GitHub)..."
            read -p "Enter your Git commit name (e.g. John Doe): " git_name
            read -p "Enter your Git commit email (e.g. john@example.com): " git_email
            cat <<EOF > "$local_gitconfig"
[user]
    name = $git_name
    email = $git_email
EOF
            info "Created $local_gitconfig successfully."
        else
            warn "Non-interactive shell. Creating empty $local_gitconfig. Configure it manually later."
            cat <<EOF > "$local_gitconfig"
[user]
    name = your_name
    email = your_email
EOF
        fi
    fi

    local dot_dir="$HOME/.dotfiles"

    if [[ ! -d "$dot_dir" ]]; then
        info "Initializing bare repository at $dot_dir..."
        execute "git clone --bare . \"$dot_dir\""
    else
        info "Bare repository already exists at $dot_dir. Updating configuration..."
        execute "git --git-dir=\"$dot_dir\" remote set-url origin \".\" 2>/dev/null || true"
        execute "git --git-dir=\"$dot_dir\" fetch origin main:main 2>/dev/null || true"
    fi

    # Configure local bare repository
    execute "git --git-dir=\"$dot_dir\" --work-tree=\"$HOME\" config --local status.showUntrackedFiles no"

    # Enable sparse-checkout to keep home directory clean
    info "Configuring sparse-checkout to keep home directory clean..."
    execute "git --git-dir=\"$dot_dir\" --work-tree=\"$HOME\" sparse-checkout init --no-cone"
    execute "(cd \"\$HOME\" && git --git-dir=\"$dot_dir\" --work-tree=\"\$HOME\" sparse-checkout set \"/.zshrc\" \"/.gitconfig\" \"/.gemini\" \"/.gitignore_global\" \"/.p10k.zsh\")"

    # Backup existing non-symlink config files if they differ
    for f in .zshrc .gitconfig .gitignore_global .p10k.zsh; do
        if [[ -f "$HOME/$f" && ! -L "$HOME/$f" ]]; then
            warn "Existing file $HOME/$f found. Backing up to $f.backup"
            execute "mv \"$HOME/$f\" \"$HOME/$f.backup\""
        fi
    done

    # Checkout the files into the home directory
    info "Checking out dotfiles from bare repository..."
    execute "git --git-dir=\"$dot_dir\" --work-tree=\"$HOME\" checkout -f"
}

# --- 5. MAIN ORCHESTRATION ---
main() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --os)
                if [[ $# -lt 2 ]]; then
                    error "Missing argument for --os. Expected 'fedora' or 'ubuntu'."
                    exit 1
                fi
                TARGET_OS="$2"
                shift 2
                ;;
            --dry-run)
                export DRY_RUN=true
                shift
                ;;
            *)
                error "Unknown option: $1. Valid flags: --os <fedora|ubuntu>, --dry-run"
                exit 1
                ;;
        esac
    done

    case "$TARGET_OS" in
        fedora|ubuntu) ;;
        *) error "Unsupported OS: '$TARGET_OS'. Expected 'fedora' or 'ubuntu'." ; exit 1 ;;
    esac

    [[ "$DRY_RUN" == "true" ]] && info "🔍 RUNNING IN DRY-RUN MODE (OS: $TARGET_OS)"

    install_packages
    install_shell_tools
    setup_dotfiles

    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "\n${GREEN}Dry run completed successfully.${NC}"
        info "No packages, repositories, services, or dotfiles were changed."
        return
    fi

    echo -e "\n${GREEN}🎉 Installation is completed!${NC}"
    info "---------------------------------"
    info "🚀 Tool Verification:"
    command -v aws >/dev/null && info "  AWS CLI:   $(aws --version | head -n 1)"
    command -v az >/dev/null && info "  Azure CLI: $(az --version | head -n 1)"
    command -v gh >/dev/null && info "  GitHub CLI: $(gh --version | head -n 1)"
    command -v docker >/dev/null && info "  Docker:    $(docker --version)"
    command -v tofu >/dev/null && info "  OpenTofu:  $(tofu --version | head -n 1)"
    command -v kubectl >/dev/null && info "  Kubectl:   $(kubectl version --client --short 2>/dev/null || kubectl version --client | head -n 1)"
    info "---------------------------------"
    info "📝 Next Steps:"
    info "  ✔️ Run: 'reload-shell' to apply changes"
    info "  ✔️ Run: 'gh auth login' to enable GitHub Copilot"
}

main "$@"
