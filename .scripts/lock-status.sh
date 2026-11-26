#!/bin/sh
# Single-line lockscreen status: battery, Wi-Fi, volume and brightness.
# Pure /bin/sh (no Python) so hyprlock renders it immediately at lock time.

parts=""

add() {
    [ -z "$1" ] && return
    if [ -n "$parts" ]; then
        parts="$parts  |  $1"
    else
        parts="$1"
    fi
}

# Battery (omitted entirely when the machine has no battery)
battery=""
for b in /sys/class/power_supply/BAT*; do
    [ -r "$b/capacity" ] || continue
    cap=$(cat "$b/capacity" 2>/dev/null) || continue
    state=$(cat "$b/status" 2>/dev/null)
    case "$state" in
        Charging) icon='󰂄' ;;
        Full)     icon='󰁹' ;;
        *)
            if [ "$cap" -ge 75 ]; then icon='󰂀'
            elif [ "$cap" -ge 50 ]; then icon='󰁾'
            elif [ "$cap" -ge 25 ]; then icon='󰁼'
            else icon='󰁺'
            fi
            ;;
    esac
    battery="$icon $cap%"
    break
done
add "$battery"

# Network: Wi-Fi SSID, ethernet glyph, or disconnected glyph
wifi_dev=$(LC_ALL=C nmcli -t -f TYPE,DEVICE device 2>/dev/null | grep '^wifi:' | head -n 1 | cut -d: -f2-)
ssid=''
[ -n "$wifi_dev" ] && ssid=$(LC_ALL=C nmcli -g GENERAL.CONNECTION device show "$wifi_dev" 2>/dev/null)
[ "$ssid" = '--' ] && ssid=''
if [ -n "$ssid" ]; then
    add "󰖩 $ssid"
elif LC_ALL=C nmcli -t -f TYPE,STATE device 2>/dev/null | grep -q '^ethernet:connected'; then
    add '󰈀'
else
    add '󰖪'
fi

# Default audio output volume (uses the same glyphs as Waybar)
vol=$(LC_ALL=C wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null)
case "$vol" in
    *'[MUTED]'*)
        add '󰝟 muted'
        ;;
    Volume:*)
        pct=$(printf '%s\n' "$vol" | awk '{ n = $2 * 100 + 0.5; print int(n) }')
        if [ -n "$pct" ]; then
            if [ "$pct" -le 33 ]; then icon='󰕿'
            elif [ "$pct" -le 66 ]; then icon='󰖀'
            else icon='󰕾'
            fi
            add "$icon $pct%"
        fi
        ;;
esac

# Brightness: sysfs backlight first, then the same cached DDC state Waybar uses.
# The icon tiers match Waybar's custom/brightness format-icons (1 / 4 / 7).
add_brightness() {
    case $1 in
        ''|*[!0-9]*) return ;;
    esac
    if [ "$1" -le 33 ]; then icon='󰃚'
    elif [ "$1" -le 66 ]; then icon='󰃝'
    else icon='󰃠'
    fi
    add "$icon $1%"
}
for d in /sys/class/backlight/*; do
    [ -r "$d/brightness" ] || continue
    cur=$(cat "$d/brightness" 2>/dev/null) || continue
    max=$(cat "$d/max_brightness" 2>/dev/null) || continue
    [ "$max" -gt 0 ] || continue
    add_brightness $(((cur * 100 + max / 2) / max))
    break
done
if ! ls /sys/class/backlight/* >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
    runtime=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
    # hypr-brightness.py writes an empty error string on success.
    cached=$(jq -r 'select((.error // "") == "") | .target // empty' \
        "$runtime/violet-brightness.json" 2>/dev/null)
    add_brightness "$cached"
fi

[ -n "$parts" ] && printf '%s\n' "$parts"
