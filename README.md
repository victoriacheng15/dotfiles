# Dotfiles

Personal dotfiles and environment setup. Supports Fedora 40+ and Ubuntu 22.04/24.04 LTS.

## Setup

The repository uses a three-tier architecture orchestrated via `make`:
- **Tier 1 (Foundation Packages):** System packages managed declaratively via Ansible (`ansible/`).
- **Tier 2 (Python Tools):** Isolated virtual environments managed via `uv`.
- **Tier 3 (Polyglot Runtimes):** User-space tools managed via `mise` (`home/.config/mise/config.toml`).
- **Configuration & CLI Utilities:** Dotfiles and personal CLI tools managed via GNU Stow (`home/`).

### Quick Start Workflow

```bash
cd dotfiles/
make preflight
make bootstrap
make packages-check
make packages
make tools
make restow
make doctor
```

## After Setup

```bash
source ~/.zshrc
gh auth login
```

## Management

Dotfiles and CLI utilities in `home/` are symlinked into `$HOME` via [GNU Stow](https://www.gnu.org/software/stow/).

```bash
make stow
make restow
make unstow
make doctor
```

### Personal CLI Utilities (`~/.local/bin/`)

Tracked in `home/.local/bin/` and symlinked directly into your `$PATH`:

- **`gh-issues`:** CLI for managing blog drafts and LinkedIn issues in `victoriacheng15/blog-drafts`:
  - `gh-issues --blog <file>`: Create blog draft issue with frontmatter title and yearly milestone.
  - `gh-issues --linkedin <file>`: Create LinkedIn draft issue with 'ln-only' label.
  - `gh-issues --fetch <issue_no>`: Fetch issue body into `issue-<issue_no>.md`.
  - `gh-issues --update <issue_no> [file]`: Update issue body from `issue-<issue_no>.md` (or specified file).
- **`gh-setup`:** GitHub repository ruleset and guardrail configuration.
- **`gh-status`:** Fast inspector for GitHub PR and issue states (`gh-status --issue <num>`, `gh-status --pr <num>`).
- **`ppr`:** Interactive pretty PR listing.


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

<details>
<summary>Fedora Atomic Desktop & Toolbox Setup</summary>

Fedora Atomic Desktops (Silverblue, Kinoite, Sericea) feature an immutable root filesystem (`/`). Instead of package layering development tools onto the base system with `rpm-ostree`, development workflows run inside containerized environments using **Toolbox** (or Distrobox).

### Shared Home Directory

Your home directory (`/var/home/$USER`) is shared directly between the host and Toolbox containers. Any dotfiles configured here (`.zshrc`, `.p10k.zsh`, `.gitconfig`, `.gitignore_global`) are immediately active and shared across both the host and container environments.

### Toolbox Environment (`workspace`)

From the Atomic host, run [install-atomic.sh](install-atomic.sh) to create and provision the unified `workspace` container:

```bash
cd dotfiles/
bash install-atomic.sh
bash install-atomic.sh --dry-run
```

Once provisioned, enter the environment:

```bash
toolbox enter workspace
```

### Host-Level Applications

Install graphical user applications (IDEs, browsers, terminals) on the immutable host via Flatpak:

```bash
flatpak install flathub com.visualstudio.code
```

</details>
