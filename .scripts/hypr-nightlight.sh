#!/usr/bin/env bash
# Night light toggle and Waybar status for hyprsunset.
set -euo pipefail
temperature=4000
icon='󰖔'  # nf-md-weather_night

running() { pgrep -x hyprsunset >/dev/null 2>&1; }
# Waybar signal 12 refreshes this module immediately (see config.jsonc).
refresh() { pkill -RTMIN+12 -x waybar 2>/dev/null || true; }

case ${1:-toggle} in
    on)
        if ! running; then
            setsid hyprsunset -t "$temperature" >/dev/null 2>&1 &
            for _ in {1..20}; do
                running && break
                sleep 0.1
            done
        fi
        refresh
        ;;
    off)
        pkill -x hyprsunset 2>/dev/null || true
        refresh
        ;;
    toggle)
        if running; then "$0" off; else "$0" on; fi
        ;;
    status)
        if running; then
            printf '{"text":"%s","tooltip":"Night light %s K · click to disable","class":"active"}\n' \
                "$icon" "$temperature"
        else
            # Show the dim moon only in the evening/night; hide it during the day.
            hour=$(date +%H)
            if (( 10#$hour >= 17 || 10#$hour < 7 )); then
                printf '{"text":"%s","tooltip":"Night light off · click to enable %s K","class":"off"}\n' \
                    "$icon" "$temperature"
            else
                printf '{"text":"","tooltip":"","class":"hidden"}\n'
            fi
        fi
        ;;
    *)
        printf 'Usage: %s on|off|toggle|status\n' "$0" >&2
        exit 2
        ;;
esac
