install_go() {
  local INSTALL_CMD="$1"

  if ! command -v go >/dev/null 2>&1; then
    echo -e "${GREEN}📦 Installing Go...${NC}"
      eval "$INSTALL_CMD golang" || echo -e "${YELLOW}⚠️ Failed to install Go from package manager${NC}"
  else
    echo -e "${GREEN}✔️ Go already installed${NC}"
  fi
}
