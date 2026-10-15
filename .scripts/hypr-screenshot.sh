#!/usr/bin/env bash
set -euo pipefail
mode=${1:-copy}
[[ $mode == copy || $mode == edit ]] || exit 2
target=${2:-area}
[[ $target == area || $target == window ]] || exit 2
if [[ $target == window ]]; then
    # Only offer windows on workspaces currently visible on a monitor.
    monitors=$(hyprctl -j monitors)
    clients=$(hyprctl -j clients)
    boxes=$(jq -r --argjson monitors "$monitors" '
        [$monitors[] | .activeWorkspace.id, .specialWorkspace.id | select(. != 0)] as $visible
        | .[]
        | select(.mapped and (.hidden != true))
        | select(.workspace.id as $id | $visible | index($id))
        | select(.size[0] > 0 and .size[1] > 0)
        | "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"
    ' <<< "$clients")
    [[ -n $boxes ]] || exit 0
    geometry=$(slurp -r -d <<< "$boxes") || exit 0
else
    geometry=$(slurp -d) || exit 0
fi
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
