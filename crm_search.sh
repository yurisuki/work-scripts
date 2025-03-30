#!/bin/bash

# This tool will search on ZOHO ZIA.
# Requirements: rofi

# Use Rofi to get user input for the search query
query=$(rofi -dmenu -p "Enter search query:")

# Check if the user pressed ESC or provided empty input
if [ -z "$query" ]; then
    echo "No input provided. Exiting..."
    exit 1
fi

# Replace spaces with URL encoding for spaces (%20)
encoded_query=$(echo "$query" | sed 's/ /%20/g')

# Build the Zoho Zia search URL
url="https://search.zoho.eu/searchhome?q=$encoded_query&s=all%20apps"

# Open the URL in the default web browser
xdg-open "$url"
