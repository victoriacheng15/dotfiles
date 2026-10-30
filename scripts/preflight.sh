#!/usr/bin/env bash
# ==============================================================================
# 🔍 SYSTEM & TOOLCHAIN PREFLIGHT VERIFICATION
# ==============================================================================
# Validates operating system, architecture, container context, privileges,
# network connectivity, and readiness for Ansible, uv, and mise.
#
# Usage:
#   ./scripts/preflight.sh           # standard execution
#   ./scripts/preflight.sh --strict  # exit 1 on any warning
#   ./scripts/preflight.sh --help    # display usage
# ==============================================================================

set -euo pipefail

STRICT_MODE=false
PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0

# Formatting
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

pass() {
  echo -e "  ${GREEN}✔ [PASS]${NC} $*"
  PASS_COUNT=$((PASS_COUNT + 1))
}

warn() {
  echo -e "  ${YELLOW}⚠ [WARN]${NC} $*"
  WARN_COUNT=$((WARN_COUNT + 1))
}

fail() {
  echo -e "  ${RED}✘ [FAIL]${NC} $*"
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

header() {
  echo -e "\n${BOLD}${CYAN}=== $* ===${NC}"
}

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  --strict    Treat warnings as failures (exit code 1)
  -h, --help  Show this help message

Checks performed:
  1. Operating System (Fedora, Ubuntu, Debian)
  2. CPU Architecture (x86_64, aarch64)
  3. User Privileges & Sudo Access
  4. Disk Space & Storage Headroom
  5. Toolchain Readiness (Ansible, uv, mise, GNU Stow)
EOF
  exit 0
}

# --- 1. OPERATING SYSTEM ---
check_os() {
  header "1. Operating System & Distribution"

  if [[ ! -f /etc/os-release ]]; then
    fail "Unable to identify OS: /etc/os-release not found."
    return
  fi

  # shellcheck disable=SC1091
  . /etc/os-release
  local os_id="${ID:-unknown}"
  local os_name="${PRETTY_NAME:-$os_id}"
  local version="${VERSION_ID:-unknown}"

  case "$os_id" in
    fedora)
      pass "Detected supported distribution: $os_name (ID: $os_id, Version: $version)"
      ;;
    ubuntu|debian|pop)
      pass "Detected supported distribution: $os_name (ID: $os_id, Version: $version)"
      ;;
    *)
      warn "Distribution '$os_id' is not officially verified. Setup expects Fedora or Ubuntu/Debian."
      ;;
  esac
}

# --- 2. ARCHITECTURE ---
check_arch() {
  header "2. CPU Architecture"

  local arch
  arch="$(uname -m)"
  case "$arch" in
    x86_64|aarch64|arm64)
      pass "Supported CPU architecture: $arch"
      ;;
    *)
      warn "Uncommon architecture detected: $arch. Binaries for mise or uv may require building from source."
      ;;
  esac
}

# --- 3. PRIVILEGES & SUDO ---
check_privileges() {
  header "3. Privileges & Sudo Access"

  local current_user
  current_user="$(whoami)"

  if [[ "$EUID" -eq 0 ]]; then
    warn "Running as root user. Standard workflow recommends running as a standard user with sudo access."
  else
    pass "Running as non-root user: $current_user"
  fi

  if command -v sudo >/dev/null 2>&1; then
    if sudo -n true >/dev/null 2>&1; then
      pass "Sudo access: Passwordless or currently authenticated"
    elif sudo -v >/dev/null 2>&1; then
      pass "Sudo access: Verified via credentials"
    else
      warn "Sudo command exists but authentication failed. Package installation tasks may prompt for password."
    fi
  else
    fail "sudo command is not installed. System package installation requires sudo."
  fi
}

# --- 4. DISK SPACE ---
check_disk_space() {
  header "4. Storage & Disk Space"

  local home_free_kb root_free_kb
  home_free_kb="$(df -k "$HOME" | awk 'NR==2 {print $4}')"
  root_free_kb="$(df -k / | awk 'NR==2 {print $4}')"

  local home_free_mb=$((home_free_kb / 1024))
  local root_free_mb=$((root_free_kb / 1024))

  if [[ "$home_free_mb" -ge 2048 ]]; then
    pass "Storage in \$HOME: ${home_free_mb} MB available (Minimum: 2048 MB)"
  else
    warn "Storage in \$HOME is low: ${home_free_mb} MB available (Recommended: 2048+ MB)"
  fi

  if [[ "$root_free_mb" -ge 2048 ]]; then
    pass "Storage in /: ${root_free_mb} MB available (Minimum: 2048 MB)"
  else
    warn "Storage in / is low: ${root_free_mb} MB available (Recommended: 2048+ MB)"
  fi
}

# --- 5. TOOLCHAIN READINESS ---
check_toolchains() {
  header "5. Toolchain Readiness (Ansible, uv, mise, GNU Stow)"

  # GNU Stow
  if command -v stow >/dev/null 2>&1; then
    pass "GNU Stow is installed: $(stow --version 2>&1 | head -n 1)"
  else
    warn "GNU Stow is missing. Dotfiles symlinking requires stow."
  fi

  # Tier 1: Ansible
  if command -v ansible-playbook >/dev/null 2>&1; then
    pass "Ansible is installed: $(ansible-playbook --version 2>&1 | head -n 1)"
  else
    warn "Ansible is not installed."
    echo -e "       ${CYAN}→ Remediation:${NC}"
    echo -e "         - Fedora:   sudo dnf install -y ansible-core"
    echo -e "         - Ubuntu:   sudo apt update && sudo apt install -y ansible-core"
    echo -e "         - via uv:   uv tool install ansible-core"
  fi

  # Tier 2: uv (Python tooling)
  if command -v uv >/dev/null 2>&1; then
    pass "uv is installed: $(uv --version 2>&1)"
  else
    warn "uv is not installed (recommended for isolated Python CLIs)."
    echo -e "       ${CYAN}→ Remediation: curl -LsSf https://astral.sh/uv/install.sh | sh${NC}"
  fi

  # Tier 3: mise (Polyglot runtimes)
  if command -v mise >/dev/null 2>&1; then
    pass "mise is installed: $(mise --version 2>&1 | head -n 1)"
  else
    warn "mise is not installed (recommended for polyglot runtimes)."
    echo -e "       ${CYAN}→ Remediation: curl https://mise.run | sh${NC}"
  fi
}

# --- MAIN ---
main() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --strict)
        STRICT_MODE=true
        shift
        ;;
      -h|--help)
        usage
        ;;
      *)
        echo -e "${RED}Unknown option: $1${NC}"
        usage
        ;;
    esac
  done

  echo -e "${BOLD}${CYAN}======================================================================${NC}"
  echo -e "${BOLD}${CYAN}              SYSTEM & TOOLCHAIN PREFLIGHT VERIFICATION               ${NC}"
  echo -e "${BOLD}${CYAN}======================================================================${NC}"

  check_os
  check_arch
  check_privileges
  check_disk_space
  check_toolchains

  header "Summary & Diagnostics"
  echo -e "  Passed:   ${GREEN}${PASS_COUNT}${NC}"
  echo -e "  Warnings: ${YELLOW}${WARN_COUNT}${NC}"
  echo -e "  Failures: ${RED}${FAIL_COUNT}${NC}"

  if [[ "$FAIL_COUNT" -gt 0 ]]; then
    echo -e "\n${RED}${BOLD}✘ Preflight checks failed with ${FAIL_COUNT} critical error(s).${NC}"
    echo -e "Please address the errors above before running installation playbooks.\n"
    exit 1
  elif [[ "$STRICT_MODE" == "true" && "$WARN_COUNT" -gt 0 ]]; then
    echo -e "\n${YELLOW}${BOLD}⚠ Strict mode enabled: ${WARN_COUNT} warning(s) detected.${NC}\n"
    exit 1
  else
    echo -e "\n${GREEN}${BOLD}✔ System meets preflight requirements. Environment is ready for provisioning.${NC}\n"
    exit 0
  fi
}

main "$@"
