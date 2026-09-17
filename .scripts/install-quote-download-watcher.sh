#!/usr/bin/env bash
# Installs and starts the per-user watcher from this checkout.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
UNIT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
DOWNLOAD_DIR="$(xdg-user-dir DOWNLOAD)"

mkdir -p "$UNIT_DIR"
sed "s|@SCRIPT_PATH@|$SCRIPT_DIR/quote-download-watcher.sh|" \
	"$SCRIPT_DIR/systemd/quote-download-watcher.service" > "$UNIT_DIR/quote-download-watcher.service"
sed "s|@DOWNLOAD_PATH@|$DOWNLOAD_DIR|" \
	"$SCRIPT_DIR/systemd/quote-download-watcher.path" > "$UNIT_DIR/quote-download-watcher.path"

systemctl --user daemon-reload
systemctl --user enable --now quote-download-watcher.path
systemctl --user start quote-download-watcher.service
systemctl --user status quote-download-watcher.path --no-pager
