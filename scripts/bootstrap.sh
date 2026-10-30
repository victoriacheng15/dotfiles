#!/usr/bin/env bash
# ==============================================================================
# 🚀 WORKSTATION BOOTSTRAPPER
# ==============================================================================
# Prepares the system to run Ansible playbooks.
# Installs minimal system bridges, then provisions uv, ansible-core, and mise
# in user space without host system pollution.
#
# Usage:
#   bash scripts/bootstrap.sh            # standard execution
#   bash scripts/bootstrap.sh --dry-run  # preview actions
# ==============================================================================

set -euo pipefail

DRY_RUN=false
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

info()  { echo -e "${CYAN}[INFO]${NC} $*"; }
pass()  { echo -e "${GREEN}[✔]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

execute() {
  if [[ "$DRY_RUN" == "true" ]]; then
    echo -e "  ${CYAN}[DRY-RUN]${NC} Would execute: $*"
  else
    eval "$@"
  fi
}

ensure_path() {
  export PATH="$HOME/.local/bin:$PATH"
}

# --- 1. SYSTEM BRIDGES ---
install_system_bridges() {
  info "1. Checking OS-level prerequisite bridges..."

  if [[ ! -f /etc/os-release ]]; then
    error "/etc/os-release not found. Unsupported Linux distribution."
    exit 1
  fi

  # shellcheck disable=SC1091
  . /etc/os-release
  local os_id="${ID:-unknown}"

  case "$os_id" in
    fedora)
      local fedora_pkgs=()
      if ! rpm -q python3-libdnf5 >/dev/null 2>&1; then
        fedora_pkgs+=(python3-libdnf5)
      fi
      if ! command -v curl >/dev/null 2>&1; then
        fedora_pkgs+=(curl)
      fi

      if [[ ${#fedora_pkgs[@]} -gt 0 ]]; then
        info "Installing Fedora system bridges: ${fedora_pkgs[*]}..."
        execute "sudo dnf install -y ${fedora_pkgs[*]}"
      else
        pass "Fedora system bridges are already present."
      fi
      ;;

    ubuntu|debian|pop)
      local deb_pkgs=()
      if ! command -v curl >/dev/null 2>&1; then
        deb_pkgs+=(curl)
      fi
      if ! dpkg -s ca-certificates >/dev/null 2>&1; then
        deb_pkgs+=(ca-certificates)
      fi

      if [[ ${#deb_pkgs[@]} -gt 0 ]]; then
        info "Installing Ubuntu/Debian system bridges: ${deb_pkgs[*]}..."
        execute "sudo apt update && sudo apt install -y ${deb_pkgs[*]}"
      else
        pass "Ubuntu/Debian system bridges are already present."
      fi
      ;;

    *)
      warn "Unrecognized OS '$os_id'. Assuming prerequisite packages are installed manually."
      ;;
  esac
}

# --- 2. UV (PYTHON TOOLING LAYER) ---
install_uv() {
  info "2. Checking Python tool manager (uv)..."

  ensure_path
  if command -v uv >/dev/null 2>&1; then
    pass "uv is already installed: $(uv --version)"
  else
    info "Installing uv in user space..."
    execute "curl -LsSf https://astral.sh/uv/install.sh | sh"
    ensure_path
  fi
}

# --- 3. ANSIBLE-CORE VIA UV ---
install_ansible() {
  info "3. Checking Ansible (ansible-core)..."

  ensure_path
  if command -v ansible-playbook >/dev/null 2>&1; then
    pass "Ansible is already installed: $(ansible-playbook --version | head -n 1)"
  else
    info "Installing ansible-core in isolated user space via uv..."
    execute "uv tool install ansible-core"
    ensure_path
  fi
}

# --- 4. MISE (POLYGLOT RUNTIMES) ---
install_mise() {
  info "4. Checking polyglot runtime manager (mise)..."

  ensure_path
  if command -v mise >/dev/null 2>&1; then
    pass "mise is already installed: $(mise --version | head -n 1)"
  else
    info "Installing mise in user space..."
    execute "curl https://mise.run | sh"
    ensure_path
  fi
}

# --- MAIN ---
main() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run)
        DRY_RUN=true
        shift
        ;;
      -h|--help)
        echo "Usage: $(basename "$0") [--dry-run]"
        exit 0
        ;;
      *)
        error "Unknown option: $1"
        exit 1
        ;;
    esac
  done

  echo -e "${BOLD}${CYAN}======================================================================${NC}"
  echo -e "${BOLD}${CYAN}                   WORKSTATION BOOTSTRAP INITIALIZER                  ${NC}"
  echo -e "${BOLD}${CYAN}======================================================================${NC}"

  install_system_bridges
  install_uv
  install_ansible
  install_mise

  echo -e "\n${BOLD}${GREEN}✔ Bootstrap complete! Environment is primed for Ansible.${NC}\n"
  info "Next step (run the Ansible playbook):"
  echo -e "  ${BOLD}ANSIBLE_CONFIG=ansible/ansible.cfg ansible-playbook ansible/playbook.yml${NC}\n"
}

main "$@"
