#!/usr/bin/env bash
set -euo pipefail
rofi_menu() { rofi -no-config -theme "$HOME/.config/rofi/violet-night.rasi" "$@"; }
confirm() {
    local answer
    answer=$(printf 'Cancel\nConfirm\n' | rofi_menu -dmenu -p "$1") || return 1
    [[ "$answer" == Confirm ]]
}
case ${1:-apps} in
    apps) rofi_menu -show drun ;;
    browser)
        for browser in brave brave-browser; do
            if command -v "$browser" >/dev/null; then exec "$browser"; fi
        done
        notify-send 'Browser unavailable' 'Install brave-bin to use the browser shortcut.'
        exit 1
        ;;
    clipboard)
        choice=$(cliphist list | rofi_menu -dmenu -display-columns 2 -p Clipboard) || exit 0
        [[ -n "$choice" ]] || exit 0
        printf '%s\n' "$choice" | cliphist decode | wl-copy
        ;;
    clear-clipboard)
        if confirm 'Clear clipboard history?'; then cliphist wipe; wl-copy --clear; fi
        ;;
    brightness)
        choice=$(printf '10%%\n25%%\n50%%\n75%%\n100%%\n' | rofi_menu -dmenu -p Brightness) || exit 0
        [[ "$choice" =~ ^(10|25|50|75|100)%$ ]] || exit 0
        "$HOME/.scripts/hypr-brightness.sh" set "${choice%%%}"
        ;;
    lock) pgrep -x hyprlock >/dev/null || exec hyprlock ;;
    session)
        choice=$(printf 'Lock\nSuspend\nLog out\nRestart\nShut down\n' | rofi_menu -dmenu -p Session) || exit 0
        case "$choice" in
            Lock) exec "$0" lock ;;
            Suspend)
                loginctl lock-session
                for _ in {1..50}; do
                    if [[ $(loginctl show-session "${XDG_SESSION_ID:-self}" -p LockedHint --value) == yes ]]; then
                        exec systemctl suspend
                    fi
                    sleep 0.1
                done
                notify-send 'Suspend cancelled' 'The session did not confirm that it was locked.'
                exit 1
                ;;
            'Log out') confirm 'Log out?' && hyprctl dispatch 'hl.dsp.exit()' ;;
            Restart) confirm 'Restart?' && systemctl reboot ;;
            'Shut down') confirm 'Shut down?' && systemctl poweroff ;;
        esac
        ;;
    *) printf 'Unknown menu: %s\n' "$1" >&2; exit 2 ;;
esac
