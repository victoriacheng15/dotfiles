HOME_DIR := $(HOME)
DOTFILES_DIR := $(shell pwd)
BIN_DIR := $(HOME_DIR)/.local/bin

.PHONY: stow restow unstow bin

# Symlink all dotfiles from home/ into $HOME
stow:
	stow -v -t "$(HOME_DIR)" -d "$(DOTFILES_DIR)" home

# Prune obsolete symlinks and re-create (use after adding/removing files)
restow:
	stow -v -R -t "$(HOME_DIR)" -d "$(DOTFILES_DIR)" home

# Remove all symlinks managed by stow
unstow:
	stow -v -D -t "$(HOME_DIR)" -d "$(DOTFILES_DIR)" home

# Symlink CLI utilities into ~/.local/bin
bin:
	mkdir -p "$(BIN_DIR)"
	ln -sf "$(DOTFILES_DIR)/scripts/gh-status.sh" "$(BIN_DIR)/gh-status"
	ln -sf "$(DOTFILES_DIR)/scripts/ppr.sh" "$(BIN_DIR)/ppr"
	ln -sf "$(DOTFILES_DIR)/scripts/setup-guardrails.sh" "$(BIN_DIR)/setup-guardrails"

