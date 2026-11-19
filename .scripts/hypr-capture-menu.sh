#!/usr/bin/env bash
# SUPER+SHIFT+S: stop a running recording, otherwise pick a capture action.
# Shift+Enter in the menu opens the screenshot editor (like rtemplate.py).
set -euo pipefail

# While recording, the same shortcut stops it instead of opening the menu.
if pgrep -x wf-recorder >/dev/null 2>&1; then
    exec "$HOME/.scripts/hypr-record.sh" stop
fi

rofi_menu() {
    rofi -no-config -theme "$HOME/.config/rofi/violet-night.rasi" "$@"
}

status=0
choice=$(
    printf '%s\n' \
        'Select window' \
        'Record video · full screen' \
        'Record video · select window' \
        'Record video · select area' |
        rofi_menu -dmenu -i \
        -p 'Take a screenshot' \
        -kb-accept-alt '' \
        -kb-custom-3 'Shift+Return,Shift+KP_Enter' \
        -mesg 'Enter  Select    ·    Shift+Enter  Edit screenshot    ·    Esc  Close'
) || status=$?

# rofi returns 12 for kb-custom-3 (Shift+Enter).
if [[ $status -eq 12 ]]; then
    exec "$HOME/.scripts/hypr-screenshot.sh" edit
fi
[[ $status -eq 0 ]] || exit 0

case "$choice" in
    'Select window')                 exec "$HOME/.scripts/hypr-screenshot.sh" copy window ;;
    'Record video · full screen')    exec "$HOME/.scripts/hypr-record.sh" full ;;
    'Record video · select window')  exec "$HOME/.scripts/hypr-record.sh" window ;;
    'Record video · select area')    exec "$HOME/.scripts/hypr-record.sh" area ;;
esac
