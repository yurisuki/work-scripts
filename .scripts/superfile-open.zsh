#!/usr/bin/env zsh

# Desktop launchers do not read the interactive shell PATH.
export PATH="$HOME/.local/bin:$PATH"

if [[ -n "$1" ]]; then
    cd -- "$1" || exit 1
else
    cd -- "$HOME" || exit 1
fi

# Use the last-directory file written by this installed superfile version.
last_dir_file="${XDG_STATE_HOME:-$HOME/.local/state}/superfile/lastdir"
rm -f -- "$last_dir_file"
command spf
if [[ -f "$last_dir_file" ]]; then
    source "$last_dir_file"
    rm -f -- "$last_dir_file"
fi

# Keep a real terminal prompt after quitting the file manager.
exec zsh -i
