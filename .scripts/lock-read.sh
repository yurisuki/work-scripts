#!/usr/bin/env bash
# Wait for lock-prime.sh to finish, then print one cached field.
set -uo pipefail

field=${1:-}
[[ -n $field ]] || exit 0
dir="${XDG_RUNTIME_DIR:-/tmp}/violet-lock-cache"

for _ in $(seq 1 200); do
    [[ -f $dir/ready ]] && break
    sleep 0.02
done
[[ -f $dir/$field ]] && cat -- "$dir/$field"
