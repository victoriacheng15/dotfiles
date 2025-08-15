install_nvm(){
  local INSTALL_CMD="$1"
  
  if [ ! -d "$HOME/.nvm" ]; then
    echo -e "${GREEN}📦 Installing NVM...${NC}"
      curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash
  else
    echo -e "${GREEN}✔️ NVM already installed${NC}"
  fi
}