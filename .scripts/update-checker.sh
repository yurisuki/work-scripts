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

    # Check if git is installed
    if ! command -v git &> /dev/null; then
        echo -e "\n${RED}${BOLD}✗ Git not installed. Cannot check for updates.${RESET}"
        exit 1
    fi

    # Clone repository if it doesn't exist
    if [ ! -d "$LOCAL_DIR/.git" ]; then
        echo -e "\n${BLUE}${BOLD}▶ First time setup. Cloning repository...${RESET}"
        
        git clone --quiet "$REPO_URL" "$LOCAL_DIR"
        if [ $? -ne 0 ]; then
            echo -e "\n${RED}${BOLD}✗ Failed to clone repository.${RESET}"
            exit 1
        fi
        echo -e "\n${GREEN}${BOLD}✓ Repository cloned successfully.${RESET}"
        
        # Create timestamp file
        date +%s > "$TIMESTAMP_FILE"
        
        # Check if install script exists and is executable
        if [ -f "$INSTALL_SCRIPT" ]; then
            echo -e "\n${BLUE}${BOLD}▶ Running install script...${RESET}"
            
            # Make it executable if it's not
            [ -x "$INSTALL_SCRIPT" ] || chmod +x "$INSTALL_SCRIPT"
            
            # Run the install script
            "$INSTALL_SCRIPT"
            
            echo -e "\n${GREEN}${BOLD}✓ Installation complete.${RESET}"
        fi
        
        echo -e "\n${GREEN}${BOLD}✓ Setup complete. You're good to go!${RESET}"
        exit 0
    fi

    # Change to repository directory
    cd "$LOCAL_DIR" || {
        echo -e "\n${RED}${BOLD}✗ Failed to change to repository directory.${RESET}"
        exit 1
    }

    # Get the current state of the repository
    echo -e "\n${BLUE}${BOLD}▶ Fetching latest changes...${RESET}"
    git fetch

    # Check if there are any updates
    UPSTREAM=${2:-'@{u}'}
    LOCAL=$(git rev-parse @)
    REMOTE=$(git rev-parse "$UPSTREAM")
    BASE=$(git merge-base @ "$UPSTREAM")

    if [ "$LOCAL" = "$REMOTE" ]; then
        # Up-to-date
        echo -e "\n${GREEN}${BOLD}✓ Your system is up-to-date!${RESET}"
        
        # Update timestamp anyway
        date +%s > "$TIMESTAMP_FILE"
        
        # Show last update time
        LAST_UPDATE=$(date -d @$(cat "$TIMESTAMP_FILE") "+%Y-%m-%d %H:%M:%S")
        echo -e "\n${SILVER}Last checked: ${CYAN}$LAST_UPDATE${RESET}"
        
        exit 0
    elif [ "$LOCAL" = "$BASE" ]; then
        # Need to pull
        echo -e "\n${ORANGE}${BOLD}⚠ Updates available!${RESET}"
        
        # Show what's new
        echo -e "\n${SILVER}Changes:${RESET}"
        git log --pretty=format:"${CYAN}%h${RESET} - %s (${PURPLE}%an${RESET}, ${SILVER}%ar${RESET})" HEAD..$REMOTE | head -n 5
        
        # If there are more than 5 commits, show a message
        COMMIT_COUNT=$(git rev-list --count HEAD..$REMOTE)
        if [ "$COMMIT_COUNT" -gt 5 ]; then
            echo -e "${SILVER}...and $(($COMMIT_COUNT - 5)) more${RESET}"
        fi
        
        # Ask if user wants to update
        echo -e "\n${BLUE}${BOLD}Do you want to update now? (y/n)${RESET} "
        read -r ANSWER
        
        if [[ "$ANSWER" =~ ^[Yy]$ ]]; then
            # Pull the changes
            echo -e "\n${BLUE}${BOLD}▶ Pulling updates...${RESET}"
            
            if git pull --quiet; then
                echo -e "\n${GREEN}${BOLD}✓ Repository updated successfully.${RESET}"

                # Update timestamp
                date +%s > "$TIMESTAMP_FILE"

                # Check if install script exists and is executable
                if [ -f "$INSTALL_SCRIPT" ]; then
                    echo -e "\n${BLUE}${BOLD}▶ Running install script...${RESET}"
                    
                    # Make it executable if it's not
                    [ -x "$INSTALL_SCRIPT" ] || chmod +x "$INSTALL_SCRIPT"
                    
                    # Run the install script
                    "$INSTALL_SCRIPT"
                    
                    echo -e "\n${GREEN}${BOLD}✓ Installation complete.${RESET}"
                else
                    echo -e "\n${RED}${BOLD}⚠ Install script not found.${RESET}"
                fi
            else
                echo -e "\n${RED}${BOLD}✗ Failed to update repository.${RESET}"
            fi
        else
            echo -e "\n${ORANGE}${BOLD}⚠ Update canceled.${RESET}"
        fi
    else
        # Diverged
        echo -e "\n${RED}${BOLD}✗ Your repository has diverged from the remote.${RESET}"
        echo -e "${SILVER}This might be due to local changes. Consider resetting your repository.${RESET}"
    fi
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
