#!/usr/bin/env bash
# Grab superfile's selected file(s) and attach them to the pointer as a drag.
set -uo pipefail

scripts="$HOME/.scripts"
helper="$scripts/superfile-drag.py"
icon="$HOME/.local/share/device-notifications/icons/clipboard.svg"

notify() {
    notify-send --app-name=Superfile --icon="$icon" --expire-time=2500 \
        --hint=boolean:suppress-sound:true "$1" "$2" 2>/dev/null || true
}

# Called directly by superfile as its "editor": $1 is the selected path.
# Directories still open in the real editor (needed by E / open_current_directory_with_editor).
if (( $# > 0 )); then
    if [[ -d ${1:-} ]]; then
        # Match superfile's previous default dir_editor (vi on Linux).
        exec vi "$@"
    fi
    printf '%s\n' "$@" | nohup python3 "$helper" >/dev/null 2>&1 &
    exit 0
fi

# Also detect superfile launched from a plain terminal (window title says kitty).
has_spf_child() {
    local parent=$1 depth=$2 child command
    (( depth > 3 )) && return 1
    while read -r child; do
        [[ -n $child ]] || continue
        command=$(ps -p "$child" -o comm= 2>/dev/null || true)
        [[ ${command,,} == spf || ${command,,} == superfile ]] && return 0
        has_spf_child "$child" "$((depth + 1))" && return 0
    done < <(pgrep -P "$parent" 2>/dev/null || true)
    return 1
}

window=$(hyprctl activewindow -j 2>/dev/null || true)
klass=$(printf '%s' "$window" | jq -r '.class // empty' 2>/dev/null || true)
title=$(printf '%s' "$window" | jq -r '.title // empty' 2>/dev/null || true)
pid=$(printf '%s' "$window" | jq -r '.pid // empty' 2>/dev/null || true)
address=$(printf '%s' "$window" | jq -r '.address // empty' 2>/dev/null || true)
if [[ ${klass,,} != *superfile* && ${title,,} != *superfile* ]] &&
   { [[ -z $pid ]] || ! has_spf_child "$pid" 0; }; then
    notify 'Drag not started' 'Focus a superfile window first.'
    exit 1
fi

# Save the clipboard so it can be restored after reading superfile's selection.
mime=''
backup=$(mktemp)
if mime=$(wl-paste --list-types 2>/dev/null | head -1); then
    if [[ -n $mime ]]; then
        wl-paste --type "$mime" >"$backup" 2>/dev/null || mime=''
    fi
fi

# superfile's Y hotkey copies the selected path(s) to the clipboard.
wtype Y
sleep 0.5
selection=$(wl-paste --type text/plain 2>/dev/null | sed '/^[[:space:]]*$/d' || true)

if [[ -n $mime && -s $backup ]]; then
    wl-copy --type "$mime" <"$backup" 2>/dev/null || true
fi
rm -f -- "$backup"

if [[ -z $selection ]]; then
    notify 'Drag not started' 'No selected file found in superfile.'
    exit 1
fi

printf '%s\n' "$selection" | python3 "$helper" &
helper_pid=$!
sleep 0.4
# The helper's tiny GTK window briefly takes focus; put it back on superfile.
if [[ -n $address ]]; then
    hyprctl dispatch "hl.dsp.focus({window=\"address:$address\"})" >/dev/null 2>&1 || true
fi
if ! wait "$helper_pid"; then
    notify 'Drag failed' 'Could not start the file drag.'
    exit 1
fi
