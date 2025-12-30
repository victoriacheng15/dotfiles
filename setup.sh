#!/usr/bin/env bash
set -e  # exit if anything fails

# ============================================================================
# CONFIGURATION & CONSTANTS
# ============================================================================

# Dry-run mode flag
DRY_RUN=false

# Color variables for terminal output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ============================================================================
# LOGGING & HELPER FUNCTIONS
# ============================================================================

info() { echo -e "${GREEN}[INFO] $*${NC}"; }
error() { echo -e "${YELLOW}[ERROR] $*${NC}" >&2; }
dry_run_msg() { 
  if [ "$DRY_RUN" = true ]; then
    echo -e "${CYAN}[DRY-RUN] $*${NC}"
  fi
}

# Execute command or show dry-run message
execute() {
  if [ "$DRY_RUN" = true ]; then
    dry_run_msg "Would execute: $*"
    return 0
  else
    eval "$@"
  fi
}

# ============================================================================
# OS DETECTION & PACKAGE MANAGER SETUP
# ============================================================================

detect_os_and_package_manager() {
  echo "🚀 Setting up dev environment..."
  
  # Detect OS from /etc/os-release
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_ID="$ID"
    OS_VERSION="$VERSION_ID"
    OS_NAME="$NAME"
    info "Detected OS: $OS_NAME ($OS_ID $OS_VERSION)"
  else
    error "Cannot detect OS - /etc/os-release not found"
    exit 1
  fi
  
  # Detect package manager and set install command
  if command -v apt >/dev/null 2>&1; then
    PKG_MANAGER="apt"
    INSTALL_CMD="sudo apt install -y"
  elif command -v dnf >/dev/null 2>&1; then
    PKG_MANAGER="dnf"
    INSTALL_CMD="sudo dnf install -y"
  else
    error "No supported package manager found (apt or dnf). Exiting."
    exit 1
  fi
  
  info "Package manager: $PKG_MANAGER"
}

# Update system packages
update_system() {
  info "Updating system packages..."
  
  if [ "$PKG_MANAGER" = "apt" ]; then
    dry_run_msg "sudo apt update && sudo apt upgrade -y"
    execute "sudo apt update >/dev/null 2>&1 && sudo apt upgrade -y >/dev/null 2>&1"
  elif [ "$PKG_MANAGER" = "dnf" ]; then
    dry_run_msg "sudo dnf upgrade --refresh -y"
    execute "sudo dnf upgrade --refresh -y >/dev/null 2>&1"
  fi
  
  info "✔️ System packages updated"
}

# Get the correct package name for the current OS
get_package_name() {
  local tool="$1"
  case "$OS_ID:$tool" in
    ubuntu:fd) echo "fd-find" ;;
    fedora:fd) echo "fd-find" ;;
    *) echo "$tool" ;;
  esac
}

# ============================================================================
# BUILD TOOLS INSTALLATION (OS-specific)
# ============================================================================

install_build_tools() {
  if [ "$OS_ID" = "ubuntu" ]; then
    if ! dpkg -l | grep -q build-essential; then
      info "Installing Ubuntu build-essential..."
      execute "sudo apt install -y build-essential"
    else
      info "✔️ build-essential already installed"
    fi
  elif [ "$OS_ID" = "fedora" ]; then
    if ! dnf group list installed | grep -q "Development Tools"; then
      info "Installing Fedora Development Tools..."
      execute "sudo dnf group install -y development-tools"
    else
      info "✔️ Development Tools already installed"
    fi
  fi
}

# ============================================================================
# PACKAGE MANAGER INSTALLATIONS
# ============================================================================

# Install Nix package manager (cross-platform package manager)
install_nix() {
  if command -v nix >/dev/null 2>&1; then
    info "✔️ Nix already installed."
    return 0
  fi
  info "Installing Nix package manager..."
  if [ "$DRY_RUN" = true ]; then
    dry_run_msg "sh <(curl -L https://nixos.org/nix/install) --daemon"
    return 0
  fi
  sh <(curl -L https://nixos.org/nix/install) --daemon || {
    error "Nix installation failed. Please check logs or install manually."
    return 1
  }
  info "Nix installation complete. You may need to restart your shell or source /etc/profile.d/nix.sh."
}

# Install NVM (Node Version Manager)
install_nvm() {
  if [ ! -d "$HOME/.nvm" ]; then
    info "Installing NVM (Node Version Manager)..."
    if [ "$DRY_RUN" = true ]; then
      dry_run_msg "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/\$NVM_VERSION/install.sh | bash"
      return 0
    fi
    NVM_VERSION=$(curl -s https://api.github.com/repos/nvm-sh/nvm/releases/latest | jq -r .tag_name)
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/$NVM_VERSION/install.sh | bash
  else
    info "✔️ NVM already installed"
  fi
}

# ============================================================================
# SHELL INSTALLATION (Zsh + Oh My Zsh)
# ============================================================================

install_zsh() {
  local INSTALL_CMD="$1"

  if ! command -v zsh >/dev/null 2>&1; then
    info "Installing Zsh..."
    execute "$INSTALL_CMD zsh"
  else
    info "✔️ Zsh already installed"
  fi

  if [ ! -d "$HOME/.oh-my-zsh" ]; then
    info "Installing Oh My Zsh..."
    if [ "$DRY_RUN" = true ]; then
      dry_run_msg "RUNZSH=no CHSH=no sh -c \"\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\""
    else
      RUNZSH=no CHSH=no sh -c \
          "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    fi
  else
    info "✔️ Oh My Zsh already installed"
  fi
  
  # Add exec zsh to .bashrc to auto-switch to zsh
  if [ -f "$HOME/.bashrc" ]; then
    if ! grep -q "exec zsh" "$HOME/.bashrc"; then
      info "Adding 'exec zsh' to .bashrc for auto-switch..."
      if [ "$DRY_RUN" = true ]; then
        dry_run_msg "Would add exec zsh to $HOME/.bashrc"
      else
        echo "" >> "$HOME/.bashrc"
        echo "# Auto-switch to Zsh if available" >> "$HOME/.bashrc"
        echo "if [ -x /usr/bin/zsh ]; then" >> "$HOME/.bashrc"
        echo "  exec zsh" >> "$HOME/.bashrc"
        echo "fi" >> "$HOME/.bashrc"
        info "✔️ Added exec zsh to .bashrc"
      fi
    else
      info "✔️ exec zsh already in .bashrc"
    fi
  fi
}

# ============================================================================
# CONTAINERIZATION (Docker)
# ============================================================================

install_docker() {
  if command -v docker >/dev/null 2>&1; then
    info "✔️ Docker already installed"
    return 0
  fi
  
  info "Installing Docker..."
  
  if [ "$PKG_MANAGER" = "apt" ]; then
    # Remove old versions
    execute "sudo apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true"
    
    # Install prerequisites
    execute "sudo apt install -y ca-certificates curl gnupg lsb-release"
    execute "sudo mkdir -p /etc/apt/keyrings"
    
    # Add Docker's official GPG key and repository (Ubuntu)
    if [ "$DRY_RUN" = false ]; then
      curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
        sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    else
      dry_run_msg "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg"
      dry_run_msg "Add Docker apt repository"
    fi
    
    # Install Docker
    execute "sudo apt update >/dev/null 2>&1"
    execute "sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin"
    
  elif [ "$PKG_MANAGER" = "dnf" ]; then
    # Remove old versions
    execute "sudo dnf -y remove docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine 2>/dev/null || true"
    
    # Add Docker repository
    execute "sudo dnf -y install dnf-plugins-core"
    execute "sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo"
    
    # Install Docker
    execute "sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin"
    execute "sudo systemctl enable --now docker"
  else
    error "Docker installation not supported for this package manager."
    return 1
  fi
  
  info "✔️ Docker installed successfully"
}

# ============================================================================
# VERSION CONTROL & CI/CD TOOLS
# ============================================================================

# Install GitHub CLI
install_gh_cli() {
  if command -v gh >/dev/null 2>&1; then
    info "✔️ GitHub CLI already installed"
    return 0
  fi
  
  info "Installing GitHub CLI (gh)..."
  local pkg_name=$(get_package_name "gh")
  execute "$INSTALL_CMD $pkg_name" || error "Failed to install GitHub CLI from package manager"
}

# ============================================================================
# CLOUD CLI TOOLS (Azure, AWS, GCP)
# ============================================================================

# Install Azure CLI
install_azure() {
  if command -v az >/dev/null 2>&1; then
    info "✔️ Azure CLI already installed"
    return 0
  fi
  
  info "Installing Azure CLI..."
  
  if [ "$PKG_MANAGER" = "apt" ]; then
    sudo apt-get install -y ca-certificates curl gnupg lsb-release apt-transport-https
    curl -sL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | sudo tee /usr/share/keyrings/microsoft-archive-keyring.gpg >/dev/null
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/microsoft-archive-keyring.gpg] https://packages.microsoft.com/repos/azure-cli/ $(lsb_release -cs) main" \
      | sudo tee /etc/apt/sources.list.d/azure-cli.list
    sudo apt-get update >/dev/null 2>&1 && sudo apt-get install -y azure-cli
    
  elif [ "$PKG_MANAGER" = "dnf" ]; then
    sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
    sudo tee /etc/yum.repos.d/azure-cli.repo > /dev/null <<'EOF'
[azure-cli]
name=Azure CLI
baseurl=https://packages.microsoft.com/yumrepos/azure-cli
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF
    sudo dnf -y install azure-cli
  fi
}

# Install AWS CLI (placeholder for future implementation)
install_aws() {
  info "AWS CLI installation not yet implemented"
  info "Visit: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
}

# Install GCP CLI (placeholder for future implementation)
install_gcp() {
  info "GCP CLI installation not yet implemented"
  info "Visit: https://cloud.google.com/sdk/docs/install"
}

# ============================================================================
# DEVELOPER UTILITIES & TOOLS
# ============================================================================

# Install common development tools
install_tools() {
  local tools=("jq" "ripgrep" "fd")
  
  for tool in "${tools[@]}"; do
    local pkg_name=$(get_package_name "$tool")
    local check_cmd="$tool"
    
    # fd-find binary is called 'fdfind' on some systems
    if [ "$tool" = "fd" ]; then
      if command -v fd >/dev/null 2>&1 || command -v fdfind >/dev/null 2>&1; then
        info "✔️ $tool already installed"
        continue
      fi
    elif command -v "$check_cmd" >/dev/null 2>&1; then
      info "✔️ $tool already installed"
      continue
    fi
    
    info "Installing $tool..."
    execute "$INSTALL_CMD $pkg_name" || error "Failed to install $tool from package manager"
  done
}

# ============================================================================
# SERVER MANAGEMENT TOOLS
# ============================================================================

# Install Cockpit (web-based server management interface)
install_cockpit() {
  if systemctl is-active --quiet cockpit 2>/dev/null; then
    info "✔️ Cockpit already installed and running"
    return 0
  fi
  
  info "Installing Cockpit..."
  execute "$INSTALL_CMD cockpit" || {
    error "Failed to install Cockpit"
    return 1
  }
  
  # Enable/start cockpit via socket (preferred), fallback to service
  if command -v systemctl >/dev/null 2>&1; then
    execute "sudo systemctl enable --now cockpit.socket 2>/dev/null || sudo systemctl enable --now cockpit 2>/dev/null" || {
      error "Failed to enable/start Cockpit"
      return 1
    }
    info "✔️ Cockpit installed and started"
  fi
}

# ============================================================================
# CONFIGURATION & SETUP (SSH, Dotfiles)
# ============================================================================

# Generate SSH key for Git/GitHub
setup_ssh() {
  read -p "Do you want to generate a new SSH key for Git/GitHub? [y/N]: " SETUP_SSH
  if [[ "$SETUP_SSH" =~ ^[Yy]$ ]]; then
    if [ -f "$HOME/.ssh/id_ed25519" ] || [ -f "$HOME/.ssh/id_rsa" ]; then
      error "SSH key already exists in ~/.ssh"
      read -p "Display existing public key? [y/N]: " SHOW_KEY
      if [[ "$SHOW_KEY" =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}Your public key:${NC}"
        [ -f "$HOME/.ssh/id_ed25519.pub" ] && cat "$HOME/.ssh/id_ed25519.pub"
        [ -f "$HOME/.ssh/id_rsa.pub" ] && cat "$HOME/.ssh/id_rsa.pub"
      fi
    else
      read -p "Enter your email for SSH key: " SSH_EMAIL
      ssh-keygen -t ed25519 -C "$SSH_EMAIL" -f "$HOME/.ssh/id_ed25519" -N ""
      info "✔️ SSH key generated at ~/.ssh/id_ed25519"
      echo -e "${BLUE}Your public key:${NC}"
      cat "$HOME/.ssh/id_ed25519.pub"
    fi
  else
    info "Skipping SSH key setup"
  fi
}

# Symlink dotfiles to home directory
setup_symlink() {
  read -p "Do you want to symlink your dotfiles to your home directory? [y/N]: " LINK_DOTFILES
  if [[ "$LINK_DOTFILES" =~ ^[Yy]$ ]]; then
    for file in .zshrc .gitconfig; do
      if [ -L "$HOME/$file" ]; then
        info "✔️ $HOME/$file is already a symlink"
      else
        if [ -f "$HOME/$file" ]; then
          info "Backing up existing $HOME/$file to $HOME/$file.backup"
          execute "mv '$HOME/$file' '$HOME/$file.backup'"
        fi
        info "Creating symlink: $HOME/$file -> $PWD/$file"
        execute "ln -sf '$PWD/$file' '$HOME/$file'"
        info "✔️ Linked $HOME/$file"
      fi
    done
  else
    info "Skipping dotfile symlinking"
  fi
}

# ============================================================================
# MAIN SETUP ORCHESTRATION
# ============================================================================

main() {
  # Parse command line arguments
  for arg in "$@"; do
    case $arg in
      --dry-run)
        DRY_RUN=true
        info "🔍 DRY RUN MODE - No changes will be made"
        ;;
      --help|-h)
        echo "Usage: $0 [OPTIONS]"
        echo ""
        echo "Options:"
        echo "  --dry-run    Show what would be done without making any changes"
        echo "  --help, -h   Show this help message"
        echo ""
        exit 0
        ;;
      *)
        error "Unknown option: $arg"
        echo "Use --help for usage information"
        exit 1
        ;;
    esac
  done
  
  # Step 1: Detect OS and package manager
  detect_os_and_package_manager
  
  # Step 2: Update system packages (comment out for debugging)
  update_system
  
  # Step 3: Install build tools (build-essential or development-tools)
  install_build_tools
  
  # Step 4: Install package managers
  install_nix
  install_nvm
  
  # Step 5: Install shell environment
  install_zsh
  
  # Step 6: Install containerization tools
  install_docker
  
  # Step 7: Install version control tools
  install_gh_cli
  
  # Step 8: Install cloud CLI tools
  read -p "Do you want to install Azure CLI? [y/N]: " INSTALL_AZURE
  if [[ "$INSTALL_AZURE" =~ ^[Yy]$ ]]; then
    install_azure
  fi
  
  # Step 9: Install developer utilities
  install_tools
  
  # Step 10: Optional - Install Cockpit for server management
  read -p "Do you want to install Cockpit (web admin for home servers)? [y/N]: " INSTALL_COCKPIT
  if [[ "$INSTALL_COCKPIT" =~ ^[Yy]$ ]]; then
    install_cockpit
  fi
  
  # Step 11: Setup SSH keys
  setup_ssh
  
  # Step 12: Symlink dotfiles
  setup_symlink
  
  echo ""
  info "🎉 Setup complete!"
  info "📝 Next steps:"
  info "   1. Restart your terminal or run: source ~/.zshrc"
  info "   2. If you installed Docker, add your user to docker group: sudo usermod -aG docker \$USER"
  info "   3. If you installed NVM, restart terminal and run: nvm install --lts"
  echo ""
}

# ============================================================================
# SCRIPT ENTRY POINT
# ============================================================================

main "$@"

