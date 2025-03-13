#!/bin/bash

# Set the output directory
output_dir=~/Dokumenty/Ralakde/temp

# Create the directory if it doesn't exist
mkdir -p "$output_dir"

# Use Zenity to choose the PDF file
file=$(zenity --file-selection --title="Select PDF to print")

# Check if file is selected
if [ -z "$file" ]; then
  zenity --error --text="No file selected. Exiting."
  exit 1
fi

# Temporary output file in the specified directory
output_pdf="$output_dir/output.pdf"

# Crop settings for 10x15 cm label (converted to points: 1 inch = 72 points)
# 10x15 cm = 283.5x425.25 points
crop_box="[50 50 450 650]"  # Adjust this if needed

# Use Ghostscript to crop and extract the first page with the custom crop box
gs -o "$output_pdf" -sDEVICE=pdfwrite -dFirstPage=1 -dLastPage=1 -c "[/CropBox $crop_box /PAGES pdfmark" -f "$file"

# Ensure the output is a valid PDF by checking if it's not empty
if [ ! -s "$output_pdf" ]; then
  zenity --error --text="Failed to create the cropped PDF. Exiting."
  exit 1
fi

# Now, print the cropped label (10x15 cm) to the GK420d printer
lp -d GK420d -o media=Custom.100x150mm -o fit-to-page "$output_pdf"

# Notify the user
zenity --info --text="Printing complete!"
