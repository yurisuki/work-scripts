#!/usr/bin/env bash
# Keep Waybar alive for this compositor session and retain startup errors.
set -uo pipefail
[[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]] || exit 0
exec 9>"${XDG_RUNTIME_DIR:?}/violet-waybar.lock"
flock -n 9 || exit 0
log_dir="${XDG_STATE_HOME:-$HOME/.local/state}/waybar"
mkdir -p "$log_dir"
[[ ! -f "$log_dir/session.log" ]] || mv -f "$log_dir/session.log" "$log_dir/session.previous.log"
exec >>"$log_dir/session.log" 2>&1
bar_pid=
cleanup() {
    trap - EXIT INT TERM
    if [[ -n $bar_pid ]]; then
        kill "$bar_pid" 2>/dev/null || true
        wait "$bar_pid" 2>/dev/null || true
    fi
}
trap cleanup EXIT
trap 'exit 0' INT TERM
while hyprctl -j monitors >/dev/null 2>&1; do
    printf '\n[%s] Starting Waybar\n' "$(date --iso-8601=seconds)"
    "$HOME/.scripts/bar-start.py" 9>&- &
    bar_pid=$!
    wait "$bar_pid"
    status=$?
    bar_pid=
    printf '[%s] Waybar exited with status %s; retrying in 3 seconds\n' "$(date --iso-8601=seconds)" "$status"
    sleep 3
done
