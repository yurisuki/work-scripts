#!/usr/bin/env bash
# Screen recording with wf-recorder. Modes: full | window | area | stop.
set -euo pipefail

mode=${1:-full}
[[ $mode == full || $mode == window || $mode == area || $mode == stop ]] || exit 2

recorder="$HOME/.local/bin/wf-recorder"
icon_dir="$HOME/.local/share/device-notifications/icons"
icon="$icon_dir/recording.svg"
icon_done="$icon_dir/recording-done.svg"

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

if [[ $mode == stop ]]; then
    if pkill -INT -x wf-recorder 2>/dev/null; then
        notify-send --app-name 'Recording' --icon="$icon" 'Stopping recording' 'The video is being finalized and saved to Videos.' || true
    else
        notify-send --app-name 'Recording' --icon="$icon" 'No recording is running' || true
    fi
    exit 0
fi

if pgrep -x wf-recorder >/dev/null 2>&1; then
    notify-send --app-name 'Recording' --icon="$icon" 'A recording is already running' 'Stop it with Super+Shift+S.' || true
    exit 1
fi

if [[ ! -x $recorder ]]; then
    notify-send --app-name 'Recording' --icon="$icon" 'wf-recorder is missing' || true
    exit 1
fi

geometry=
case $mode in
    window)
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
        geometry=$(slurp -r -d <<< "$boxes") || exit 0
        ;;
    area)
        geometry=$(slurp -d) || exit 0
        ;;
esac
[[ -z $geometry ]] || [[ $geometry =~ ^[0-9]+,[0-9]+\ [0-9]+x[0-9]+$ ]] || exit 0

videos=$(xdg-user-dir VIDEOS 2>/dev/null || true)
[[ -n $videos && -d $videos ]] || videos="$HOME/Videos"
mkdir -p "$videos"
file="$videos/recording-$(date +%Y%m%d-%H%M%S).mp4"

args=(-f "$file")
[[ -n $geometry ]] && args+=(-g "$geometry")

notify-send --app-name 'Recording' --icon="$icon" 'Recording started' 'Stop it with Super+Shift+S.' || true
"$recorder" "${args[@]}" >/dev/null 2>&1 &
pid=$!
wait "$pid" || true
notify_folder "$icon_done" 'Recording' 'Video saved' "$file" "$videos"
