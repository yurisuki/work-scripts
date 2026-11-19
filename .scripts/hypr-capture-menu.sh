#!/usr/bin/env bash
# SUPER+SHIFT+S: pick a screenshot or screen-recording action in rofi.
set -euo pipefail

rofi_menu() { rofi -no-config -theme "$HOME/.config/rofi/violet-night.rasi" "$@"; }

choice=$(
    printf '%s\n' \
        'Select window' \
        'Edit' \
        'Record video · full screen' \
        'Record video · select window' \
        'Record video · select area' |
        rofi_menu -dmenu -p 'Screenshot'
) || exit 0

case "$choice" in
    'Select window')                 exec "$HOME/.scripts/hypr-screenshot.sh" copy window ;;
    'Edit')                          exec "$HOME/.scripts/hypr-screenshot.sh" edit ;;
    'Record video · full screen')    exec "$HOME/.scripts/hypr-record.sh" full ;;
    'Record video · select window')  exec "$HOME/.scripts/hypr-record.sh" window ;;
    'Record video · select area')    exec "$HOME/.scripts/hypr-record.sh" area ;;
esac
