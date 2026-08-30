#!/usr/bin/env bash

# ==============================================================================
# FEDORA-SPECIFIC INSTALLATION HELPER
# ==============================================================================

set -euo pipefail

DRY_RUN=${DRY_RUN:-false}
SERVER_MODE=${SERVER_MODE:-false}

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info() { echo -e "${GREEN}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }

execute() {
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${CYAN}[DRY-RUN]${NC} Would execute: $*"
    else
        eval "$@"
    fi
}

info "Setting up Fedora repositories..."
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

info "Installing Fedora packages..."
execute "sudo dnf install -y zsh golang rust cargo gh azure-cli yq"
