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
start() {
    "$@" 9>&- &
    pids+=("$!")
}
export PATH="$HOME/.local/bin:$PATH"
export XDG_CURRENT_DESKTOP=Hyprland
export XDG_SESSION_DESKTOP=Hyprland
export XDG_SESSION_TYPE=wayland
dbus-update-activation-environment --systemd PATH WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP XDG_SESSION_TYPE HYPRLAND_INSTANCE_SIGNATURE
# Keep portal/GSettings consumers consistent with the GTK theme and font settings.
if command -v gsettings >/dev/null 2>&1; then
    gsettings set org.gnome.desktop.interface gtk-theme 'VioletNight'
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
    gsettings set org.gnome.desktop.interface font-name 'Inter 10'
    gsettings set org.gnome.desktop.interface document-font-name 'Inter 10'
    gsettings set org.gnome.desktop.wm.preferences titlebar-font 'Inter Bold 10'
fi
wallpaper_file="$HOME/.config/hypr/wallpaper"
mkdir -p "$HOME/.local/share/backgrounds"
if [[ -s "$wallpaper_file" && -f "$(<"$wallpaper_file")" ]]; then
    ln -sfn -- "$(<"$wallpaper_file")" "$HOME/.local/share/backgrounds/current-wallpaper.webp"
else
    ln -sfn -- "$HOME/.local/share/backgrounds/dark.jpg" "$HOME/.local/share/backgrounds/current-wallpaper.webp"
fi
start hyprpaper
start "$HOME/.scripts/bar-session.sh"
start swaync
start "$HOME/.scripts/ticktick-startup.py"
start "$HOME/.scripts/hypr-osd.py" --daemon
start "$HOME/.scripts/hypr-game-focus.py"
start "$HOME/.local/bin/device-notifications.py"
play_startup_sound() {
    # Wait for the default output, then let login-time device routing settle.
    local attempt
    for attempt in {1..20}; do
        if timeout 2 wpctl get-volume @DEFAULT_AUDIO_SINK@ >/dev/null 2>&1; then
            sleep 2
            if ! timeout 2 wpctl get-volume @DEFAULT_AUDIO_SINK@ >/dev/null 2>&1; then
                continue
            fi
            systemctl --user is-active --quiet violet-focus.service && return 0
            timeout 5 pw-play --volume=0.25 "$HOME/.local/share/device-notifications/sounds/session-start.wav" ||
                printf 'Startup sound: playback failed\n' >&2
            return
        fi
        sleep 0.5
    done
    printf 'Startup sound: no audio output became available\n' >&2
}
start play_startup_sound
start hypridle
start udiskie
start snappy-switcher --daemon
start /usr/lib/hyprpolkitagent/hyprpolkitagent
start wl-paste --type text --watch cliphist store
start wl-paste --type image --watch cliphist store
# Preserve the existing work utilities in this session too.
if [[ -x "$HOME/.scripts/quote-download-watcher.sh" ]]; then
    systemctl --user start quote-download-watcher.path 2>/dev/null || true
fi
while hyprctl -j monitors >/dev/null 2>&1; do sleep 3; done
