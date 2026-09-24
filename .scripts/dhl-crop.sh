#!/bin/bash

# Set the output directory
output_dir=~/Dokumenty/Ralakde/temp

# Create the directory if it doesn't exist
mkdir -p "$output_dir"

# Use Zenity to choose the PDF file
file=$(zenity --file-selection --title="Select DHL label PDF to crop")

# Check if file is selected
if [ -z "$file" ]; then
    notify-send -a "dhl-crop" -u critical "No file selected. Exiting."
    exit 1
fi

# Temporary output file in the specified directory
output_pdf="$output_dir/output.pdf"

# Use dhl-crop to crop and extract the first page with the custom crop box
${HOME}/.scripts/dhl-crop.py "$file" -o "$output_pdf"

# Ensure the output is a valid PDF by checking if it's not empty
if [ ! -s "$output_pdf" ]; then
    notify-send -a "dhl-crop" -u critical "Failed to create the cropped PDF. Exiting."
    exit 1
fi

# Now, print the cropped label (10x15 cm) to the GK420d printer
xdg-open "$output_pdf"

# Notify the user
notify-send -a "dhl-crop" "Cropped!" "Opening PDF file."


