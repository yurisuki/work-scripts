#!/bin/bash

# Define paths
TEMPLATE="$HOME/Dokumenty/Ralakde/Our inquires/!1Inquiry template.xlsx"
BASE_DIR="$HOME/Dokumenty/Ralakde/Our inquires"

# Get current month name
MONTH=$(date +%B)
MONTH_DIR="$BASE_DIR/$MONTH"

# Create month folder if it doesn't exist
mkdir -p "$MONTH_DIR"

# Ask user for the recipient's name
INQUIRY_PERSON=$(zenity --entry --title="New Inquiry" --text="Enter the recipient's name:")

# Exit if no name is entered
if [ -z "$INQUIRY_PERSON" ]; then
    zenity --error --title="Error" --text="No name entered. Exiting."
    exit 1
fi

# Define base new file path
NEW_FILE="$MONTH_DIR/$INQUIRY_PERSON inquiry.xlsx"

# Check if the file already exists and append a number to the filename
COUNTER=1
while [ -f "$NEW_FILE" ]; do
    NEW_FILE="$MONTH_DIR/$INQUIRY_PERSON inquiry ($COUNTER).xlsx"
    COUNTER=$((COUNTER + 1))
done

# Copy the template
cp "$TEMPLATE" "$NEW_FILE"

# Replace the name in cell D1 using Python script
python3 - <<EOF
import openpyxl

# Load the Excel file
file_path = "$NEW_FILE"
wb = openpyxl.load_workbook(file_path)

# Select the active sheet (or specify a sheet by name: wb['Sheet1'])
sheet = wb.active

# Replace the value in D1 with the recipient's name
sheet['D1'] = "$INQUIRY_PERSON"

# Save the workbook with the updated value
wb.save(file_path)
EOF

# Open the newly created file in OnlyOffice (or the default spreadsheet application) in the background
xdg-open "$NEW_FILE" &

# Notify user
notify-send "Success" "Inquiry file created and name replaced in D1:\n$NEW_FILE"

# Ensure the terminal stays open for a bit
sleep 5
