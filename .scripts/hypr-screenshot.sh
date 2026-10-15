#!/usr/bin/env bash
set -euo pipefail
mode=${1:-copy}
[[ $mode == copy || $mode == edit ]] || exit 2
geometry=$(slurp -d) || exit 0
[[ -n $geometry ]] || exit 0
# Capture completely before touching the clipboard or opening the editor.
file=$(mktemp "${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/screenshot-XXXXXX.png")
trap 'rm -f -- "$file"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
grim -g "$geometry" "$file"
if [[ $mode == edit ]]; then
    # Swappy saves only on request; Copy keeps the annotated image in the clipboard.
    export SCREENSHOT_SAVE_DIR="$(xdg-user-dir PICTURES)/Screenshots"
    swappy -f "$file"
else
    wl-copy --type image/png < "$file"
    notify-send --app-name Screenshot --expire-time 2000 'Screenshot copied' || true
fi
