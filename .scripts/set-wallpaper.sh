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
pkill -u "$USER" -x swaybg 2>/dev/null || true
nohup swaybg -i "$image_path" -m fill -c '#171020' >/dev/null 2>&1 </dev/null &
notify-send 'Wallpaper changed' "$(basename "$image_path")"
