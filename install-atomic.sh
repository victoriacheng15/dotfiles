#!/usr/bin/env bash

# ==============================================================================
# 🚀 FEDORA ATOMIC DESKTOP BOOTSTRAP
# Provisions the 'workspace' Toolbox container.
# Run this on the host (not inside a container).
#
# Usage:
#   bash install-atomic.sh                   # provision workspace container
#   bash install-atomic.sh --name=workspace  # explicit container name
#   bash install-atomic.sh --dry-run         # preview without changes
# ==============================================================================

set -euo pipefail

export DRY_RUN=false
CONTAINER_NAME="workspace"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

execute() {
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${CYAN}[DRY-RUN]${NC} Would execute: $*"
    else
        eval "$@"
    fi
}

# --- GUARD: Must run on the host ---
guard_host() {
    if [[ -f /run/.containerenv ]]; then
        error "This script must be run on the Atomic host, not inside a container."
        exit 1
    fi
}

# Packages installed inside workspace via dnf
WORKSPACE_PACKAGES=(
    stow
    zsh
    gh
    jq
    yq
    azure-cli
    awscli2
    kubernetes-client
    weasyprint
    poppler-utils
)

# --- HELPERS ---
container_exists() {
    toolbox list --containers | awk '{print $2}' | grep -q "^${1}$"
}

create_container() {
    local name="$1"
    if container_exists "$name"; then
        info "$name container already exists. Skipping creation."
    else
        info "Creating $name container..."
        execute "toolbox create -c $name"
    fi
}

# --- SETUP WORKSPACE ---
setup_workspace() {
    local name="$1"
    info "Setting up $name container..."
    create_container "$name"

    info "Installing group packages inside $name..."
    for group in c-development development-tools editors; do
        info "  Installing group: $group..."
        execute "toolbox run -c $name -- sudo dnf group install -y $group"
    done

    info "Installing individual packages inside $name..."
    for pkg in "${WORKSPACE_PACKAGES[@]}"; do
        info "  Installing package: $pkg..."
        execute "toolbox run -c $name -- sudo dnf install -y $pkg"
    done

    # Oh My Zsh (non-interactive)
    execute "toolbox run -c $name -- bash -c \
        '[[ -d \$HOME/.oh-my-zsh ]] || CHSH=no RUNZSH=no sh -c \"\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\"'"

    # Powerlevel10k theme
    execute "toolbox run -c $name -- bash -c \
        '[[ -d \${ZSH_CUSTOM:-\$HOME/.oh-my-zsh/custom}/themes/powerlevel10k ]] || git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \${ZSH_CUSTOM:-\$HOME/.oh-my-zsh/custom}/themes/powerlevel10k'"

    # uv for Python tooling
    execute "toolbox run -c $name -- bash -c \
        'command -v uv || curl -LsSf https://astral.sh/uv/install.sh | sh'"

    # mise for toolchain management
    execute "toolbox run -c $name -- bash -c \
        'command -v mise || curl https://mise.run | sh'"

    # Global language runtimes via mise
    info "Installing global runtimes via mise (node@lts, go@latest)..."
    execute "toolbox run -c $name -- bash -c 'mise use -g node@lts go@latest'"
}

# --- LOCAL GIT CREDENTIALS ---
setup_git_credentials() {
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
}

# --- MAIN ---
main() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                export DRY_RUN=true
                shift
                ;;
            --name=*)
                CONTAINER_NAME="${1#--name=}"
                shift
                ;;
            *)
                error "Unknown option: $1. Valid flags: --name=<container-name>, --dry-run"
                exit 1
                ;;
        esac
    done

    guard_host

    [[ "$DRY_RUN" == "true" ]] && info "RUNNING IN DRY-RUN MODE (container: $CONTAINER_NAME)"

    setup_workspace "$CONTAINER_NAME"
    setup_git_credentials

    echo -e "\n${GREEN}Done. $CONTAINER_NAME container is ready.${NC}"
    info "Next steps:"
    info "  toolbox enter $CONTAINER_NAME"
}

main "$@"
