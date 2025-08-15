install_jq() {
  local INSTALL_CMD="$1"

  if ! command -v jq >/dev/null 2>&1; then
    echo -e "${GREEN}📦 Installing jq...${NC}"
      eval "$INSTALL_CMD jq" || echo -e "${YELLOW}⚠️ Failed to install jq from package manager${NC}"
  else
    echo -e "${GREEN}✔️ jq already installed${NC}"
  fi
}
