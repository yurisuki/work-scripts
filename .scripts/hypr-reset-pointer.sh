#!/usr/bin/env bash
set -euo pipefail

# Recover both halves of the ThinkPad pointer without restarting the session.
exec 9>"${XDG_RUNTIME_DIR:?}/hypr-reset-pointer.lock"
flock -n 9 || exit 0

state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/hypr-pointer"
mkdir -p "$state_dir"
chmod 700 "$state_dir"
{
    date --iso-8601=seconds
    hyprctl version
    hyprctl devices
    # Keep input diagnostics, excluding application/window information.
    hyprctl rollinglog | rg -i 'libinput|held.button|sendButton|\[seatmgr\]' | tail -250 || true
} >"$state_dir/last-reset.log" 2>&1

restore() {
    hyprctl eval 'hl.device({name="synaptics-tm3381-002", enabled=true})' >/dev/null
    hyprctl eval 'hl.device({name="tpps/2-elan-trackpoint", enabled=true})' >/dev/null
}
trap restore EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
hyprctl eval 'hl.device({name="synaptics-tm3381-002", enabled=false})' >/dev/null
hyprctl eval 'hl.device({name="tpps/2-elan-trackpoint", enabled=false})' >/dev/null
sleep 0.3
restore
trap - EXIT
