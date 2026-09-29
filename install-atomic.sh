#!/usr/bin/env bash

# ==============================================================================
# 🚀 FEDORA ATOMIC DESKTOP BOOTSTRAP
# Provisions cloud-dev and node-dev Toolbox containers.
# Run this on the host (not inside a container).
#
# Usage:
#   bash install-atomic.sh                   # provision both containers
#   bash install-atomic.sh --env=cloud       # cloud-dev only
#   bash install-atomic.sh --env=node        # node-dev only
#   bash install-atomic.sh --env=all         # explicit all (same as default)
#   bash install-atomic.sh --dry-run         # preview without changes
#   bash install-atomic.sh --env=cloud --dry-run
# ==============================================================================

set -euo pipefail

export DRY_RUN=false

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

# Packages installed inside cloud-dev via dnf
CLOUD_DEV_PACKAGES=(
    stow
    zsh
    gh
    jq
    yq
    azure-cli
    awscli2
    kubernetes-clients
)

# Packages installed inside node-dev via dnf
NODE_DEV_PACKAGES=(
    gcc-c++
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

# --- 1. CLOUD-DEV CONTAINER ---
setup_cloud_dev() {
    info "Setting up cloud-dev container..."
    create_container "cloud-dev"

    info "Installing group packages inside cloud-dev..."
    execute "toolbox run -c cloud-dev -- sudo dnf group install -y \
        c-development \
        development-tools \
        editors"

    info "Installing packages inside cloud-dev: ${CLOUD_DEV_PACKAGES[*]}"
    execute "toolbox run -c cloud-dev -- sudo dnf install -y ${CLOUD_DEV_PACKAGES[*]}"

    # Oh My Zsh (non-interactive)
    execute "toolbox run -c cloud-dev -- bash -c \
        '[[ -d \$HOME/.oh-my-zsh ]] || CHSH=no RUNZSH=no sh -c \"\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\"'"

    # uv for Python tooling
    execute "toolbox run -c cloud-dev -- bash -c \
        'command -v uv || curl -LsSf https://astral.sh/uv/install.sh | sh'"

    # mise for toolchain management
    execute "toolbox run -c cloud-dev -- bash -c \
        'command -v mise || curl https://mise.run | sh'"
}

# --- 2. NODE-DEV CONTAINER ---
setup_node_dev() {
    info "Setting up node-dev container..."
    create_container "node-dev"

    info "Installing build tools inside node-dev..."
    execute "toolbox run -c node-dev -- sudo dnf group install -y development-tools"
    execute "toolbox run -c node-dev -- sudo dnf install -y ${NODE_DEV_PACKAGES[*]}"

    info "Installing mise inside node-dev..."
    execute "toolbox run -c node-dev -- bash -c 'command -v mise || curl https://mise.run | sh'"

    info "Installing Node.js LTS and pnpm via mise..."
    execute "toolbox run -c node-dev -- bash -c 'mise use -g node@lts && mise use -g pnpm@latest'"
}

# --- MAIN ---
main() {
    local env="all"

    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                export DRY_RUN=true
                shift
                ;;
            --env=*)
                env="${1#--env=}"
                shift
                ;;
            *)
                error "Unknown option: $1. Valid flags: --env=cloud|node|all, --dry-run"
                exit 1
                ;;
        esac
    done

    case "$env" in
        cloud|node|all) ;;
        *) error "Invalid --env value: '$env'. Expected cloud, node, or all."; exit 1 ;;
    esac

    guard_host

    [[ "$DRY_RUN" == "true" ]] && info "RUNNING IN DRY-RUN MODE (env: $env)"

    [[ "$env" == "cloud" || "$env" == "all" ]] && setup_cloud_dev
    [[ "$env" == "node"  || "$env" == "all" ]] && setup_node_dev

    echo -e "\n${GREEN}Done.${NC}"
    info "Next steps:"
    [[ "$env" == "cloud" || "$env" == "all" ]] && info "  toolbox enter cloud-dev"
    [[ "$env" == "node"  || "$env" == "all" ]] && info "  toolbox enter node-dev"
}

main "$@"
