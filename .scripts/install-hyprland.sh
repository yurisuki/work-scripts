#!/usr/bin/env bash
# Compatibility entry point; use the one shared installer from the checkout.
set -euo pipefail
source_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
[[ -f "$source_dir/install/deploy.py" ]] || { echo 'Run install.sh from the cloned work-scripts repository.' >&2; exit 1; }
exec bash "$source_dir/install.sh" "$@"
