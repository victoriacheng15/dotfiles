# Dotfiles

This repository contains a simple development environment bootstrap script (`setup.sh`) and example dotfiles.

Overview of `setup.sh`

- Detects the OS package manager (apt or dnf) and runs a system update/upgrade.
- Installs the following core tools and utilities (in order):
  - Nix (multi-user installer) — used for per-project tooling via `shell.nix`
  - Zsh and Oh My Zsh
  - Docker (daemon + CLI; installed via official Docker repo)
  - GitHub CLI (`gh`)
  - Azure CLI (`az`) via the official Microsoft repository
  - jq
  - Node Version Manager (nvm)
  - Cockpit (optional, for home server admin)
