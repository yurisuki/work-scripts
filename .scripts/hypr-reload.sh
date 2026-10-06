#!/usr/bin/env bash
set -euo pipefail
# Avoid overlapping refreshes when the shortcut is pressed repeatedly.
exec 9>"${XDG_RUNTIME_DIR:?}/violet-reload.lock"
flock -n 9 || exit 0
if ! "$HOME/.scripts/bar-start.py" --render-only; then
    notify-send --app-name 'Violet Night' 'Reload failed' 'Could not read Waybar configuration.'
    exit 1
fi
if ! hyprctl reload config-only; then
    notify-send --app-name 'Violet Night' 'Reload failed' 'Could not reload Hyprland configuration.'
    exit 1
fi
errors=$(hyprctl configerrors)
if [[ -n ${errors//[[:space:]]/} ]]; then
    notify-send --app-name 'Violet Night' --urgency=critical 'Configuration errors' "$errors"
    exit 1
fi
if ! pkill -USR2 -x waybar; then
    hyprctl eval 'hl.exec_cmd(os.getenv("HOME") .. "/.scripts/bar-start.py")'
fi
notify-send --app-name 'Violet Night' --expire-time=2000 \
    --hint=boolean:SWAYNC_BYPASS_DND:true 'Configuration reloaded' 'Hyprland and Waybar refreshed successfully.'
