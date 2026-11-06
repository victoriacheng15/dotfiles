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

## Verification & Dry Run

```bash
# Run preflight verification checks
make preflight

# Preview Ansible package provisioning
make packages-check

# Run post-provisioning health check
make doctor
```
