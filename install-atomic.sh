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
    kubernetes-clients
    weasyprint
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
    execute "toolbox run -c $name -- sudo dnf group install -y \
        c-development \
        development-tools \
        editors"

    info "Installing packages inside $name: ${WORKSPACE_PACKAGES[*]}"
    execute "toolbox run -c $name -- sudo dnf install -y ${WORKSPACE_PACKAGES[*]}"

    # Oh My Zsh (non-interactive)
    execute "toolbox run -c $name -- bash -c \
        '[[ -d \$HOME/.oh-my-zsh ]] || CHSH=no RUNZSH=no sh -c \"\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\"'"

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

    echo -e "\n${GREEN}Done. $CONTAINER_NAME container is ready.${NC}"
    info "Next steps:"
    info "  toolbox enter $CONTAINER_NAME"
}

main "$@"
