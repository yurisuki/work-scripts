#!/usr/bin/env bash
# Moves every completed QT-*.pdf download using move_and_open.sh.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DOWNLOAD_DIR="$(xdg-user-dir DOWNLOAD)"

shopt -s nullglob
for pdf_file in "$DOWNLOAD_DIR"/QT-*.pdf; do
	[[ -f "$pdf_file" ]] || continue
	"$SCRIPT_DIR/move_and_open.sh" "$pdf_file"
done
