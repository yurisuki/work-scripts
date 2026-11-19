#!/usr/bin/env bash
set -euo pipefail
mode=${1:-copy}
[[ $mode == copy || $mode == edit ]] || exit 2
target=${2:-area}
[[ $target == area || $target == window || $target == full ]] || exit 2
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

# Desktop notification whose click opens a folder in superfile.
notify_folder() {
    local icon=$1 app=$2 title=$3 message=$4 folder=$5 action
    [[ -n $folder ]] || return 0
    mkdir -p -- "$folder" 2>/dev/null || true
    (
        action=$(notify-send --app-name "$app" --icon "$icon" \
            --action 'default=Open folder' "$title" "$message" 2>/dev/null) || exit 0
        [[ $action == default ]] || exit 0
        exec kitty --title superfile -e spf "$folder"
    ) >/dev/null 2>&1 &
}
if [[ $target != full ]] && ! command -v hyprpicker >/dev/null; then
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
# Freeze only when a selection UI is involved; full-screen capture needs no picker.
if [[ $target != full ]]; then
    hyprpicker -r -z -d 9>&- >/dev/null 2>&1 &
    freeze_pid=$!
    sleep 0.2
    if ! kill -0 "$freeze_pid" 2>/dev/null; then
        notify-send --app-name Screenshot 'Screenshot failed' 'Could not freeze the screen.' || true
        exit 1
    fi
fi
if [[ $target == full ]]; then
    geometry=
elif [[ $target == window ]]; then
    geometry=$(slurp -r -d <<< "$boxes") || exit 0
else
    geometry=$(slurp -d) || exit 0
fi
[[ $target == full || -n $geometry ]] || exit 0
# Capture completely before touching the clipboard or opening the editor.
file=$(mktemp "$runtime/screenshot-XXXXXX.png")
if [[ -n $geometry ]]; then
    grim -g "$geometry" "$file"
else
    grim "$file"
fi
stop_freeze
flock -u 9
"$HOME/.scripts/device-notifications.py" --preview screenshot 9>&- >/dev/null 2>&1 &
if [[ $mode == edit ]]; then
    # Swappy saves only on request; Copy keeps the annotated image in the clipboard.
    SCREENSHOT_SAVE_DIR="$(xdg-user-dir PICTURES)/Screenshots"
    export SCREENSHOT_SAVE_DIR
    swappy -f "$file" 9>&-
else
    wl-copy --type image/png < "$file" 9>&-
    notify_folder \
        "$HOME/.local/share/device-notifications/icons/screenshot-copied.svg" \
        'Screenshot' 'Screenshot copied' 'Copied to clipboard' \
        "$(xdg-user-dir PICTURES)/Screenshots"
fi
