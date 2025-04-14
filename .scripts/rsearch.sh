#!/bin/bash

# rsearch - Professional multi-engine search tool using rofi
# Made by: yurisuki

CONFIG_FILE="$HOME/Dokumenty/Ralakde/Zoho WorkDrive (Ralakde)/My Folders/rseach list"
BROWSER=${BROWSER:-firefox}

# Function to create the config directory and default config if it doesn't exist
function setup_config {
    if [ ! -d "$(dirname "$CONFIG_FILE")" ]; then
        mkdir -p "$(dirname "$CONFIG_FILE")"
    fi
    
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "# rsearch configuration file" > "$CONFIG_FILE"
        echo "# Format: ENGINE_NAME || https://search.engine.url?q=\$Q" >> "$CONFIG_FILE"
        echo "⚙️ || manage_engines" >> "$CONFIG_FILE"
        echo "💎 ZIA || https://search.zoho.eu/searchhome?q=$Q&s=all%20apps" >> "$CONFIG_FILE"
        echo "🔍 GOOGLE || https://www.google.com/search?q=\$Q" >> "$CONFIG_FILE"
    fi
}

# Function to encode the query for URL
function url_encode {
    echo "$1" | sed -e 's/ /%20/g' -e 's/&/%26/g' -e 's/\?/%3F/g' -e 's/=/%3D/g' -e 's/+/%2B/g' -e 's/#/%23/g' -e 's/:/%3A/g' -e 's/\//%2F/g' -e 's/\\/%5C/g'
}

# Function to manage engines (add/remove)
function manage_engines {
    local options=("➕ Add new engine" "➖ Remove engine" "↩️ Back")
    local choice=$(printf "%s\n" "${options[@]}" | rofi -dmenu -i -p "⚙️ Engine Management:")
    
    case "$choice" in
        "➕ Add new engine")
            add_engine
            ;;
        "➖ Remove engine")
            remove_engine
            ;;
        *)
            # Back or cancelled
            return
            ;;
    esac
}

# Function to add a new search engine
function add_engine {
    local engine_name=$(rofi -dmenu -p "✨ Engine name:")
    [ -z "$engine_name" ] && return
    
    local engine_url=$(rofi -dmenu -p "🔗 URL (use \$Q for query):")
    [ -z "$engine_url" ] && return
    
    echo "$engine_name || $engine_url" >> "$CONFIG_FILE"
    notify-send "🚀 rsearch" "Added new search engine: $engine_name"
}

# Function to remove a search engine
function remove_engine {
    # Read engines from config file
    local engines=()
    local engine_names=()
    while IFS= read -r line; do
        # Skip empty lines, comments, or the management entry
        [[ -z "$line" || "$line" =~ ^# || "$line" =~ "⚙️ ||" ]] && continue
        
        # Get just the engine name (before the ||)
        engine_name="${line%% || *}"
        engine_names+=("$engine_name")
        engines+=("$line")
    done < "$CONFIG_FILE"
    
    # Display just engine names in rofi for removal
    local choice=$(printf "%s\n" "${engine_names[@]}" | rofi -dmenu -i -p "🗑️ Select engine to remove:")
    
    # If no selection, return
    [ -z "$choice" ] && return
    
    # Find the full line to remove based on the name
    local line_to_remove=""
    for i in "${!engine_names[@]}"; do
        if [[ "${engine_names[$i]}" == "$choice" ]]; then
            line_to_remove="${engines[$i]}"
            break
        fi
    done
    
    # If no line found, return
    [ -z "$line_to_remove" ] && return
    
    # Create a temporary file
    temp_file=$(mktemp)
    
    # Copy all lines except the one to remove
    while IFS= read -r line; do
        if [[ "$line" != "$line_to_remove" ]]; then
            echo "$line" >> "$temp_file"
        fi
    done < "$CONFIG_FILE"
    
    # Replace the original file
    mv "$temp_file" "$CONFIG_FILE"
    
    notify-send "🚀 rsearch" "Removed search engine: $choice"
}

# Function to perform search with all engines
function search_all_engines {
    local query="$1"
    local encoded_query=$(url_encode "$query")
    
    # Get all URLs from config file
    local all_urls=()
    
    while IFS= read -r line; do
        # Skip empty lines, comments, or the management entry
        [[ -z "$line" || "$line" =~ ^# || "$line" =~ "⚙️ ||" ]] && continue
        
        # Get search URL
        search_url="${line#* || }"
        
        # Skip if it's not a real URL
        [[ "$search_url" == "manage_engines" ]] && continue
        
        # Replace $Q with the encoded query
        search_url="${search_url//\$Q/$encoded_query}"
        
        all_urls+=("$search_url")
        
    done < "$CONFIG_FILE"
    
    # Open all URLs in one browser window with multiple tabs
    if [[ ${#all_urls[@]} -gt 0 ]]; then
        if [[ "$BROWSER" == "firefox" ]]; then
            # For Firefox, open first URL in new window
            $BROWSER --new-window "${all_urls[0]}" &
            
            # Wait for Firefox to open
            sleep 2
            
            # Send the rest of the URLs to the same Firefox instance
            if [[ ${#all_urls[@]} -gt 1 ]]; then
                for url in "${all_urls[@]:1}"; do
                    xdg-open "$url"
                    sleep 0.8
                done
            fi
            
        elif [[ "$BROWSER" == "google-chrome" || "$BROWSER" == "chromium" || "$BROWSER" == "brave-browser" ]]; then
            # For Chrome-based browsers, we can simply pass multiple URLs
            $BROWSER --new-window "${all_urls[@]}" &
            
        else
            # For other browsers, try using xdg-open for all URLs
            for url in "${all_urls[@]}"; do
                xdg-open "$url"
                sleep 0.8
            done
        fi
    fi
}

# Main function
function main {
    # Ensure config exists
    setup_config
    
    # Parse search engines from config file
    declare -a engines=()
    declare -a urls=()
    
    while IFS= read -r line; do
        # Skip empty lines or lines starting with #
        [[ -z "$line" || "$line" =~ ^# ]] && continue
        
        # Split the line by " || "
        engine_name="${line%% || *}"
        search_url="${line#* || }"
        
        # Add to arrays
        engines+=("$engine_name")
        urls+=("$search_url")
        
    done < "$CONFIG_FILE"
    
    # Use rofi to get user selection
    local selection=$(printf "%s\n" "${engines[@]}" | rofi -dmenu -i -p "🔎 Search:")
    
    # Check if the user pressed ESC
    [ -z "$selection" ] && exit 0
    
    # Check if management option was selected
    if [[ "$selection" == "⚙️" ]]; then
        manage_engines
        main  # Return to main menu after management
        return
    fi
    
    # Check if user directly entered a search query
    # (If selection doesn't match any engine name)
    is_query=true
    for engine in "${engines[@]}"; do
        if [[ "$selection" == "$engine" ]]; then
            is_query=false
            break
        fi
    done
    
    # If selection is a direct query, search with all engines
    if $is_query; then
        search_all_engines "$selection"
        exit 0
    fi
    
    # Find the selected engine's URL
    local selected_url=""
    for i in "${!engines[@]}"; do
        if [[ "${engines[$i]}" == "$selection" ]]; then
            selected_url="${urls[$i]}"
            break
        fi
    done
    
    # If special manager URL, handle it
    if [[ "$selected_url" == "manage_engines" ]]; then
        manage_engines
        main  # Return to main menu after management
        return
    fi
    
    # Get the search query
    local query=$(rofi -dmenu -p "🔎 Search $selection:")
    
    # Check if the user pressed ESC or provided empty input
    [ -z "$query" ] && exit 0
    
    # Encode the query
    local encoded_query=$(url_encode "$query")
    
    # Replace $Q with the encoded query
    local search_url="${selected_url//\$Q/$encoded_query}"
    
    # Open the URL in the default browser
    if [[ "$BROWSER" == "firefox" ]]; then
        $BROWSER --new-window "$search_url" &
    elif [[ "$BROWSER" == "google-chrome" || "$BROWSER" == "chromium" || "$BROWSER" == "brave-browser" ]]; then
        $BROWSER --new-window "$search_url" &
    else
        xdg-open "$search_url" &
    fi
}

# Run the main function
main

exit 0
