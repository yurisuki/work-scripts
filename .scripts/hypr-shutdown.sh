#!/usr/bin/env bash
set -euo pipefail

action=${1:-logout}
shift || true

play_exit_sound() {
    # Finish the short sound while the session audio server is still available.
    for option in "$@"; do
        [[ $option != --dry-run ]] || return 0
    done
    timeout 4 "$HOME/.local/bin/device-notifications.py" --play-and-wait session-end >/dev/null 2>&1 || true
}

case "$action" in
    logout|exit)
        play_exit_sound "$@"
        exec hyprshutdown --top-label "Logging out..." "$@"
        ;;
    reboot|restart)
        play_exit_sound "$@"
        exec hyprshutdown --top-label "Restarting..." -p "systemctl reboot" "$@"
        ;;
    poweroff|shutdown)
        play_exit_sound "$@"
        exec hyprshutdown --top-label "Shutting down..." -p "systemctl poweroff" "$@"
        ;;
    *)
        exec hyprshutdown "$action" "$@"
        ;;
esac
