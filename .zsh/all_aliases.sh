# Always handy
alias reload-shell='source ~/.zshrc'
alias reboot='sudo reboot'
alias shutdown='sudo shutdown now'

# Distro-aware package aliases
if command -v apt >/dev/null 2>&1; then
  alias update='sudo apt update && sudo apt upgrade -y'
  alias cleanup='sudo apt autoremove -y && sudo apt autoclean'
elif command -v dnf >/dev/null 2>&1; then
  # --refresh updates metadata; equivalent to apt update
  alias update='sudo dnf upgrade --refresh -y'
  alias cleanup='sudo dnf autoremove -y && sudo dnf clean all'
else
  update() { echo "No supported package manager found (apt/dnf)"; }
  cleanup() { echo "No supported package manager found (apt/dnf)"; }
fi

alias dev='cd $HOME/software'
alias home='cd ~'
alias ls='ls --color=auto -la'               # List all files in long format
alias ll='ls -lh'               # List files with human-readable sizes
alias la='ls -A'                # List all files except . and ..
alias l='ls -CF'                # List files in columns
# git
alias g='git'
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gcm='git commit -m'
alias gco='git checkout'
alias gb='git branch'
alias gp='git push'
alias gpl='git pull'
alias gd='git diff'
alias gl='git log --oneline --graph --decorate --all'
alias gst='git stash'
alias gsp='git stash pop'
# Docker Shortcuts
alias d='docker'
alias dc='docker compose'
alias dps='docker ps'
alias dim='docker images'
alias dlog='docker logs -f'
# python env
alias pyenv='source env/bin/activate'
# misc
alias dls='cp image_outputs/* /mnt/c/Users/$USER/Downloads/'