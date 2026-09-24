# Custom Purple Theme
autoload -U colors && colors

# Purple color scheme (using magenta/purple colors)
PROMPT="%F{171}┌[%f%F{171}%n%f%F{171}@%f%F{171}%m%f%F{171}]%f%F{171}─[%f%F{171}%~%f%F{171}]%f
%F{171}└[%f%F{171}%#%f%F{171}]%f%F{white} "

# Right prompt with time
RPROMPT="%F{171}%D{%H:%M}%f"

# Enable zsh completion system
autoload -Uz compinit

# Completion settings
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' list-colors ''
zstyle ':completion:*' group-name ''
zstyle ':completion:*' verbose yes
zstyle ':completion:*:descriptions' format '%B%d%b'
zstyle ':completion:*:messages' format '%d'
zstyle ':completion:*:warnings' format 'No matches for: %d'
# Show all prefix matches even when one is an existing file or directory.
zstyle ':completion:*' accept-exact false

# Zsh plugins directory
ZSH_PLUGINS_DIR="$HOME/.zsh/plugins"
mkdir -p "$ZSH_PLUGINS_DIR"

# zsh-autosuggestions
if [[ ! -d "$ZSH_PLUGINS_DIR/zsh-autosuggestions" ]]; then
  git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_PLUGINS_DIR/zsh-autosuggestions"
fi
source "$ZSH_PLUGINS_DIR/zsh-autosuggestions/zsh-autosuggestions.zsh"

# zsh-syntax-highlighting
if [[ ! -d "$ZSH_PLUGINS_DIR/zsh-syntax-highlighting" ]]; then
  git clone https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_PLUGINS_DIR/zsh-syntax-highlighting"
fi
source "$ZSH_PLUGINS_DIR/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"

# zsh-completions
if [[ ! -d "$ZSH_PLUGINS_DIR/zsh-completions" ]]; then
  git clone https://github.com/zsh-users/zsh-completions "$ZSH_PLUGINS_DIR/zsh-completions"
fi
fpath=("$ZSH_PLUGINS_DIR/zsh-completions/src" $fpath)
compinit

# Source custom aliases
if [[ -e ~/.zsh_aliases ]]; then
  source ~/.zsh_aliases
fi
