#!/bin/bash

TARGET_DIR="$HOME/Dokumenty/Ralakde/1!QUOTES"
LAST_PDF_FILE="/tmp/lastpdf"

notify_error() {
	notify-send -i error -a "move_and_open" "$1"
	echo "Error: $1"
	exit 1
}

mkdir -p "$TARGET_DIR"

# If no arguments, open last PDF if it exists
if [[ $# -eq 0 ]]; then
	if [[ -f "$LAST_PDF_FILE" ]]; then
		LAST_FILE=$(cat "$LAST_PDF_FILE")
		if [[ -f "$LAST_FILE" ]]; then
			echo "Opening PDF: $(basename "$LAST_FILE")"
			xdg-open "$LAST_FILE"
			exit 0
		else
			notify_error "Last moved QUOTE not found."
		fi
	else
		notify_error "No recent downloaded QUOTE."
	fi
fi

PDF_FILE="$1"
BASENAME=$(basename "$PDF_FILE")
if [[ ! -f "$PDF_FILE" || ! "$BASENAME" =~ ^QT-.*\.pdf$ ]]; then
	notify_error "File does not exist or its name does not start with QT-"
fi

mv "$PDF_FILE" "$TARGET_DIR/" || notify_error "Failed to move file."
MOVED_FILE="$TARGET_DIR/$BASENAME"
echo "$MOVED_FILE" > "$LAST_PDF_FILE"
echo "Moved: $MOVED_FILE"
