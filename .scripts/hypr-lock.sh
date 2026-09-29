#!/usr/bin/env bash
set -euo pipefail

wallpaper_file="$HOME/.config/hypr/wallpaper"
if [[ -e "$wallpaper_file" ]]; then
    HYPRLOCK_WALLPAPER=$(cat -- "$wallpaper_file")
else
    HYPRLOCK_WALLPAPER="$HOME/.local/share/backgrounds/dark.jpg"
fi
export HYPRLOCK_WALLPAPER

exec hyprlock "$@"
