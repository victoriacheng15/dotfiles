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
cd ~/dotfiles

# Run setup (defaults to Fedora):
bash setup.sh

# Or specify target OS explicitly:
bash setup.sh --os fedora
# or: bash setup.sh --os ubuntu

# Preview execution:
bash setup.sh --dry-run
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

- Manages configuration files directly in the home directory via a Git bare repository (`~/.dotfiles`) and a custom `dot` alias.

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

#### 1. Cloud & Infra Container (`cloud-dev`)

Dedicated container for Golang, Python, Kubernetes, and cloud infrastructure workflows. Managed entirely by [setup.sh](setup.sh):

```bash
# Create and enter container
toolbox create -c cloud-dev
toolbox enter cloud-dev

# Run automated setup
cd ~/dotfiles
bash setup.sh
```

This installs all core runtime and cloud tooling (`golang`, `rust`, `helm`, `opentofu`, `awscli2`, `azure-cli`, `kubernetes-clients`, `jq`, `yq`) and initializes dotfiles. Python tooling and virtual environments are managed via [uv](https://docs.astral.sh/uv/).

#### 2. Node.js Container (`node-dev`)

Dedicated container for frontend and JavaScript ecosystems, managed via [mise](https://mise.jdx.dev/):

```bash
# Create and enter container
toolbox create -c node-dev
toolbox enter node-dev

sudo dnf group install development-tools
sudo dnf install gcc-c++

# Install Node.js runtime and package managers via mise
mise use -g node@lts
mise use -g pnpm@latest
```

### Host-Level Applications

Install graphical user applications (IDEs, browsers, terminals) on the immutable host via Flatpak:

```bash
flatpak install flathub com.visualstudio.code
```

## Management

You can manage configuration files (`.zshrc`, `.gitconfig`, `.gemini/`) using either of two workflows:

### Method 1: Direct in `$HOME` (Bare Repo / `dot` Alias)

Edit active configuration files directly in your home directory without intermediate copying.

1. **Edit the target file:**
   ```bash
   vim ~/.zshrc
   # or edit ~/.gitconfig, ~/.gemini/
   ```

2. **Reload shell (for `.zshrc`):**
   ```bash
   reload-shell
   # or: source ~/.zshrc
   ```

3. **Stage, commit, and push:**
   ```bash
   dot status
   dot add ~/.zshrc
   dot commit -m "Update zsh configuration"
   dot push origin main
   ```
   *(Note: Ensure `dot remote set-url origin git@github.com:victoriacheng15/dotfiles.git` is set if pushing directly to GitHub).*

### Method 2: In Cloned Repository (`dotfiles/`)

Edit files inside this repository working directory, sync them to `$HOME`, and push using standard `git`.

1. **Edit the file:**
   ```bash
   vim .zshrc
   # or edit .gitconfig, .gemini/
   ```

2. **Sync to `$HOME` and reload:**
   ```bash
   cp .zshrc ~/.zshrc
   # for .gitconfig: cp .gitconfig ~/.gitconfig
   # for .gemini:    cp -r .gemini/ ~/.gemini/
   reload-shell
   ```

3. **Stage, commit, and push:**
   ```bash
   git add .zshrc
   git commit -m "Update zsh configuration"
   git push origin main
   ```

## Testing In Isolation

```bash
# Ubuntu
docker run -it --rm -v "$(pwd):/root/dotfiles" -w /root/dotfiles ubuntu:22.04 bash -c "apt update && apt install -y sudo && bash setup.sh"

# Fedora
podman run -it --rm -v "$(pwd):/root/dotfiles:Z" -w /root/dotfiles fedora:39 bash -c "dnf install -y sudo && bash setup.sh"
```

## Useful Aliases

**System:** `reload-shell`, `update`, `cleanup`  
**Nav:** `dev`, `home`, `ls`, `ll`  
**Git:** `g`, `gs`, `ga`, `gc`, `gp`, `gpl`, `gl`, `gst`  
**Docker:** `d`, `dc`, `dps`, `dim`, `dlog`

## Debugging

```bash
# Dry run
bash setup.sh --dry-run

# Skip specific installs - comment out in main()
```

## Notes

- Supports Ubuntu 22.04/24.04 LTS and Fedora 40+
- Fedora setup intentionally skips Docker installation
- Idempotent - safe to run multiple times
- `setup.sh` is the unified orchestrator script; it automatically detects your OS and installs missing packages.
