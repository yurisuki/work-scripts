#!/usr/bin/env bash
set -euo pipefail
input=${1:?PDF path required}
input=${input#\"}
input=${input%\"}
input=${input#\'}
input=${input%\'}
[[ -f $input ]] || exit 2
brave --new-window "file://$input" >/dev/null 2>&1 &
