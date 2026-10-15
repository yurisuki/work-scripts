#!/usr/bin/env bash
set -euo pipefail
mode=${1:-copy}
[[ $mode == copy || $mode == edit ]] || exit 2
target=${2:-area}
[[ $target == area || $target == window ]] || exit 2
runtime=${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}
exec 9>"$runtime/screenshot-$UID.lock"
flock -n 9 || exit 0
file=
freeze_pid=
stop_freeze() {
    if [[ -n $freeze_pid ]]; then
        kill "$freeze_pid" 2>/dev/null || true
        wait "$freeze_pid" 2>/dev/null || true
        freeze_pid=
    fi
}
cleanup() {
    stop_freeze
    [[ -z $file ]] || rm -f -- "$file"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
if ! command -v hyprpicker >/dev/null; then
    notify-send --app-name Screenshot 'Screenshot failed' 'Install hyprpicker to freeze the screen.' || true
    exit 1
fi
if [[ $target == window ]]; then
    # Only offer windows on workspaces currently visible on a monitor.
    monitors=$(hyprctl -j monitors)
    clients=$(hyprctl -j clients)
    boxes=$(jq -r --argjson monitors "$monitors" '
        [$monitors[] | if (.specialWorkspace.id // 0) != 0 then .specialWorkspace.id else .activeWorkspace.id end] as $visible
        | .[]
        | select(.mapped and (.hidden != true))
        | select(.workspace.id as $id | $visible | index($id))
        | select(.size[0] > 0 and .size[1] > 0)
        | "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"
    ' <<< "$clients")
    [[ -n $boxes ]] || exit 0
fi
# Keep the frozen surfaces alive until grim has captured the selection.
hyprpicker -r -z -d 9>&- >/dev/null 2>&1 &
freeze_pid=$!
sleep 0.2
if ! kill -0 "$freeze_pid" 2>/dev/null; then
    notify-send --app-name Screenshot 'Screenshot failed' 'Could not freeze the screen.' || true
    exit 1
fi
if [[ $target == window ]]; then
    geometry=$(slurp -r -d <<< "$boxes") || exit 0
else
    geometry=$(slurp -d) || exit 0
fi
[[ -n $geometry ]] || exit 0
# Capture completely before touching the clipboard or opening the editor.
file=$(mktemp "$runtime/screenshot-XXXXXX.png")
grim -g "$geometry" "$file"
stop_freeze
flock -u 9
if [[ $mode == edit ]]; then
    # Swappy saves only on request; Copy keeps the annotated image in the clipboard.
    export SCREENSHOT_SAVE_DIR="$(xdg-user-dir PICTURES)/Screenshots"
    swappy -f "$file" 9>&-
else
    wl-copy --type image/png < "$file" 9>&-
    notify-send --app-name Screenshot --expire-time 2000 'Screenshot copied' || true
fi
