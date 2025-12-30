# Dotfiles

Personal dotfiles and dev environment setup for Ubuntu/Fedora.

## Quick Start

```bash
git clone git@github.com:victoriacheng15/dotfiles.git
```

```bash
cd ~/dotfiles
./setup.sh              # Normal run
./setup.sh --dry-run    # Preview without changes
```

## What Gets Installed

**Core:**

- Build tools (build-essential/development-tools)
- Zsh + Oh My Zsh (auto-switches from bash)
- Nix, NVM

**Dev Tools:**

- GitHub CLI, jq, ripgrep, fd-find
- Docker + Docker Compose

**Optional (prompts):**

- Azure CLI
- Cockpit (server management)

**Config:**

- SSH key generation
- Symlinks .zshrc and .gitconfig

## After Setup

```bash
# Restart terminal or
source ~/.zshrc

# Add to docker group
sudo usermod -aG docker $USER
newgrp docker

# Install Node
nvm install --lts
```

## Useful Aliases

**System:** `reload-shell`, `update`, `cleanup`  
**Nav:** `dev`, `home`, `ls`, `ll`  
**Git:** `g`, `gs`, `ga`, `gc`, `gp`, `gpl`, `gl`, `gst`  
**Docker:** `d`, `dc`, `dps`, `dim`, `dlog`

## Debugging

```bash
# Skip system update - comment out in main():
# update_system

# Dry run
./setup.sh --dry-run

# Skip specific installs - comment out in main()
```

## Notes

- Supports Ubuntu 22.04/24.04 LTS and Fedora 40+
- Idempotent - safe to run multiple times
- All functions organized by category with comment headers
