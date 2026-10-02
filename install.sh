#!/usr/bin/env bash

# ==============================================================================
# 🚀 DEV ENVIRONMENT BOOTSTRAP ORCHESTRATOR
# ==============================================================================

set -euo pipefail

# --- 1. CONFIGURATION & CENTRALIZED PACKAGE LISTS ---
export DRY_RUN=false
TARGET_OS="fedora"

# Centralized package definitions
FEDORA_GROUPS=(
    c-development
    development-tools
    editors
)

FEDORA_PACKAGES=(
    stow
    zsh
    gh
    jq
    yq
    azure-cli
    awscli2
    weasyprint
)

# Todo check for ubuntu packages later
UBUNTU_GROUPS=(
    build-essential
)

UBUNTU_PACKAGES=(
    stow
    zsh
    gh
    azure-cli
    jq
    yq
    weasyprint
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
        azure-cli) command -v az >/dev/null 2>&1 ;;
        *)         command -v "$pkg" >/dev/null 2>&1 ;;
    esac
}

install_mise() {
    if command -v mise >/dev/null 2>&1; then
        info "mise is already installed."
    else
        info "Installing mise..."
        execute "curl https://mise.run | sh"
    fi
}

install_packages() {
    local pkgs=()
    local missing=()

    if [[ "$TARGET_OS" == "fedora" ]]; then
        info "Installing Fedora package groups..."
        for group in "${FEDORA_GROUPS[@]}"; do
            info "  Installing group: $group..."
            execute "sudo dnf group install -y $group"
        done
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

# --- 4. DOTFILE SYMLINKS (GNU STOW) ---
setup_symlinks() {
    info "Symlinking dotfiles via GNU Stow..."

    local repo_dir
    repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    if ! command -v stow &>/dev/null; then
        warn "GNU Stow is not installed. Skipping dotfile symlinks."
        return
    fi

    # Backup any existing regular files that stow would conflict with
    for f in .zshrc .gitconfig .gitignore_global .p10k.zsh; do
        if [[ -f "$HOME/$f" && ! -L "$HOME/$f" ]]; then
            warn "Existing file $HOME/$f found. Backing up to $f.backup"
            execute "mv \"$HOME/$f\" \"$HOME/$f.backup\""
        fi
    done

    # -R (restow): prunes obsolete links before creating new ones
    # -t: target directory for symlinks
    # -d: source directory containing the stow package
    execute "stow -R -t \"$HOME\" -d \"$repo_dir\" home"
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
    install_mise
    install_shell_tools
    setup_symlinks

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
    command -v mise >/dev/null && info "  mise:      $(mise --version | head -n 1)"
    command -v kubectl >/dev/null && info "  Kubectl:   $(kubectl version --client --short 2>/dev/null || kubectl version --client | head -n 1)"
    info "---------------------------------"
    info "📝 Next Steps:"
    info "  ✔️ Run: 'reload-shell' to apply changes"
    info "  ✔️ Run: 'gh auth login' to enable GitHub Copilot"
}

main "$@"
