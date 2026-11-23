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

# Notification with an inline preview and Edit / Save actions.
notify_screenshot() {
    local preview=$1 folder=$2 action saved_action dest_dir dest card body
    local icon="$HOME/.local/share/device-notifications/icons/screenshot-copied.svg"
    mkdir -p -- "$folder" 2>/dev/null || true
    # SwayNC renders <img src="file://…"> in the body as a large preview;
    # the image-path hint would shrink it into the top-left icon instead.
    card=${preview%.png}-card.png
    if ! python3 - "$preview" "$card" 2>/dev/null <<'PY'
from PIL import Image, ImageOps
import sys
with Image.open(sys.argv[1]) as image:
    ImageOps.fit(image.convert('RGB'), (700, 380), method=Image.Resampling.LANCZOS).save(sys.argv[2], 'PNG')
PY
    then
        card=$preview
    fi
    body="Copied to clipboard <img src=\"file://$card\" width=\"350\" height=\"190\"/>"
    (
        action=$(notify-send --app-name Screenshot --icon "$icon" \
            --expire-time=20000 \
            --action 'edit=Edit' --action 'save=Save' --action 'default=Open folder' \
            'Screenshot copied' "$body" 2>/dev/null) || exit 0
        case $action in
            edit)
                exec swappy -f "$preview"
                ;;
            save)
                dest_dir="$(xdg-user-dir PICTURES)/Screenshots"
                mkdir -p -- "$dest_dir" 2>/dev/null || exit 0
                dest="$dest_dir/screenshot-$(date +%Y%m%d-%H%M%S).png"
                cp -- "$preview" "$dest" 2>/dev/null || exit 0
                saved_action=$(notify-send --app-name Screenshot --icon "$icon" \
                    --action 'default=Open folder' 'Screenshot saved' "$dest" \
                    2>/dev/null) || true
                [[ $saved_action == default ]] && exec kitty --title superfile -e spf "$dest_dir"
                ;;
            default)
                exec kitty --title superfile -e spf "$folder"
                ;;
        esac
    ) 9>&- >/dev/null 2>&1 &
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
# Keep a stable copy for the notification preview and its Edit / Save actions.
preview="$runtime/violet-screenshot-preview.png"
cp -f -- "$file" "$preview"
flock -u 9
"$HOME/.scripts/device-notifications.py" --preview screenshot 9>&- >/dev/null 2>&1 &
# Swappy saves only on request; Copy keeps the annotated image in the clipboard.
SCREENSHOT_SAVE_DIR="$(xdg-user-dir PICTURES)/Screenshots"
export SCREENSHOT_SAVE_DIR
if [[ $mode == edit ]]; then
    swappy -f "$file" 9>&-
else
    wl-copy --type image/png < "$file" 9>&-
    notify_screenshot "$preview" "$(xdg-user-dir PICTURES)/Screenshots"
fi
