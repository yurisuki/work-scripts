#!/usr/bin/env bash
set -euo pipefail
script="$HOME/Dokumenty/Ralakde/Zoho WorkDrive (Ralakde)/My Folders/Search stock tool/search_stock_V1_PRO.py"
if [[ ! -f "$script" ]]; then
    zenity --error --text='Sign in to Zoho WorkDrive and sync the Search stock tool first.'
    exit 1
fi
exec python3 "$script"
