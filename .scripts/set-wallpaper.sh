#!/usr/bin/env bash
set -euo pipefail
wallpaper_config="$HOME/.config/hypr/wallpaper"
image_path="${1:-}"
if [[ -z "$image_path" ]]; then
    image_path=$(zenity --file-selection --title='Choose wallpaper' --filename="${HOME}/Pictures/" --file-filter='Images | *.jpg *.jpeg *.png *.webp *.bmp') || exit 0
fi
image_path=$(realpath -- "$image_path")
[[ -f "$image_path" ]] || { notify-send 'Wallpaper' 'Selected file does not exist.'; exit 1; }
mkdir -p "$(dirname "$wallpaper_config")"
printf '%s\n' "$image_path" > "$wallpaper_config"
mkdir -p "$HOME/.local/share/backgrounds"
ln -sfn -- "$image_path" "$HOME/.local/share/backgrounds/current-wallpaper.webp"
if ! pgrep -u "$USER" -x hyprpaper >/dev/null; then
    hyprctl eval 'hl.exec_cmd("hyprpaper")' >/dev/null
fi
# Allow a newly launched hyprpaper to open its IPC socket.
applied=false
for attempt in {1..20}; do
    if hyprctl hyprpaper wallpaper ",$HOME/.local/share/backgrounds/current-wallpaper.webp,cover" >/dev/null 2>&1; then
        applied=true
        break
    fi
    sleep 0.1
done
if [[ "$applied" != true ]]; then
    notify-send 'Wallpaper' 'Saved selection, but could not contact hyprpaper. Try logging out and back in.'
    exit 1
fi
pkill -u "$USER" -x swaybg 2>/dev/null || true
notify-send 'Wallpaper changed' "$(basename "$image_path")"
