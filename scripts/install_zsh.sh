install_zsh() {
  local INSTALL_CMD="$1"

  if ! command -v zsh >/dev/null 2>&1; then
    echo -e "${GREEN}📦 Installing Zsh...${NC}"
      eval "$INSTALL_CMD zsh"
  else
    echo -e "${GREEN}✔️ Zsh already installed${NC}"
  fi

  if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo -e "${GREEN}📦 Installing Oh My Zsh...${NC}"
      RUNZSH=no CHSH=no sh -c \
          "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  else
    echo -e "${GREEN}✔️ Oh My Zsh already installed${NC}"
  fi
}