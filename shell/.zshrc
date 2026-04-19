# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH

# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time Oh My Zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="refined"

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment one of the following lines to change the auto-update behavior
# zstyle ':omz:update' mode disabled  # disable automatic updates
# zstyle ':omz:update' mode auto      # update automatically without asking
# zstyle ':omz:update' mode reminder  # just remind me to update when it's time

# Uncomment the following line to change how often to auto-update (in days).
# zstyle ':omz:update' frequency 13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(git ansible python)

source $ZSH/oh-my-zsh.sh

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='nvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch $(uname -m)"

# Set personal aliases, overriding those provided by Oh My Zsh libs,
# plugins, and themes. Aliases can be placed here, though Oh My Zsh
# users are encouraged to define aliases within a top-level file in
# the $ZSH_CUSTOM folder, with .zsh extension. Examples:
# - $ZSH_CUSTOM/aliases.zsh
# - $ZSH_CUSTOM/macos.zsh

# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"

# Always handy
alias reload-shell='source ~/.zshrc'
alias reboot='sudo reboot'
alias shutdown='sudo shutdown now'

alias update='sudo apt update && sudo apt upgrade -y'
alias cleanup='sudo apt autoremove -y && sudo apt clean'

# Set update/cleanup aliases based on distro (Ubuntu/Debian or Fedora)
if [ -f /etc/os-release ]; then
  . /etc/os-release
  case "$ID" in
    ubuntu|debian|pop)
      alias update='sudo apt update && sleep 1 && sudo apt upgrade -y'
      alias cleanup='sudo apt autoremove -y && sleep 1 && sudo apt clean'
      ;;
    fedora)
      alias update='sudo dnf upgrade --refresh -y'
      alias cleanup='sudo dnf autoremove -y && sleep 1 && sudo dnf clean all'
      ;;
    *)
      alias update='echo "Unknown distro: $ID"'
      alias cleanup='echo "Unknown distro: $ID"'
      ;;
  esac
fi

alias dev='cd $HOME/software'
alias home='cd ~'
alias ls='ls --color=auto -la'               # List all files in long format
alias ll='ls -lah'               # List files with human-readable sizes
alias la='ls -A'                # List all files except . and ..
alias l='ls -CF'                # List files in columns
# Docker Shortcuts
alias d='docker'
alias dc='docker compose'
alias dps='docker ps'
alias dim='docker images'
alias dlog='docker logs -f'
alias docker=podman
# misc
alias dls='cp image_outputs/* /mnt/c/Users/$USER/Downloads/'
alias k='kubectl'

ignore_files() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    echo "📄 Supported .gitignore types:"
    npx gitignore -types
    return 0
  fi

  if [[ "$#" -eq 0 ]]; then
    echo "❌ Please provide at least one language/framework (e.g., node, python)"
    echo "ℹ️ Use 'ignore_files --help' to list available types"
    return 1
  fi

  npx gitignore "$@"
  echo "✅ .gitignore generated for: $*"
}

# GitHub PR Helper: Creates or updates a PR based on commit.md
ppr() {
    local COMMIT_FILE="commit.md"

    if [[ ! -f "$COMMIT_FILE" ]]; then
        echo "❌ Error: $COMMIT_FILE not found in current directory."
        return 1
    fi

    # Create temp file for body and ensure cleanup
    local BODY_FILE=$(mktemp)
    trap "rm -f '$BODY_FILE'" EXIT

    # Extract body: from '### Summary' to just before '## Execution Commands'
    awk '/### Summary/,/## Execution Commands/ { if (!/## Execution Commands/) print }' "$COMMIT_FILE" > "$BODY_FILE"

    # Extract title from the git commit command line in commit.md
    local TITLE=$(grep "git commit -m" "$COMMIT_FILE" | sed 's/.*-m "\(.*\)".*/\1/')

    if [[ "$1" == "--dry-run" ]]; then
        echo "--- Extracted PR Body ---"
        cat "$BODY_FILE"
        echo "-------------------------"
        if gh pr view >/dev/null 2>&1; then
            echo "🔍 DRY RUN: gh pr edit --body-file <temp_file>"
        else
            echo "🔍 DRY RUN: gh pr create --title \"$TITLE\" --body-file <temp_file>"
        fi
        return 0
    fi

    if gh pr view >/dev/null 2>&1; then
        echo "🔄 Existing PR found. Updating body..."
        gh pr edit --body-file "$BODY_FILE"
    else
        echo "🚀 Creating new PR: $TITLE"
        gh pr create --title "$TITLE" --body-file "$BODY_FILE"
    fi
}

# Method 1: Fetch issue body and save as issue-[num].md
# Usage: fetch_issue <issue_number>
fetch_issue() {
    local repo="victoriacheng15/blog-drafts"
    local issue_no=$1
    if [[ -z "$issue_no" ]]; then
        echo "Usage: fetch_issue <issue_number>"
        return 1
    fi

    local file_path="issue-${issue_no}.md"
    echo "Fetching issue #$issue_no from $repo to $file_path..."
    gh issue view "$issue_no" --repo "$repo" --json body --jq .body > "$file_path"
}

# Method 2: Update issue body from a local file
# Usage: update_issue <issue_number> <file_path>
update_issue() {
    local repo="victoriacheng15/blog-drafts"
    local issue_no=$1
    local file_path=$2

    if [[ -z "$issue_no" || -z "$file_path" ]]; then
        echo "Usage: update_issue <issue_number> <file_path>"
        return 1
    fi

    if [[ ! -f "$file_path" ]]; then
        echo "Error: File $file_path not found."
        return 1
    fi

    echo "Updating issue #$issue_no in $repo from $file_path..."
    gh issue edit "$issue_no" --repo "$repo" --body-file "$file_path"
}

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

export KUBECONFIG=~/.kube/config

export WASMTIME_HOME="$HOME/.wasmtime"
export PATH="$WASMTIME_HOME/bin:$PATH"
