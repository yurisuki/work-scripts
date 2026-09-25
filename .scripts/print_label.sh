#!/usr/bin/env bash
set -euo pipefail
file=$(zenity --file-selection --title='Select PDF to print') || exit 0
[[ -f "$file" ]] || exit 1
printer=${LABEL_PRINTER:-GK420d}
if ! lpstat -p "$printer" >/dev/null 2>&1; then
    zenity --error --text="Configure printer $printer in CUPS first (or set LABEL_PRINTER)."
    exit 1
fi
output=$(mktemp --suffix=.pdf)
trap 'rm -f -- "$output"' EXIT
gs -o "$output" -sDEVICE=pdfwrite -dFirstPage=1 -dLastPage=1 \
    -c '[/CropBox [50 50 450 650] /PAGES pdfmark' -f "$file"
[[ -s "$output" ]]
lp -d "$printer" -o media=Custom.100x150mm -o fit-to-page "$output"
notify-send 'Label printing' "Sent to $printer"
