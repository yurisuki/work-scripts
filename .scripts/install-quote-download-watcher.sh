#!/usr/bin/env bash
set -euo pipefail
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
unit_dir="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
download_dir=$(xdg-user-dir DOWNLOAD)
mkdir -p "$unit_dir" "$download_dir"
python3 - "$script_dir" "$unit_dir" "$download_dir" <<'PY'
from pathlib import Path
import sys
source, destination, downloads = map(Path, sys.argv[1:])
def escape(value):
    return str(value).replace('\\', '\\\\').replace('"', '\\"').replace('%', '%%')
for unit in ('service', 'path'):
    text = (source / 'systemd' / f'quote-download-watcher.{unit}').read_text()
    text = text.replace('@SCRIPT_PATH@', escape(source / 'quote-download-watcher.sh'))
    text = text.replace('@DOWNLOAD_PATH@', escape(downloads))
    (destination / f'quote-download-watcher.{unit}').write_text(text)
PY
systemctl --user daemon-reload
systemctl --user enable --now quote-download-watcher.path
