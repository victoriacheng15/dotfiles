#!/usr/bin/env bash
# ==============================================================================
# 🩺 POST-PROVISIONING HEALTH & ENVIRONMENT DOCTOR
# ==============================================================================
# Validates dotfiles symlinks, PATH resolution, Tier 1 system packages,
# Tier 2 uv environment, Tier 3 mise runtimes, and container sockets.
#
# Usage:
#   ./scripts/doctor.sh           # standard execution
#   ./scripts/doctor.sh --strict  # exit 1 on any warning
#   ./scripts/doctor.sh --help    # display usage
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

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
  1. GNU Stow Symlink Integrity (~/.zshrc, ~/.tmux.conf, ~/.local/bin/*, etc.)
  2. Shell & PATH Configuration (~/.local/bin, mise shims)
  3. Tier 1 System Package Binaries (git, zsh, tmux, stow, jq, yq, gh, etc.)
  4. Tier 2 Python Tooling (uv)
  5. Tier 3 Polyglot Runtimes (mise)
  6. Container Engine & Socket Readiness (podman / docker)
EOF
  exit 0
}

# --- 1. GNU STOW SYMLINK INTEGRITY ---
check_symlinks() {
  header "1. GNU Stow Symlink Integrity"

  local tracked_links=(
    "${HOME}/.zshrc:${DOTFILES_DIR}/home/.zshrc"
    "${HOME}/.tmux.conf:${DOTFILES_DIR}/home/.tmux.conf"
    "${HOME}/.gitconfig:${DOTFILES_DIR}/home/.gitconfig"
    "${HOME}/.p10k.zsh:${DOTFILES_DIR}/home/.p10k.zsh"
    "${HOME}/.config/mise/config.toml:${DOTFILES_DIR}/home/.config/mise/config.toml"
    "${HOME}/.local/bin/gh-issues:${DOTFILES_DIR}/home/.local/bin/gh-issues"
    "${HOME}/.local/bin/gh-setup:${DOTFILES_DIR}/home/.local/bin/gh-setup"
    "${HOME}/.local/bin/gh-status:${DOTFILES_DIR}/home/.local/bin/gh-status"
    "${HOME}/.local/bin/ppr:${DOTFILES_DIR}/home/.local/bin/ppr"
  )

  for entry in "${tracked_links[@]}"; do
    local link_path="${entry%%:*}"
    local expected_target="${entry##*:}"
    local rel_path="${link_path#$HOME/}"

    if [[ -L "$link_path" ]]; then
      local actual_target
      actual_target="$(readlink -f "$link_path")"
      if [[ "$actual_target" == "$expected_target" ]]; then
        pass "~/$rel_path correctly symlinked to repository"
      else
        warn "~/$rel_path symlinked to unexpected target: $actual_target (expected $expected_target)"
      fi
    elif [[ -e "$link_path" ]]; then
      warn "~/$rel_path exists as a regular file, not a symlink managed by stow"
    else
      fail "~/$rel_path is missing. Run 'make stow' or 'make restow' to restore."
    fi
  done
}

# --- 2. SHELL & PATH RESOLUTION ---
check_shell_and_path() {
  header "2. Shell & PATH Resolution"

  # Check current/configured shell
  local user_shell
  user_shell="$(grep "^${USER:-$(whoami)}:" /etc/passwd | cut -d: -f7 || echo "$SHELL")"
  if [[ "$user_shell" =~ zsh$ ]]; then
    pass "Default login shell is zsh ($user_shell)"
  else
    warn "Default login shell is $user_shell (recommended: zsh)"
  fi

  # Check PATH for ~/.local/bin
  if [[ ":$PATH:" == *":$HOME/.local/bin:"* ]]; then
    pass "\$HOME/.local/bin is present in current PATH"
  else
    warn "\$HOME/.local/bin not found in active PATH. Ensure your active shell sources ~/.zshrc."
  fi

  # Check PATH for mise shims
  local mise_data_dir="${XDG_DATA_HOME:-$HOME/.local/share}/mise"
  if [[ ":$PATH:" == *":$mise_data_dir/shims:"* ]] || command -v mise &>/dev/null; then
    pass "mise runtime shims or binary are reachable in PATH"
  else
    warn "mise shims not found in active PATH."
  fi
}

# --- 3. TIER 1 SYSTEM PACKAGES ---
check_tier1_packages() {
  header "3. Tier 1 System Package Binaries"

  local required_tools=("git" "zsh" "tmux" "stow" "jq" "yq" "gh")
  local optional_tools=("aws" "az" "weasyprint")

  for tool in "${required_tools[@]}"; do
    if command -v "$tool" &>/dev/null; then
      local tool_path
      tool_path="$(command -v "$tool")"
      pass "Found required tool '$tool' at $tool_path"
    else
      fail "Missing required tool '$tool'. Provision via 'make packages'."
    fi
  done

  for tool in "${optional_tools[@]}"; do
    if command -v "$tool" &>/dev/null; then
      local tool_path
      tool_path="$(command -v "$tool")"
      pass "Found optional tool '$tool' at $tool_path"
    else
      warn "Optional tool '$tool' is not installed."
    fi
  done
}

# --- 4. TIER 2 PYTHON TOOLING (UV) ---
check_tier2_uv() {
  header "4. Tier 2 Python Toolchain (uv)"

  if command -v uv &>/dev/null; then
    local uv_version
    uv_version="$(uv --version 2>/dev/null || echo "unknown")"
    pass "uv is installed: $uv_version"
  else
    fail "uv is not installed. Run 'make bootstrap' to install."
  fi
}

# --- 5. TIER 3 POLYGLOT RUNTIMES (MISE) ---
check_tier3_mise() {
  header "5. Tier 3 Polyglot Runtimes (mise)"

  if ! command -v mise &>/dev/null; then
    fail "mise is not installed. Run 'make bootstrap' to install."
    return
  fi

  local mise_version
  mise_version="$(mise --version 2>/dev/null || echo "unknown")"
  pass "mise is installed: $mise_version"

  local tool_count
  tool_count="$(mise ls 2>/dev/null | tail -n +2 | grep -v '^[[:space:]]*$' | wc -l || echo 0)"
  if [[ "$tool_count" -gt 0 ]]; then
    pass "mise is managing $tool_count installed runtime(s) / tool(s)"
  fi
}

# --- 6. CONTAINER ENGINE & SOCKETS ---
check_containers() {
  header "6. Container Engine & Sockets"

  if command -v podman &>/dev/null; then
    pass "podman is available: $(podman --version 2>/dev/null || echo 'podman')"

    local user_socket="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/podman/podman.sock"
    if [[ -S "$user_socket" ]]; then
      pass "Rootless Podman socket active at $user_socket"
    else
      warn "Rootless Podman socket not found at $user_socket. Enable via: systemctl --user enable --now podman.socket"
    fi
  elif command -v docker &>/dev/null; then
    pass "docker is available: $(docker --version 2>/dev/null || echo 'docker')"
  else
    warn "Neither podman nor docker detected in current environment."
  fi
}

# --- MAIN EXECUTION ---
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
  echo -e "${BOLD}${CYAN}            POST-PROVISIONING HEALTH & ENVIRONMENT DOCTOR             ${NC}"
  echo -e "${BOLD}${CYAN}======================================================================${NC}"

  check_symlinks
  check_shell_and_path
  check_tier1_packages
  check_tier2_uv
  check_tier3_mise
  check_containers

  header "Summary & Diagnostics"
  echo -e "  Passed:   ${GREEN}${PASS_COUNT}${NC}"
  echo -e "  Warnings: ${YELLOW}${WARN_COUNT}${NC}"
  echo -e "  Failures: ${RED}${FAIL_COUNT}${NC}"

  if [[ "$FAIL_COUNT" -gt 0 ]]; then
    echo -e "\n${RED}${BOLD}✘ Doctor detected ${FAIL_COUNT} critical failure(s).${NC}"
    echo -e "Review the failures above and run the suggested remediation steps.\n"
    exit 1
  elif [[ "$STRICT_MODE" == "true" && "$WARN_COUNT" -gt 0 ]]; then
    echo -e "\n${YELLOW}${BOLD}⚠ Strict mode enabled: ${WARN_COUNT} warning(s) detected.${NC}\n"
    exit 1
  else
    echo -e "\n${GREEN}${BOLD}✔ All systems healthy. Environment is fully provisioned and operational.${NC}\n"
    exit 0
  fi
}

main "$@"
