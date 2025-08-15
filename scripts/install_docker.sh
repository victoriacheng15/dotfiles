install_docker() {
  local PKG_MANAGER="$1"

  if ! command -v docker >/dev/null 2>&1; then
      echo -e "${GREEN}📦 Installing Docker...${NC}"
      if [ "$PKG_MANAGER" = "apt" ]; then
          sudo apt remove -y docker docker-engine docker.io containerd runc || true
          sudo apt install -y ca-certificates curl gnupg lsb-release
          sudo mkdir -p /etc/apt/keyrings
          curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
          echo \
            "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
            $(lsb_release -cs) stable" | \
            sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
          sudo apt update
          sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
      elif [ "$PKG_MANAGER" = "dnf" ]; then
          sudo dnf -y remove docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine || true
          sudo dnf -y install dnf-plugins-core
          sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
          sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
          sudo systemctl enable --now docker
      else
          echo -e "${YELLOW}⚠️ Docker installation not supported for this package manager.${NC}"
      fi
  else
      echo -e "${GREEN}✔️ Docker already installed${NC}"
  fi
}
