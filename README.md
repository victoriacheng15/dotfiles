# Dotfiles

Personal dotfiles and dev environment setup for Ubuntu/Debian and Fedora.

## Quick Start

```bash
git clone git@github.com:victoriacheng15/dotfiles.git
```

```bash
cd ~/dotfiles

# Ubuntu/Debian
bash setup-ubuntu.sh
bash setup-ubuntu.sh --dry-run
bash setup-ubuntu.sh --server

# Fedora
bash setup-fedora.sh
bash setup-fedora.sh --dry-run
bash setup-fedora.sh --server
```

`--server` skips Zsh and desktop shell setup. `--dry-run` prints the commands that would run without changing packages, repositories, services, or dotfiles.

## What Gets Installed

**Core:**

- Zsh + Oh My Zsh (auto-switches from bash)
- Go, Rust/Cargo, NVM
- GitHub CLI
- Azure CLI

**Dev Tools:**

- Docker + Docker Compose on Ubuntu/Debian only
- K3s, Helm

**Config:**

- Symlinks .zshrc and .gitconfig

## After Setup

```bash
# Restart terminal or
source ~/.zshrc

# Ubuntu/Debian only: activate Docker group membership
newgrp docker

# GitHub CLI
gh auth login
```

Fedora uses Podman by default and this setup intentionally skips Docker installation.

## Testing In Isolation

```bash
# Ubuntu
docker run -it --rm -v "$(pwd):/root/dotfiles" -w /root/dotfiles ubuntu:22.04 bash -c "apt update && apt install -y sudo && bash setup-ubuntu.sh"

# Fedora
podman run -it --rm -v "$(pwd):/root/dotfiles:Z" -w /root/dotfiles fedora:39 bash -c "dnf install -y sudo && bash setup-fedora.sh"
```

## Useful Aliases

**System:** `reload-shell`, `update`, `cleanup`  
**Nav:** `dev`, `home`, `ls`, `ll`  
**Git:** `g`, `gs`, `ga`, `gc`, `gp`, `gpl`, `gl`, `gst`  
**Docker:** `d`, `dc`, `dps`, `dim`, `dlog`

## Debugging

```bash
# Dry run
bash setup-ubuntu.sh --dry-run
bash setup-fedora.sh --dry-run

# Skip specific installs - comment out in main()
```

## Notes

- Supports Ubuntu 22.04/24.04 LTS and Fedora 40+
- Fedora setup intentionally skips Docker installation
- Idempotent - safe to run multiple times
- `setup.sh` is the original combined script; prefer the OS-specific scripts for new installs
