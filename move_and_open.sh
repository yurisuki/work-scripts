#!/bin/bash

# Path to the target directory
TARGET_DIR="$HOME/Dokumenty/Ralakde/1!QUOTES"

# Ensure the target directory exists
mkdir -p "$TARGET_DIR"

# Temporary file to store the last moved PDF file
LAST_PDF_FILE="/tmp/lastpdf"

# Flag for opening the file
OPEN_FILE=false

# Parse command-line options
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    -o|--open) OPEN_FILE=true; shift ;;
    *) PDF_FILE="$1"; shift ;;
  esac
done

# If no PDF file is provided, check if /tmp/lastpdf exists and open it
if [[ -z "$PDF_FILE" && -f "$LAST_PDF_FILE" ]]; then
  LAST_FILE=$(cat "$LAST_PDF_FILE")
  xdg-open "$LAST_FILE"
  echo "Opening the last moved PDF: $LAST_FILE"
  exit 0
fi

# Check if the file exists and starts with QT-
if [[ -f "$PDF_FILE" && "$(basename "$PDF_FILE")" == QT-*.pdf ]]; then
  # Move the file to the target directory
  mv "$PDF_FILE" "$TARGET_DIR"
  echo "File $(basename "$PDF_FILE") has been moved to $TARGET_DIR"

  # Save the moved file's path to /tmp/lastpdf
  echo "$TARGET_DIR/$(basename "$PDF_FILE")" > "$LAST_PDF_FILE"

  # If the open flag is set, open the file
  if $OPEN_FILE; then
    xdg-open "$TARGET_DIR/$(basename "$PDF_FILE")"
    echo "File $(basename "$PDF_FILE") has been opened."
  fi
else
  echo "Error: File does not exist or its name does not start with QT-"
  exit 1
fi
