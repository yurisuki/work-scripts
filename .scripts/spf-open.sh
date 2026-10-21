#!/usr/bin/env bash
# Superfile's editor action: images become wallpapers; other files use $EDITOR.
set -euo pipefail

[[ $# -eq 1 && -f "$1" ]] || { printf 'Select one file.\n' >&2; exit 1; }
mime_type=$(file --brief --mime-type -- "$1")
case "$mime_type" in
    image/*) exec "$HOME/.scripts/set-wallpaper.sh" "$1" ;;
    *)
        read -r -a editor_command <<< "${EDITOR:-nvim}"
        exec "${editor_command[@]}" -- "$1"
        ;;
esac
