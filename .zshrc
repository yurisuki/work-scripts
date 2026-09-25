# Custom Purple Theme
autoload -U colors && colors

# Purple color scheme (using magenta/purple colors)
PROMPT="%F{171}┌[%f%F{171}%n%f%F{171}@%f%F{171}%m%f%F{171}]%f%F{171}─[%f%F{171}%~%f%F{171}]%f
%F{171}└[%f%F{171}%#%f%F{171}]%f%F{white} "

# Right prompt with time
RPROMPT="%F{171}%D{%H:%M}%f"

# Enter a directory by typing its name without cd.
setopt AUTO_CD

# Command-line navigation (consistent even when EDITOR is set to vi).
bindkey -e
# Ctrl+Left / Ctrl+Right: move by word (common terminal sequences).
bindkey '^[[1;5D' backward-word
bindkey '^[[1;5C' forward-word
bindkey '^[[5D' backward-word
bindkey '^[[5C' forward-word
bindkey '^[Od' backward-word
bindkey '^[Oc' forward-word
# Home / End: move to the beginning / end of the command line.
bindkey '^[[H' beginning-of-line
bindkey '^[[F' end-of-line
bindkey '^[OH' beginning-of-line
bindkey '^[OF' end-of-line
bindkey '^[[1~' beginning-of-line
bindkey '^[[4~' end-of-line
bindkey '^[[7~' beginning-of-line
bindkey '^[[8~' end-of-line
# Delete / Ctrl+Delete: delete the next character / word.
bindkey '^[[3~' delete-char
bindkey '^[[3;5~' kill-word
# Ctrl+Backspace (where supported) / Ctrl+W: delete the previous word.
bindkey '^H' backward-kill-word
bindkey '^W' backward-kill-word

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

# Use distro-managed plugins; no network requests when opening a shell.
fpath=(/usr/share/zsh/site-functions $fpath)
compinit
[[ ! -r /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]] || source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
[[ ! -r /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] || source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
export PATH="$HOME/.local/bin:$PATH"
export EDITOR=nvim

# Source custom aliases
if [[ -e ~/.zsh_aliases ]]; then
  source ~/.zsh_aliases
fi
