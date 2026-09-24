#!/bin/bash

# rtemplate - Professional template management tool using rofi
# Made by: yurisuki

# Templates directory - where all template files will be stored
TEMPLATES_DIR="$HOME/Dokumenty/Ralakde/Zoho WorkDrive (Ralakde)/My Folders/rtemplate list"

# Function to get current clipboard content
function get_clipboard_content {
    # Try Wayland clipboard tools first
    if [ -n "$WAYLAND_DISPLAY" ]; then
        if command -v wl-paste &> /dev/null; then
            wl-paste 2>/dev/null && return
        fi
    fi
    
    # Fall back to xclip/xsel (for Xorg)
    if command -v xclip &> /dev/null; then
        xclip -selection clipboard -o 2>/dev/null && return
    elif command -v xsel &> /dev/null; then
        xsel -b 2>/dev/null && return
    fi
    
    # Return empty string if no clipboard utility found
    echo ""
}

# Get current clipboard content
CLIPBOARD=$(get_clipboard_content)

# Function to ensure the templates directory exists
function setup_templates_dir {
    if [ ! -d "$TEMPLATES_DIR" ]; then
        mkdir -p "$TEMPLATES_DIR"
        # Create a sample template if directory is new
        echo "This is a sample template.
You can create more templates by adding files to the $TEMPLATES_DIR directory.

The filename will be used as the template name in rofi.
The file contents (like this text) will be copied to clipboard when selected." > "$TEMPLATES_DIR/📝 Sample Template"
        
        echo "# Instructions for Templates

1. Create a new file in this directory
2. The filename will be shown in rofi
3. The file contents will be copied to clipboard when selected
4. You can use the following variables in your templates:
   - \$DATE - Current date (YYYY-MM-DD)
   - \$TIME - Current time (HH:MM)
   - \$DATETIME - Current date and time (YYYY-MM-DD HH:MM)
   - \$CLIPBOARD - Content of your clipboard when script is executed" > "$TEMPLATES_DIR/ℹ️ Instructions"
    fi
}

# Function to copy text to clipboard - works with both Wayland and Xorg
function copy_to_clipboard {
    # First try Wayland clipboard tools
    if [ -n "$WAYLAND_DISPLAY" ]; then
        if command -v wl-copy &> /dev/null; then
            echo -e "$1" | wl-copy
            return
        fi
    fi
    
    # Fall back to xclip/xsel (for Xorg)
    if command -v xclip &> /dev/null; then
        echo -e "$1" | xclip -selection clipboard
    elif command -v xsel &> /dev/null; then
        echo -e "$1" | xsel -ib
    else
        notify-send "❌ rtemplate" "No clipboard utility found. Please install wl-copy (Wayland) or xclip/xsel (Xorg)."
        return 1
    fi
}

# Function to replace template variables
function process_template {
    local content="$1"
    
    # Replace common variables
    local date_now=$(date +"%Y-%m-%d")
    local time_now=$(date +"%H:%M")
    local datetime_now=$(date +"%Y-%m-%d %H:%M")
    
    # Replace $DATE, $TIME, and $DATETIME with actual values
    content="${content//\$DATE/$date_now}"
    content="${content//\$TIME/$time_now}"
    content="${content//\$DATETIME/$datetime_now}"
    content="${content//\$CLIPBOARD/$CLIPBOARD}"
    
    echo "$content"
}

# Function to manage templates
function manage_templates {
    local options=("📂 Open templates folder" "↩️ Back")
    local choice=$(printf "%s\n" "${options[@]}" | rofi -dmenu -i -p "⚙️ Template Management:")

    case "$choice" in
        "📂 Open templates folder")
            open_templates_folder
            ;;
        *)
            # Back or cancelled
            return
            ;;
    esac
}

# Function to open the templates folder
function open_templates_folder {
    xdg-open "$TEMPLATES_DIR" &
    notify-send "📋 rtemplate" "Opening templates folder"
    exit 0
}

# Main function
function main {
    # Ensure templates directory exists
    setup_templates_dir
    
    # Special option for managing templates
    local templates=("⚙️")
    local template_paths=()
    
    # Get list of template files with proper handling of spaces in filenames
    while IFS= read -r -d '' file; do
        templates+=("$(basename "$file")")
        template_paths+=("$file")
    done < <(find "$TEMPLATES_DIR" -type f -print0 | sort -z)
    
    # Create a menu text with newlines between entries
    local menu_text=""
    for template in "${templates[@]}"; do
        menu_text+="$template"$'\n'
    done
    menu_text=${menu_text%$'\n'} # Remove trailing newline to fix empty line in rofi
    
    # Use rofi to get user selection
    local selection=$(echo -e "$menu_text" | rofi -dmenu -i -p "📋 Template:")
    
    # Check if the user pressed ESC
    [ -z "$selection" ] && exit 0
    
    # Check if management option was selected
    if [[ "$selection" == "⚙️" ]]; then
        manage_templates
        main  # Return to main menu after management
        return
    fi
    
    # Find the corresponding path for the selected template
    local template_path=""
    for i in "${!templates[@]}"; do
        if [[ "${templates[$i]}" == "$selection" ]]; then
            if [ $i -eq 0 ]; then
                # This is the "Manage Templates" option, which doesn't have a path
                template_path=""
            else
                template_path="${template_paths[$i-1]}"  # Adjust index for the template_paths array
            fi
            break
        fi
    done
    
    if [ -f "$template_path" ]; then
        # Read the file content
        local content=$(cat "$template_path")
        
        # Process template variables
        local processed_content=$(process_template "$content")
        
        # Copy to clipboard
        if copy_to_clipboard "$processed_content"; then
            notify-send "📋 rtemplate" "Copied template to clipboard: $selection"
        fi
    else
        notify-send "❌ rtemplate" "Template file not found: $selection"
    fi
}

# Run the main function
main

exit 0
