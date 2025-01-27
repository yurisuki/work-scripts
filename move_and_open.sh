#!/bin/bash

# Path to the target directory
TARGET_DIR="$HOME/Dokumenty/Ralakde/3!QUOTES"

# Ensure the target directory exists
mkdir -p "$TARGET_DIR"

# File provided as an argument
PDF_FILE="$1"

# Check if the file exists and starts with QT-
if [[ -f "$PDF_FILE" && "$(basename "$PDF_FILE")" == QT-*.pdf ]]; then
  # Move the file to the target directory
  mv "$PDF_FILE" "$TARGET_DIR"
  echo "File $(basename "$PDF_FILE") has been moved to $TARGET_DIR"
else
  echo "Error: File does not exist or its name does not start with QT-"
  exit 1
fi

