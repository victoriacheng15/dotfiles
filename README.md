# Dotfiles

Personal dotfiles and dev environment setup for Ubuntu/Debian and Fedora.

### Packages to Install / Dev Stack
- [Zsh](https://www.zsh.org)
- [Oh My Zsh](https://ohmyz.sh)
- Go, Python, Rust, NVM
- [K3s](https://k3s.io) & [Helm](https://helm.sh)
- [K9s](https://github.com/derailed/k9s)
- [OpenTofu](https://opentofu.org)
- [jq](https://jqlang.github.io/jq/) & [yq](https://github.com/mikefarah/yq)
- [AWS CLI](https://aws.amazon.com/cli/) & [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli)

*Note: Check the [Fedora Developer Portal](https://developer.fedoraproject.org/) for installing development packages on Fedora.*

## Setup

```bash
cd ~/dotfiles

# Run the main unified setup script
bash setup.sh
bash setup.sh --dry-run
bash setup.sh --server
```

`--server` skips Azure CLI, K3s (Kubernetes), and K9s to keep the server installation lightweight. `--dry-run` prints the commands that would run without changing packages, repositories, services, or dotfiles.

*(Note: `setup.sh` automatically detects your OS and delegates to `setup-ubuntu.sh` or `setup-fedora.sh` for OS-specific package installations.)*

## What Gets Installed

**Core:**

- Zsh + Oh My Zsh (auto-switches from bash)
- Go, Rust/Cargo, NVM
- GitHub CLI
- Azure CLI

**Dev & DevOps Tools:**

- Docker + Docker Compose on Ubuntu/Debian only
- K3s, Helm
- OpenTofu
- K9s
- jq, yq

**Config:**

- Manages configuration files directly in the home directory via a Git bare repository (`~/.dotfiles`) and a custom `dot` alias.

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
bash setup.sh --dry-run

# Skip specific installs - comment out in main()
```

## Notes

- Supports Ubuntu 22.04/24.04 LTS and Fedora 40+
- Fedora setup intentionally skips Docker installation
- Idempotent - safe to run multiple times
- `setup.sh` is the main orchestrator script; it automatically delegates OS-specific package installation to helper scripts.
