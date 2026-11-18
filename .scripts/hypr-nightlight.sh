#!/usr/bin/env bash
# Night light toggle and Waybar status for hyprsunset.
set -euo pipefail
temperature=4000
icon='󰖔'  # nf-md-weather_night
state_file="${XDG_RUNTIME_DIR:-/tmp}/violet-nightlight-state"

running() { pgrep -x hyprsunset >/dev/null 2>&1; }
# Waybar signal 12 refreshes this module immediately (see config.jsonc).
refresh() { pkill -RTMIN+12 -x waybar 2>/dev/null || true; }
# The state file drives the bar: pgrep can still see the process for a moment
# after SIGTERM, which would otherwise leave the icon purple after toggling off.
is_on() {
    if [[ -f $state_file ]]; then
        [[ $(<"$state_file") == on ]]
    else
        running
    fi
}

case ${1:-toggle} in
    on)
        if ! running; then
            setsid hyprsunset -t "$temperature" >/dev/null 2>&1 &
        fi
        printf 'on\n' > "$state_file"
        refresh
        ;;
    off)
        pkill -x hyprsunset 2>/dev/null || true
        printf 'off\n' > "$state_file"
        refresh
        ;;
    toggle)
        if is_on; then "$0" off; else "$0" on; fi
        ;;
    status)
        hour=$(date +%H)
        if is_on; then
            printf '{"text":"%s","tooltip":"Night light %s K · click to disable","class":"active"}\n' \
                "$icon" "$temperature"
        elif (( 10#$hour >= 17 || 10#$hour < 7 )); then
            printf '{"text":"%s","tooltip":"Night light off · click to enable %s K","class":"off"}\n' \
                "$icon" "$temperature"
        else
            printf '{"text":"","tooltip":"","class":"hidden"}\n'
        fi
        ;;
    *)
        printf 'Usage: %s on|off|toggle|status\n' "$0" >&2
        exit 2
        ;;
esac
