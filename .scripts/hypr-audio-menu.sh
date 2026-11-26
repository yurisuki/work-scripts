#!/usr/bin/env bash
# Choose the default audio output device in rofi (SUPER+ú).
set -euo pipefail

rofi_menu() { rofi -no-config -theme "$HOME/.config/rofi/violet-night-dialog.rasi" "$@"; }

sinks_json=$(pactl -f json list sinks 2>/dev/null) || exit 0
mapfile -t labels < <(jq -r '.[] | ((.description | select(type=="string" and . != "" and . != "(null)")) // (.properties["device.description"] | select(type=="string" and . != "" and . != "(null)")) // .name // "Unknown output")' <<< "$sinks_json")
[[ ${#labels[@]} -gt 0 ]] || exit 0

index=$(printf '%s\n' "${labels[@]}" | rofi_menu -dmenu -i -format i -p 'Audio output') || exit 0
[[ $index =~ ^[0-9]+$ ]] || exit 0
[[ $index -lt ${#labels[@]} ]] || exit 0

name=$(jq -r --argjson i "$index" '.[$i].name' <<< "$sinks_json")
label=${labels[$index]}
port=$(jq -r --argjson i "$index" '.[$i].active_port // ""' <<< "$sinks_json")
[[ -n $name && $name != null ]] || exit 0

pactl set-default-sink "$name"

icon=0
if [[ $name == bluez* ]]; then
    icon=2
elif [[ ${name,,} == *headphone* || ${port,,} == *headphone* ]]; then
    icon=1
fi
python3 "$HOME/.scripts/hypr-osd.py" --output "$icon" "$label" >/dev/null 2>&1 &
