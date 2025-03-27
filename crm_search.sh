#!/bin/bash

# This tool will search on ZOHO CRM.
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

# Build the Zoho CRM search URL
url="https://crm.zoho.eu/crm/search?searchword=$encoded_query&isRelevance=false"

# Open the URL in the default web browser
xdg-open "$url"
