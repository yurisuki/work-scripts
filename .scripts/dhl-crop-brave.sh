#!/usr/bin/env bash
set -euo pipefail

input=${1:?PDF path required}
input=${input#\"}
input=${input%\"}
input=${input#\'}
input=${input%\'}
[[ -f $input && ${input,,} == *.pdf ]] || exit 2
runtime=${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}
output=$(mktemp "$runtime/dhl-cropped-XXXXXX.pdf")
cleanup() { rm -f -- "$output"; }
trap cleanup EXIT

"$HOME/.scripts/dhl-crop.py" "$input" -o "$output" >/dev/null
[[ -s $output ]] || exit 1
brave --new-window "$output" >/dev/null 2>&1 &
browser_pid=$!
wait "$browser_pid" || true
