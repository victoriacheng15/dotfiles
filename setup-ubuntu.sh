#!/usr/bin/env bash

# ==============================================================================
# UBUNTU-SPECIFIC INSTALLATION HELPER
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
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

execute() {
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${CYAN}[DRY-RUN]${NC} Would execute: $*"
    else
        eval "$@"
    fi
}

if [[ ! -f /etc/os-release ]]; then
    error "Cannot detect OS. /etc/os-release missing."
    exit 1
fi

. /etc/os-release
OS_ID="$ID"
OS_CODENAME="${VERSION_CODENAME:-}"

info "Setting up Ubuntu repositories..."
execute "sudo apt update && sudo apt install -y ca-certificates curl gnupg"
execute "sudo mkdir -p /etc/apt/keyrings"
execute "curl -fsSL https://download.docker.com/linux/$OS_ID/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg --yes"
execute "echo \"deb [arch=\$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$OS_ID $OS_CODENAME stable\" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null"
execute "curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo gpg --dearmor -o /etc/apt/keyrings/githubcli-archive-keyring.gpg --yes"
execute "echo \"deb [arch=\$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main\" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null"
execute "sudo apt update"

info "Installing Ubuntu packages..."
if [[ "$SERVER_MODE" == "true" ]]; then
    execute "sudo apt install -y zsh golang-go rustc cargo gh jq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin"
else
    execute "sudo apt install -y zsh golang-go rustc cargo gh azure-cli jq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin"
fi

# Configure Docker service
if [[ -f /proc/1/comm ]] && [[ "$(cat /proc/1/comm)" == "systemd" ]]; then
    execute "sudo systemctl enable --now docker"
fi

warn "Adding $USER to docker group..."
execute "sudo usermod -aG docker $USER"
