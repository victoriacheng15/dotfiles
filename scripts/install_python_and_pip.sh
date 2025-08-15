install_python_and_pip() {
  local INSTALL_CMD="$1"

  if ! command -v python3 >/dev/null 2>&1; then
    echo -e "${GREEN}📦 Installing Python3...${NC}"
      eval "$INSTALL_CMD python3" || echo -e "${YELLOW}⚠️ Failed to install Python3 from package manager${NC}"
  else
      echo -e "${GREEN}✔️ Python3 already installed${NC}"
  fi

  if ! command -v pip3 >/dev/null 2>&1; then
    echo -e "${GREEN}📦 Installing pip3...${NC}"
      eval "$INSTALL_CMD python3-pip" || eval "$INSTALL_CMD pip" || echo -e "${YELLOW}⚠️ Failed to install pip3 from package manager${NC}"
  else
      echo -e "${GREEN}✔️ pip3 already installed${NC}"
  fi
}
