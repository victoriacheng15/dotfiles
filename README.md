# Dotfiles

Personal dotfiles and dev environment setup for Ubuntu/Debian and Fedora.

### Packages to Install / Dev Stack
- [Zsh](https://www.zsh.org)
- [Oh My Zsh](https://ohmyz.sh)
- Go, Python, Rust
- [Helm](https://helm.sh)
- [OpenTofu](https://opentofu.org)
- [jq](https://jqlang.github.io/jq/) & [yq](https://github.com/mikefarah/yq)
- [AWS CLI](https://aws.amazon.com/cli/) & [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli)

*Note: Check the [Fedora Developer Portal](https://developer.fedoraproject.org/) for installing development packages on Fedora.*

## Setup

```bash
cd dotfiles/

# Run setup (defaults to Fedora):
bash install.sh

# Or specify target OS explicitly:
bash install.sh --os fedora
# or: bash install.sh --os ubuntu

# Preview execution:
bash install.sh --dry-run
```

`--dry-run` prints the commands that would run without changing packages, repositories, services, or dotfiles.

## What Gets Installed

**Core:**

- Zsh + Oh My Zsh (auto-switches from bash)
- Go, Rust/Cargo
- GitHub CLI
- Azure CLI

**Dev & DevOps Tools:**

- Docker + Docker Compose on Ubuntu/Debian only
- Helm
- OpenTofu
- jq, yq

**Config:**

- Symlinks configuration files into `$HOME` via [GNU Stow](https://www.gnu.org/software/stow/).

## After Setup

```bash
# Restart terminal or
source ~/.zshrc

# GitHub CLI
gh auth login
```

Fedora uses Podman by default and this setup intentionally skips Docker installation.

## Fedora Atomic Desktop & Toolbox Setup

Fedora Atomic Desktops (Silverblue, Kinoite, Sericea) feature an immutable root filesystem (`/`). Instead of package layering development tools onto the base system with `rpm-ostree`, development workflows run inside containerized environments using **Toolbox** (or Distrobox).

### Shared Home Directory

Your home directory (`/var/home/$USER`) is shared directly between the host and Toolbox containers. Any dotfiles configured here (`.zshrc`, `.p10k.zsh`, `.gitconfig`, `.gitignore_global`) are immediately active and shared across both the host and container environments.

### Toolbox Environments

From the Atomic host, run [install-atomic.sh](install-atomic.sh) to create and provision both containers automatically:

```bash
cd dotfiles/

# Provision both containers
bash install-atomic.sh

# Or target a specific one
bash install-atomic.sh --env=cloud
bash install-atomic.sh --env=node

# Preview without making changes
bash install-atomic.sh --dry-run
```

#### 1. Cloud & Infra Container (`cloud-dev`)

Installs group packages (`c-development`, `development-tools`, `editors`), then individual tools: `golang`, `rust`, `cargo`, `gh`, `azure-cli`, `jq`, `yq`, `helm`, `opentofu`, `awscli2`, `kubernetes-clients`, and `stow`. Also installs Oh My Zsh and [uv](https://docs.astral.sh/uv/) for Python tooling.

#### 2. Node.js Container (`node-dev`)

Installs `development-tools` group and `gcc-c++`, then sets up [mise](https://mise.jdx.dev/) with `node@lts` and `pnpm@latest`.

### Host-Level Applications

Install graphical user applications (IDEs, browsers, terminals) on the immutable host via Flatpak:

```bash
flatpak install flathub com.visualstudio.code
```

## Management

Configuration files (`.zshrc`, `.gitconfig`, `.p10k.zsh`, `.gemini/`) are symlinked into `$HOME` from this repository using [GNU Stow](https://www.gnu.org/software/stow/). This means edits made directly in `$HOME` are edits to the tracked files, and standard `git` commands in this repository are all you need.


```bash
make stow     # initial setup
make restow   # re-apply after adding/removing dotfiles
make unstow   # remove all symlinks
```


## Testing In Isolation

```bash
# Ubuntu
docker run -it --rm -v "$(pwd):/root/dotfiles" -w /root/dotfiles ubuntu:22.04 bash -c "apt update && apt install -y sudo && bash install.sh"

# Fedora
podman run -it --rm -v "$(pwd):/root/dotfiles:Z" -w /root/dotfiles fedora:44 bash -c "dnf install -y sudo && bash install.sh"
```


## Debugging

```bash
# Dry run
bash install.sh --dry-run
bash install-atomic.sh --dry-run

# Skip specific installs - comment out in main()
```

## Notes

- Supports Ubuntu 22.04/24.04 LTS and Fedora 40+
- Fedora setup intentionally skips Docker installation
- Idempotent - safe to run multiple times
- `install.sh` is the unified orchestrator for Fedora and Ubuntu; `install-atomic.sh` is for Fedora Atomic desktops (Silverblue, Kinoite, Sericea)
- Dotfiles are managed via GNU Stow; symlinks point from `$HOME` directly into this repository
