#!/bin/bash

# rtemplate - Professional template management tool using rofi
# Made by: yurisuki

CONFIG_FILE="$HOME/Dokumenty/Ralakde/Zoho WorkDrive (Ralakde)/My Folders/rtemplate list"

# Function to create the config directory and default config if it doesn't exist
function setup_config {
    if [ ! -d "$(dirname "$CONFIG_FILE")" ]; then
        mkdir -p "$(dirname "$CONFIG_FILE")"
    fi
    
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "# rtemplate configuration file" > "$CONFIG_FILE"
        echo "# Format: TEMPLATE_NAME || TEMPLATE_CONTENT" >> "$CONFIG_FILE"
        echo "⚙️ || manage_templates" >> "$CONFIG_FILE"
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
    
    echo "$content"
}

# Function to manage templates (add/remove/edit)
function manage_templates {
    local options=("➕ Add new template" "✏️ Edit template" "➖ Remove template" "↩️ Back")
    local choice=$(printf "%s\n" "${options[@]}" | rofi -dmenu -i -p "⚙️ Template Management:")
    
    case "$choice" in
        "➕ Add new template")
            add_template
            ;;
        "✏️ Edit template")
            edit_template
            ;;
        "➖ Remove template")
            remove_template
            ;;
        *)
            # Back or cancelled
            return
            ;;
    esac
}

# Function to add a new template
function add_template {
    local template_name=$(rofi -dmenu -p "✨ Template name:")
    [ -z "$template_name" ] && return
    
    # Use multi-line rofi input for content
    local template_content=$(rofi -dmenu -p "📝 Template content (use \$DATE, \$TIME, \$DATETIME as variables):" -l 0 -multi-select)
    [ -z "$template_content" ] && return
    
    # Escape newlines for storage
    template_content="${template_content//$'\n'/\\n}"
    
    echo "$template_name || $template_content" >> "$CONFIG_FILE"
    notify-send "📋 rtemplate" "Added new template: $template_name"
}

# Function to edit an existing template
function edit_template {
    # Read templates from config file
    local templates=()
    local template_names=()
    while IFS= read -r line; do
        # Skip empty lines, comments, or the management entry
        [[ -z "$line" || "$line" =~ ^# || "$line" =~ "⚙️ ||" ]] && continue
        
        # Get just the template name (before the ||)
        template_name="${line%% || *}"
        template_names+=("$template_name")
        templates+=("$line")
    done < "$CONFIG_FILE"
    
    # Display just template names in rofi for selection
    local choice=$(printf "%s\n" "${template_names[@]}" | rofi -dmenu -i -p "✏️ Select template to edit:")
    
    # If no selection, return
    [ -z "$choice" ] && return
    
    # Find the selected template's content
    local template_content=""
    for i in "${!template_names[@]}"; do
        if [[ "${template_names[$i]}" == "$choice" ]]; then
            template_content="${templates[$i]#* || }"
            break
        fi
    done
    
    # If special management content, return
    [[ "$template_content" == "manage_templates" ]] && return
    
    # Convert escaped newlines back for editing
    template_content="${template_content//\\n/$'\n'}"
    
    # Edit the content
    local new_content=$(echo -e "$template_content" | rofi -dmenu -p "✏️ Edit template content:" -l 0 -multi-select)
    
    # If cancelled, return
    [ -z "$new_content" ] && return
    
    # Escape newlines for storage
    new_content="${new_content//$'\n'/\\n}"
    
    # Create a temporary file
    temp_file=$(mktemp)
    
    # Create the new line with the updated content
    local new_line="$choice || $new_content"
    
    # Copy all lines, replacing the edited one
    while IFS= read -r line; do
        if [[ "${line%% || *}" == "$choice" ]]; then
            echo "$new_line" >> "$temp_file"
        else
            echo "$line" >> "$temp_file"
        fi
    done < "$CONFIG_FILE"
    
    # Replace the original file
    mv "$temp_file" "$CONFIG_FILE"
    
    notify-send "📋 rtemplate" "Updated template: $choice"
}

# Function to remove a template
function remove_template {
    # Read templates from config file
    local templates=()
    local template_names=()
    while IFS= read -r line; do
        # Skip empty lines, comments, or the management entry
        [[ -z "$line" || "$line" =~ ^# || "$line" =~ "⚙️ ||" ]] && continue
        
        # Get just the template name (before the ||)
        template_name="${line%% || *}"
        template_names+=("$template_name")
        templates+=("$line")
    done < "$CONFIG_FILE"
    
    # Display just template names in rofi for removal
    local choice=$(printf "%s\n" "${template_names[@]}" | rofi -dmenu -i -p "🗑️ Select template to remove:")
    
    # If no selection, return
    [ -z "$choice" ] && return
    
    # Find the full line to remove based on the name
    local line_to_remove=""
    for i in "${!template_names[@]}"; do
        if [[ "${template_names[$i]}" == "$choice" ]]; then
            line_to_remove="${templates[$i]}"
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
    
    notify-send "📋 rtemplate" "Removed template: $choice"
}

# Main function
function main {
    # Ensure config exists
    setup_config
    
    # Parse templates from config file
    declare -a template_names=()
    declare -a template_contents=()
    
    while IFS= read -r line; do
        # Skip empty lines or lines starting with #
        [[ -z "$line" || "$line" =~ ^# ]] && continue
        
        # Split the line by " || "
        name="${line%% || *}"
        content="${line#* || }"
        
        # Add to arrays
        template_names+=("$name")
        template_contents+=("$content")
        
    done < "$CONFIG_FILE"
    
    # Use rofi to get user selection
    local selection=$(printf "%s\n" "${template_names[@]}" | rofi -dmenu -i -p "📋 Template:")
    
    # Check if the user pressed ESC
    [ -z "$selection" ] && exit 0
    
    # Check if management option was selected
    if [[ "$selection" == "⚙️" ]]; then
        manage_templates
        main  # Return to main menu after management
        return
    fi
    
    # Find the selected template's content
    local selected_content=""
    for i in "${!template_names[@]}"; do
        if [[ "${template_names[$i]}" == "$selection" ]]; then
            selected_content="${template_contents[$i]}"
            break
        fi
    done
    
    # If special manager content, handle it
    if [[ "$selected_content" == "manage_templates" ]]; then
        manage_templates
        main  # Return to main menu after management
        return
    fi
    
    # Process template variables
    local processed_content=$(process_template "$selected_content")
    
    # Copy to clipboard
    if copy_to_clipboard "$processed_content"; then
        notify-send "📋 rtemplate" "Copied template to clipboard: $selection"
    fi
}

# Run the main function
main

exit 0
