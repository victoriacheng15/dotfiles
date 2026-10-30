HOME_DIR := $(HOME)
DOTFILES_DIR := $(shell pwd)

.PHONY: stow restow unstow preflight

# Run system and toolchain preflight verification checks
preflight:
	bash "$(DOTFILES_DIR)/scripts/preflight.sh"

# Symlink all dotfiles and user utilities from home/ into $HOME
stow:
	stow -v -t "$(HOME_DIR)" -d "$(DOTFILES_DIR)" home

# Prune obsolete symlinks and re-create (use after adding/removing files)
restow:
	stow -v -R -t "$(HOME_DIR)" -d "$(DOTFILES_DIR)" home

# Remove all symlinks managed by stow
unstow:
	stow -v -D -t "$(HOME_DIR)" -d "$(DOTFILES_DIR)" home

