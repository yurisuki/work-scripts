#!/usr/bin/env bash
# Screen recording with wf-recorder. Modes: full | window | area | stop.
set -euo pipefail

mode=${1:-full}
[[ $mode == full || $mode == window || $mode == area || $mode == stop ]] || exit 2

recorder="$HOME/.local/bin/wf-recorder"

if [[ $mode == stop ]]; then
    if pkill -INT -x wf-recorder 2>/dev/null; then
        notify-send --app-name 'Recording' 'Stopping recording' 'The video is being finalized and saved to Videos.' || true
    else
        notify-send --app-name 'Recording' 'No recording is running' || true
    fi
    exit 0
fi

if pgrep -x wf-recorder >/dev/null 2>&1; then
    notify-send --app-name 'Recording' 'A recording is already running' 'Stop it with Super+Shift+R.' || true
    exit 1
fi

if [[ ! -x $recorder ]]; then
    notify-send --app-name 'Recording' 'wf-recorder is missing' || true
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

notify-send --app-name 'Recording' 'Recording started' 'Stop it with Super+Shift+R.' || true
"$recorder" "${args[@]}" >/dev/null 2>&1 &
pid=$!
wait "$pid" || true
notify-send --app-name 'Recording' 'Video saved' "$file" || true
