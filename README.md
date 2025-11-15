# Dotfiles

This repository contains a simple development environment bootstrap script (`setup.sh`) and example dotfiles.

Overview of `setup.sh`

- Detects the OS package manager (apt or dnf) and runs a system update/upgrade.
- Installs the following core tools and utilities using your package manager:
  - Nix (multi-user installer) — used for per-project tooling via `shell.nix`.
  - Zsh and Oh My Zsh
  - Docker (daemon + CLI; installed via official Docker repo)
  - GitHub CLI (`gh`) and `jq` (system-managed)
  - Azure CLI (`az`) via the official Microsoft repository
