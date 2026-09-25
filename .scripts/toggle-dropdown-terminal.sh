#!/usr/bin/env bash
set -euo pipefail
dropdown_address=$(hyprctl clients -j | jq -r '.[] | select(.class == "dropdown-terminal") | .address' | head -n1)
if [[ -n "$dropdown_address" && "$dropdown_address" != "null" ]]; then
    hyprctl dispatch "hl.dsp.window.close({ window = 'address:$dropdown_address' })" >/dev/null
else
    kitty --class dropdown-terminal --title dropdown-terminal >/dev/null 2>&1 &
    disown
fi
