install_gh_cli() {
  local INSTALL_CMD="$1"

  if ! command -v gh >/dev/null 2>&1; then
    echo -e "${GREEN}📦 Installing GitHub CLI (gh)...${NC}"
      eval "$INSTALL_CMD gh" || echo -e "${YELLOW}⚠️ Failed to install GitHub CLI from package manager${NC}"
  else
    echo -e "${GREEN}✔️ GitHub CLI already installed${NC}"
  fi
}
