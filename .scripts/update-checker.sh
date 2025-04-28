#!/bin/bash

# ===================================
#   WORK-SCRIPTS UPDATER
#   Created by: adamnvrtil
# ===================================

# Configuration
REPO_URL="https://github.com/yurisuki/work-scripts.git"
LOCAL_DIR="$HOME/.local/share/work-scripts"
TIMESTAMP_FILE="$LOCAL_DIR/.last_update"
INSTALL_SCRIPT="$LOCAL_DIR/postinstall.sh"
SCRIPT_PATH=$(readlink -f "$0")  # Get the actual path of this script

# Colors and formatting
BOLD="\e[1m"
RESET="\e[0m"
GOLD="\e[38;5;220m"
SILVER="\e[38;5;248m"
BLUE="\e[38;5;39m"
GREEN="\e[38;5;82m"
RED="\e[38;5;196m"
PURPLE="\e[38;5;135m"
CYAN="\e[38;5;51m"
ORANGE="\e[38;5;208m"
DARK_GRAY="\e[38;5;240m"

# Create directories if they don't exist
mkdir -p "$LOCAL_DIR"

# Function to show a simple notification
notify() {
    if command -v notify-send >/dev/null 2>&1; then
        notify-send "Work Scripts" "$1"
    fi
    echo -e "${PURPLE}${BOLD}[NOTIFICATION]${RESET} $1"
}

# Function to update progress in a file
update_progress() {
    local progress=$1
    echo "$progress" > "$LOCAL_DIR/.progress"
}

# Function to read current progress
read_progress() {
    if [ -f "$LOCAL_DIR/.progress" ]; then
        cat "$LOCAL_DIR/.progress"
    else
        echo "0"
    fi
}

# Function to display a fancy progress bar with real progress
progress_bar() {
    local duration=${1:-3}  # Default to 3 seconds if no duration provided
    local real_progress=${2:-false}  # Whether to use real progress tracking
    local chars="▏▎▍▌▋▊▉█"
    local bar_length=40
    
    # Ensure duration is a valid number
    if ! [[ "$duration" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        duration=3  # Default to 3 seconds if invalid input
    fi
    
    # Initialize progress file if using real progress
    if [ "$real_progress" = true ]; then
        update_progress 0
    fi
    
    local sleep_duration=$(bc -l <<< "scale=3; $duration / $bar_length")
    
    # Ensure sleep_duration is not empty and is a valid number
    if [[ -z "$sleep_duration" || ! "$sleep_duration" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        sleep_duration=0.075  # Default value if calculation fails
    fi

    # Print the bar border
    echo -ne "${DARK_GRAY}╭───────────────────────────────────────────────╮${RESET}\n"
    echo -ne "${DARK_GRAY}│${RESET} "
    
    if [ "$real_progress" = true ]; then
        # Real progress mode - updates based on progress file
        local last_progress=0
        while true; do
            local current_progress=$(read_progress)
            
            # Exit if progress is 100 or greater
            if (( $(echo "$current_progress >= 100" | bc -l) )); then
                break
            fi
            
            # Only update display if progress has changed
            if (( $(echo "$current_progress > $last_progress" | bc -l) )); then
                local filled_length=$(echo "scale=0; $bar_length * $current_progress / 100" | bc -l)
                filled_length=${filled_length%.*}  # Remove decimal part
                
                echo -ne "\r${DARK_GRAY}│${RESET} ${GOLD}${BOLD}["
                
                # Draw filled part
                for ((i=0; i<filled_length; i++)); do
                    echo -ne "${CYAN}█"
                done
                
                # Draw animation character at current position
                if [ "$filled_length" -lt "$bar_length" ]; then
                    local anim_index=$(( $(date +%s%N) / 100000000 % ${#chars} ))
                    echo -ne "${BLUE}${chars:$anim_index:1}"
                    filled_length=$((filled_length + 1))
                fi
                
                # Draw empty part
                for ((i=filled_length; i<bar_length; i++)); do
                    echo -ne " "
                done
                
                echo -ne "${GOLD}]${RESET} ${current_progress}%"
                last_progress=$current_progress
            fi
            
            sleep 0.1
        done
    else
        # Animation mode (original behavior)
        for ((i=0; i<$bar_length; i++)); do
            for ((j=0; j<${#chars}; j++)); do
                echo -ne "\r${DARK_GRAY}│${RESET} ${GOLD}${BOLD}["

                for ((k=0; k<i; k++)); do
                    echo -ne "${CYAN}█"
                done

                echo -ne "${BLUE}${chars:$j:1}"

                for ((k=i+1; k<$bar_length; k++)); do
                    echo -ne " "
                done

                local percentage=$((($i * 100) / $bar_length))
                echo -ne "${GOLD}]${RESET} ${percentage}%"

                sleep "$sleep_duration" 2>/dev/null || sleep 0.075
            done
        done
    fi

    # Ensure we end with a 100% filled bar
    echo -ne "\r${DARK_GRAY}│${RESET} ${GOLD}${BOLD}["
    for ((i=0; i<$bar_length; i++)); do
        echo -ne "${CYAN}█"
    done
    echo -e "${GOLD}]${RESET} 100%  "
    echo -e "${DARK_GRAY}╰───────────────────────────────────────────────╯${RESET}"
    
    # Clean up progress file if it exists
    [ -f "$LOCAL_DIR/.progress" ] && rm "$LOCAL_DIR/.progress"
}

# Function to print a stylish header
print_header() {
    echo -e "\n${DARK_GRAY}╭─────────────────────────────────────────────────────────╮${RESET}"
    echo -e "${DARK_GRAY}│${RESET}       ${GOLD}${BOLD}✨ WORK-SCRIPTS UPDATER ✨${RESET}                    ${DARK_GRAY}│${RESET}"
    echo -e "${DARK_GRAY}│${RESET}                                                         ${DARK_GRAY}│${RESET}"
    echo -e "${DARK_GRAY}│${RESET}  ${SILVER}Repo:${RESET} ${CYAN}yurisuki/work-scripts${RESET}                        ${DARK_GRAY}│${RESET}"
    echo -e "${DARK_GRAY}╰─────────────────────────────────────────────────────────╯${RESET}\n"
}

# Function to print a fancy separator
print_separator() {
    echo -e "\n${DARK_GRAY}╭─────────────────────────────────────────────────────────╮${RESET}"
    echo -e "${DARK_GRAY}│${RESET}                                                         ${DARK_GRAY}│${RESET}"
    echo -e "${DARK_GRAY}╰─────────────────────────────────────────────────────────╯${RESET}\n"
}

# Function to animate typing effect
type_text() {
    local text="$1"
    for ((i=0; i<${#text}; i++)); do
        echo -ne "${text:$i:1}"
        sleep 0.005 2>/dev/null || sleep 0.01
    done
    echo
}

# Function to open a terminal with the updater when updates are available
open_terminal_with_updater() {
    # Check if konsole is available
    if command -v konsole >/dev/null 2>&1; then
        konsole --noclose -e "$SCRIPT_PATH" --show-ui
    else
        # Fallback if konsole is not available
        "$SCRIPT_PATH" --show-ui
    fi
    exit 0
}

# Check if this script is being run with the --show-ui flag
if [[ "$1" == "--show-ui" ]]; then
    print_header

    # Show UI for checking updates
    echo -e "\n${BLUE}${BOLD}▶ Checking for updates...${RESET}"
    progress_bar 2

    # Check if git is installed
    if ! command -v git &> /dev/null; then
        echo -e "\n${RED}${BOLD}✗ Git not installed. Cannot check for updates.${RESET}"
        exit 1
    fi

    # Clone repository if it doesn't exist
    if [ ! -d "$LOCAL_DIR/.git" ]; then
        echo -e "\n${BLUE}${BOLD}▶ First time setup. Cloning repository...${RESET}"
        progress_bar 3

        if git clone "$REPO_URL" "$LOCAL_DIR"; then
            echo -e "\n${GREEN}${BOLD}✓ Repository cloned successfully.${RESET}"
            # Create timestamp file with current time
            date +%s > "$TIMESTAMP_FILE"

            # Make install script executable if it exists
            if [ -f "$INSTALL_SCRIPT" ]; then
                chmod +x "$INSTALL_SCRIPT"
                echo -e "\n${GREEN}${BOLD}✓ Setup complete.${RESET}"
                echo -e "\n${PURPLE}${BOLD}▶ Would you like to run the install script now? ${GOLD}[y/n]${RESET}"
                read -r answer
                if [[ "$answer" =~ ^[Yy]$ ]]; then
                    echo -e "\n${BLUE}${BOLD}▶ Running install script...${RESET}"
                    echo -e "${DARK_GRAY}╭───────────────────────────────────────────────────────${RESET}"
                    "$INSTALL_SCRIPT"
                    echo -e "${DARK_GRAY}╰───────────────────────────────────────────────────────${RESET}"
                    echo -e "\n${GREEN}${BOLD}✓ Installation complete.${RESET}"
                else
                    echo -e "\n${ORANGE}${BOLD}▶ Installation skipped by user.${RESET}"
                fi
            fi
        else
            echo -e "\n${RED}${BOLD}✗ Failed to clone repository.${RESET}"
            exit 1
        fi

        # Fancy exit
        print_separator
        echo -e "${GOLD}${BOLD}Thank you for using WORK-SCRIPTS UPDATER!${RESET}"
        echo -e "\n${DARK_GRAY}Press Enter to close this window...${RESET}"
        read
        exit 0
    fi

    # Change to repository directory
    cd "$LOCAL_DIR" || {
        echo -e "\n${RED}${BOLD}✗ Failed to change to repository directory.${RESET}"
        exit 1
    }

    # Get the current state of the repository
    echo -e "\n${BLUE}${BOLD}▶ Fetching latest changes...${RESET}"
    progress_bar 1.5
    git fetch

    # Check if there are any updates
    UPSTREAM=${2:-'@{u}'}
    LOCAL=$(git rev-parse @)
    REMOTE=$(git rev-parse "$UPSTREAM")
    BASE=$(git merge-base @ "$UPSTREAM")

    if [ "$LOCAL" = "$REMOTE" ]; then
        # Up-to-date
        echo -e "\n${GREEN}${BOLD}✓ Your system is up-to-date!${RESET}"
    elif [ "$LOCAL" = "$BASE" ]; then
        # Updates are available
        # Show update information
        echo -e "\n${ORANGE}${BOLD}▶ Updates available!${RESET}"

        # Get update details
        COMMIT_COUNT=$(git rev-list --count HEAD..origin/main)
        LAST_COMMIT_MSG=$(git log -1 --pretty=%B origin/main)
        LAST_COMMIT_AUTHOR=$(git log -1 --pretty=%an origin/main)
        LAST_COMMIT_DATE=$(git log -1 --pretty=%ad --date=format:'%Y-%m-%d %H:%M:%S' origin/main)

        # Display update information in a fancy box
        echo -e "${DARK_GRAY}╭─────────────────────────────────────────────────────────╮${RESET}"
        echo -e "${DARK_GRAY}│${RESET}  ${GOLD}${BOLD}✨ UPDATE DETAILS ✨${RESET}                                ${DARK_GRAY}│${RESET}"
        echo -e "${DARK_GRAY}│${RESET}                                                         ${DARK_GRAY}│${RESET}"
        echo -e "${DARK_GRAY}│${RESET}  ${SILVER}New commits:${RESET} ${CYAN}$COMMIT_COUNT${RESET}                                    ${DARK_GRAY}│${RESET}"
        TRIMMED_MSG=${LAST_COMMIT_MSG:0:40}
        echo -e "${DARK_GRAY}│${RESET}  ${SILVER}Latest commit:${RESET} ${CYAN}$TRIMMED_MSG${RESET}   ${DARK_GRAY}│${RESET}"
        echo -e "${DARK_GRAY}│${RESET}  ${SILVER}Author:${RESET} ${CYAN}$LAST_COMMIT_AUTHOR${RESET}                               ${DARK_GRAY}│${RESET}"
        echo -e "${DARK_GRAY}│${RESET}  ${SILVER}Date:${RESET} ${CYAN}$LAST_COMMIT_DATE${RESET}                     ${DARK_GRAY}│${RESET}"
        echo -e "${DARK_GRAY}╰─────────────────────────────────────────────────────────╯${RESET}"

        # Ask if user wants to update
        echo -e "\n${PURPLE}${BOLD}▶ Would you like to update and run the install script? ${GOLD}[y/n]${RESET}"
        read -r answer
        if [[ "$answer" =~ ^[Yy]$ ]]; then
            # Pull the changes
            echo -e "\n${BLUE}${BOLD}▶ Pulling updates...${RESET}"
            progress_bar 2

            if git pull --quiet; then
                echo -e "\n${GREEN}${BOLD}✓ Repository updated successfully.${RESET}"

                # Update timestamp
                date +%s > "$TIMESTAMP_FILE"

                # Check if install script exists and is executable
                if [ -f "$INSTALL_SCRIPT" ]; then
                    # Make it executable if it's not
                    chmod +x "$INSTALL_SCRIPT"

                    echo -e "\n${BLUE}${BOLD}▶ Executing install script...${RESET}"
                    echo -e "${DARK_GRAY}╭───────────────────────────────────────────────────────${RESET}"
                    "$INSTALL_SCRIPT"
                    echo -e "${DARK_GRAY}╰───────────────────────────────────────────────────────${RESET}"
                    echo -e "\n${GREEN}${BOLD}✓ Installation complete.${RESET}"
                else
                    echo -e "\n${RED}${BOLD}⚠ Install script not found.${RESET}"
                fi
            else
                echo -e "\n${RED}${BOLD}✗ Failed to update repository.${RESET}"
            fi
        else
            echo -e "\n${ORANGE}${BOLD}▶ Update skipped by user.${RESET}"
        fi
    elif [ "$REMOTE" = "$BASE" ]; then
        # Local changes exist
        echo -e "\n${ORANGE}${BOLD}⚠ Your local repository has changes that are not on the remote.${RESET}"
    else
        # Branches have diverged
        echo -e "\n${RED}${BOLD}⚠ Your branch and the remote branch have diverged.${RESET}"
    fi

    # Fancy exit
    print_separator
    echo -e "${GOLD}${BOLD}Thank you for using WORK-SCRIPTS UPDATER!${RESET}"
    echo -e "\n${DARK_GRAY}Press Enter to close this window...${RESET}"
    read
else
    # This is the background silent check mode - NO OUTPUT AT ALL

    # Check if git is installed
    if ! command -v git &> /dev/null; then
        # Silently exit if git is not installed
        exit 1
    fi

    # Clone repository if it doesn't exist
    if [ ! -d "$LOCAL_DIR/.git" ]; then
        # Silently clone the repository for first time setup
        if git clone "$REPO_URL" "$LOCAL_DIR" --quiet; then
            # Create timestamp file with current time
            date +%s > "$TIMESTAMP_FILE"

            # Make install script executable if it exists
            if [ -f "$INSTALL_SCRIPT" ]; then
                chmod +x "$INSTALL_SCRIPT"
                # Don't run the install script automatically on first clone when in silent mode
            fi
        fi
        exit 0
    fi

    # Change to repository directory
    cd "$LOCAL_DIR" || exit 1

    # Get the current state of the repository silently
    git fetch --quiet

    # Check if there are any updates
    UPSTREAM=${1:-'@{u}'}
    LOCAL=$(git rev-parse @)
    REMOTE=$(git rev-parse "$UPSTREAM")
    BASE=$(git merge-base @ "$UPSTREAM")

    if [ "$LOCAL" = "$REMOTE" ]; then
        # Up-to-date, exit silently
        exit 0
    elif [ "$LOCAL" = "$BASE" ]; then
        # Updates are available, open the terminal with the UI
        open_terminal_with_updater
    elif [ "$REMOTE" = "$BASE" ]; then
        # Local changes exist, but we're running in silent mode so just exit
        exit 0
    else
        # Branches have diverged, but we're running in silent mode so just exit
        exit 0
    fi
fi
