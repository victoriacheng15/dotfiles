HOME_DIR := $(HOME)
DOTFILES_DIR := $(shell pwd)
ANSIBLE_CMD := ANSIBLE_CONFIG="$(DOTFILES_DIR)/ansible/ansible.cfg" ansible-playbook

.DEFAULT_GOAL := help

# ------------------------------------------------------------------------------
# Help
# ------------------------------------------------------------------------------
.PHONY: help

help:
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) }' $(MAKEFILE_LIST)

# ------------------------------------------------------------------------------
##@ Environment & Provisioning
# ------------------------------------------------------------------------------
.PHONY: preflight bootstrap packages-check packages

preflight: ## Run system and toolchain preflight verification checks
	bash "$(DOTFILES_DIR)/scripts/preflight.sh"

bootstrap: ## Install foundation prerequisites (uv, ansible-core, mise)
	bash "$(DOTFILES_DIR)/scripts/bootstrap.sh"

packages-check: ## Dry run system package provisioning via Ansible
	$(ANSIBLE_CMD) --check "$(DOTFILES_DIR)/ansible/playbook.yml"

packages: ## Provision system packages via Ansible
	$(ANSIBLE_CMD) "$(DOTFILES_DIR)/ansible/playbook.yml"

# ------------------------------------------------------------------------------
##@ Dotfiles Management
# ------------------------------------------------------------------------------
.PHONY: stow restow unstow

stow: ## Symlink all dotfiles and user utilities from home/ into $HOME
	stow -v -t "$(HOME_DIR)" -d "$(DOTFILES_DIR)" home

restow: ## Prune obsolete symlinks and re-create
	stow -v -R -t "$(HOME_DIR)" -d "$(DOTFILES_DIR)" home

unstow: ## Remove all symlinks managed by stow
	stow -v -D -t "$(HOME_DIR)" -d "$(DOTFILES_DIR)" home

