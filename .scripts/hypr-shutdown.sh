#!/usr/bin/env bash
set -euo pipefail

action=${1:-logout}
shift || true

case "$action" in
    logout|exit)
        exec hyprshutdown --top-label "Logging out..." "$@"
        ;;
    reboot|restart)
        exec hyprshutdown --top-label "Restarting..." -p "systemctl reboot" "$@"
        ;;
    poweroff|shutdown)
        exec hyprshutdown --top-label "Shutting down..." -p "systemctl poweroff" "$@"
        ;;
    *)
        exec hyprshutdown "$action" "$@"
        ;;
esac
