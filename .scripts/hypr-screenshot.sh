#!/usr/bin/env bash
set -euo pipefail
mode=${1:-copy}
[[ $mode == copy || $mode == edit ]] || exit 2
geometry=$(slurp -d) || exit 0
[[ -n $geometry ]] || exit 0
pictures=$(xdg-user-dir PICTURES)
directory="$pictures/Screenshots"
mkdir -p -- "$directory"
file=$(mktemp "$directory/Screenshot-$(date +%Y-%m-%d_%H-%M-%S)-XXXXXX.png")
if ! grim -g "$geometry" "$file"; then
    rm -f -- "$file"
    exit 1
fi
if [[ $mode == edit ]]; then
    swappy -f "$file" -o "$file"
fi
wl-copy --type image/png < "$file"
action=$(notify-send --app-name Screenshot --icon "$file" --expire-time 10000 \
    --action=open=Open 'Screenshot saved and copied' "$file") || exit 0
[[ $action != open ]] || xdg-open "$file"
