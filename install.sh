#!/usr/bin/env bash
set -euo pipefail
source_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# No flags opens the option menu; explicit flags keep working for scripts such as upd.sh.
if (( $# )); then
    exec bash "$source_dir/postinstall.sh" "$@"
fi
exec bash "$source_dir/install/tui.sh" "$source_dir"
