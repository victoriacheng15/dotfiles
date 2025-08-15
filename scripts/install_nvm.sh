install_nvm(){
  local INSTALL_CMD="$1"
  
  if [ ! -d "$HOME/.nvm" ]; then
      echo "🟢 Installing NVM..."
      curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash
  else
      echo "✔️ NVM already installed"
  fi
}