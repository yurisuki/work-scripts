#!/usr/bin/env bash
set -euo pipefail
export PATH="$HOME/.local/bin:$PATH"
unset LC_ALL
export LC_TIME="${LC_TIME:-${LANG:-C.UTF-8}}"
exec kitty --class calcure --title Calcure -e calcure
