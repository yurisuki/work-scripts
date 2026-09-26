#!/usr/bin/env bash

focused_json=$(hyprctl activewindow -j)

focused=$(jq -r '.address // empty' <<<"$focused_json")
workspace=$(jq -r '.workspace.id // empty' <<<"$focused_json")

[[ -z "$focused" || -z "$workspace" ]] && exit 1

largest=$(
    hyprctl clients -j | jq -r \
        --argjson ws "$workspace" \
        '
        [
            .[]
            | select(
                .workspace.id == $ws
                and .floating == false
                and .mapped == true
            )
        ]
        | max_by(.size[0] * .size[1])
        | .address // empty
        '
)

[[ -z "$largest" ]] && exit 1

# Already the largest window
[[ "$focused" == "$largest" ]] && exit 0

hyprctl dispatch "hl.dsp.window.swap({ target = \"address:$largest\" })"
