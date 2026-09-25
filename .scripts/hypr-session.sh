#!/usr/bin/env bash
# Services belong to this Hyprland session, not the Plasma session or login screen.
set -uo pipefail
[[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]] || exit 0
exec 9>"${XDG_RUNTIME_DIR:?}/violet-hypr-session.lock"
flock -n 9 || exit 0
pids=()
cleanup() {
    trap - EXIT INT TERM
    for pid in "${pids[@]}"; do kill "$pid" 2>/dev/null || true; done
    wait 2>/dev/null || true
}
trap cleanup EXIT
trap 'exit 0' INT TERM
start() { "$@" 9>&- & pids+=("$!"); }
export PATH="$HOME/.local/bin:$PATH"
export XDG_CURRENT_DESKTOP=Hyprland
export XDG_SESSION_DESKTOP=Hyprland
export XDG_SESSION_TYPE=wayland
dbus-update-activation-environment --systemd PATH WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP XDG_SESSION_TYPE HYPRLAND_INSTANCE_SIGNATURE
wallpaper_file="$HOME/.config/hypr/wallpaper"
if [[ -s "$wallpaper_file" && -f "$(<"$wallpaper_file")" ]]; then
    start swaybg -i "$(<"$wallpaper_file")" -m fill -c '#171020'
else
    start swaybg -i "$HOME/.local/share/backgrounds/current-wallpaper.webp" -m fill -c '#171020'
fi
start "$HOME/.scripts/bar-start.py"
start swaync
start hypridle
start nm-applet --indicator
start /usr/lib/hyprpolkitagent/hyprpolkitagent
start wl-paste --type text --watch cliphist store
start wl-paste --type image --watch cliphist store
# Preserve the existing work utilities in this session too.
if [[ -x "$HOME/.scripts/quote-download-watcher.sh" ]]; then
    systemctl --user start quote-download-watcher.path 2>/dev/null || true
fi
while hyprctl -j monitors >/dev/null 2>&1; do sleep 3; done
