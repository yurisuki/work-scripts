#!/usr/bin/env bash
# Wait for lock-prime.sh to finish, then print one cached field.
# Music fields refresh live so playback controls stay current while locked.
set -uo pipefail

field=${1:-}
[[ -n $field ]] || exit 0
dir="${XDG_RUNTIME_DIR:-/tmp}/violet-lock-cache"

for _ in $(seq 1 200); do
    [[ -f $dir/ready ]] && break
    sleep 0.02
done

case $field in
    art)
        exec python3 "$HOME/.scripts/lock-music.py" art
        ;;
    music-*)
        exec python3 "$HOME/.scripts/lock-music.py" "${field#music-}"
        ;;
esac

[[ -f $dir/$field ]] && cat -- "$dir/$field"
