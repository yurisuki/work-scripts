#!/bin/bash

# rtemplate - Professional template management tool using rofi
# Made by: yurisuki

# Templates directory - where all template files will be stored
TEMPLATES_DIR="$HOME/Dokumenty/Ralakde/Zoho WorkDrive (Ralakde)/My Folders/rtemplate list"

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
4. You can use variables like \$DATE, \$TIME, and \$DATETIME in your templates" > "$TEMPLATES_DIR/ℹ️ Instructions"
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

# Function to manage templates
function manage_templates {
    local options=("➕ Create new template" "✏️ Edit template" "➖ Delete template" "📂 Open templates folder" "↩️ Back")
    local choice=$(printf "%s\n" "${options[@]}" | rofi -dmenu -i -p "⚙️ Template Management:")
    
    case "$choice" in
        "➕ Create new template")
            create_template
            ;;
        "✏️ Edit template")
            edit_template
            ;;
        "➖ Delete template")
            delete_template
            ;;
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
}

# Function to create a new template - completely reworked
function create_template {
    # Step 1: Get template name using rofi
    local template_name=$(rofi -dmenu -p "✨ Template name:")
    
    # If user cancelled, exit function
    if [ -z "$template_name" ]; then
        notify-send "📋 rtemplate" "Template creation cancelled"
        return
    fi
    
    # Step 2: Check if template already exists
    if [ -f "$TEMPLATES_DIR/$template_name" ]; then
        local overwrite=$(echo -e "Yes\nNo" | rofi -dmenu -i -p "Template already exists. Overwrite?")
        
        if [ "$overwrite" != "Yes" ]; then
            notify-send "📋 rtemplate" "Template creation cancelled"
            return
        fi
    fi
    
    # Step 3: Create a temporary file for the content
    local temp_file=$(mktemp)
    
    # Step 4: Open editor for template content
    if command -v zenity &> /dev/null; then
        # Use Zenity for GUI text entry if available
        zenity --text-info --editable --title="Enter Template Content" \
               --width=600 --height=400 > "$temp_file"
        
        # Check if user cancelled
        if [ $? -ne 0 ]; then
            rm "$temp_file"
            notify-send "📋 rtemplate" "Template creation cancelled"
            return
        fi
    else
        # Fallback to rofi if zenity is not available
        local template_content=$(rofi -dmenu -p "📝 Template content:" -l 0 -multi-select)
        
        if [ -z "$template_content" ]; then
            rm "$temp_file"
            notify-send "📋 rtemplate" "Template creation cancelled"
            return
        fi
        
        echo -e "$template_content" > "$temp_file"
    fi
    
    # Step 5: Save the template file
    if [ -s "$temp_file" ]; then
        # Copy the temp file to the template file
        cp "$temp_file" "$TEMPLATES_DIR/$template_name"
        rm "$temp_file"
        
        # Show success notification
        notify-send "📋 rtemplate" "Created template: $template_name"
        
        # Debug output
        echo "Template created: $TEMPLATES_DIR/$template_name" >&2
        ls -la "$TEMPLATES_DIR/$template_name" >&2
    else
        # Empty content, show error
        rm "$temp_file"
        notify-send "❌ rtemplate" "Template creation failed: Empty content"
    fi
}

# Function to edit an existing template
function edit_template {
    # Get list of template files
    local templates=()
    local template_paths=()
    
    # Read files into an array, preserving spaces in filenames
    while IFS= read -r -d '' file; do
        templates+=("$(basename "$file")")
        template_paths+=("$file")
    done < <(find "$TEMPLATES_DIR" -type f -print0 | sort -z)
    
    # If no templates found
    if [ ${#templates[@]} -eq 0 ]; then
        notify-send "📋 rtemplate" "No templates found in $TEMPLATES_DIR"
        return
    fi
    
    # Display templates in rofi for selection
    local menu_text=""
    for template in "${templates[@]}"; do
        menu_text+="$template"$'\n'
    done
    menu_text=${menu_text%$'\n'} # Remove trailing newline
    
    local choice=$(echo -e "$menu_text" | rofi -dmenu -i -p "✏️ Select template to edit:")
    
    # If no selection, return
    [ -z "$choice" ] && return
    
    # Find the corresponding path
    local template_path=""
    for i in "${!templates[@]}"; do
        if [[ "${templates[$i]}" == "$choice" ]]; then
            template_path="${template_paths[$i]}"
            break
        fi
    done
    
    # Read file content
    local template_content=$(cat "$template_path")
    
    # Edit the content
    local new_content=$(echo -e "$template_content" | rofi -dmenu -p "✏️ Edit template content:" -l 0 -multi-select)
    
    # If cancelled, return
    [ -z "$new_content" ] && return
    
    # Write updated content to file
    echo -e "$new_content" > "$template_path"
    
    notify-send "📋 rtemplate" "Updated template: $choice"
}

# Function to delete a template
function delete_template {
    # Get list of template files
    local templates=()
    local template_paths=()
    
    # Read files into an array, preserving spaces in filenames
    while IFS= read -r -d '' file; do
        templates+=("$(basename "$file")")
        template_paths+=("$file")
    done < <(find "$TEMPLATES_DIR" -type f -print0 | sort -z)
    
    # If no templates found
    if [ ${#templates[@]} -eq 0 ]; then
        notify-send "📋 rtemplate" "No templates found in $TEMPLATES_DIR"
        return
    fi
    
    # Display templates in rofi for selection
    local menu_text=""
    for template in "${templates[@]}"; do
        menu_text+="$template"$'\n'
    done
    menu_text=${menu_text%$'\n'} # Remove trailing newline
    
    local choice=$(echo -e "$menu_text" | rofi -dmenu -i -p "🗑️ Select template to delete:")
    
    # If no selection, return
    [ -z "$choice" ] && return
    
    # Find the corresponding path
    local template_path=""
    for i in "${!templates[@]}"; do
        if [[ "${templates[$i]}" == "$choice" ]]; then
            template_path="${template_paths[$i]}"
            break
        fi
    done
    
    # Confirm deletion
    local confirm=$(printf "Yes\nNo" | rofi -dmenu -i -p "Are you sure you want to delete '$choice'?")
    
    if [ "$confirm" = "Yes" ]; then
        rm "$template_path"
        notify-send "📋 rtemplate" "Deleted template: $choice"
    fi
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
