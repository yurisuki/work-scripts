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
BOLD=""
RESET=""
GOLD=""
SILVER=""
BLUE=""
GREEN=""
RED=""
PURPLE=""
CYAN=""
ORANGE=""
DARK_GRAY=""

# Enable colors only if output is a terminal
if [ -t 1 ]; then
    BOLD="\033[1m"
    RESET="\033[0m"
    GOLD="\033[38;5;220m"
    SILVER="\033[38;5;248m"
    BLUE="\033[38;5;39m"
    GREEN="\033[38;5;82m"
    RED="\033[38;5;196m"
    PURPLE="\033[38;5;135m"
    CYAN="\033[38;5;51m"
    ORANGE="\033[38;5;208m"
    DARK_GRAY="\033[38;5;240m"
fi

# Create directories if they don't exist
mkdir -p "$LOCAL_DIR"

# Function to show a simple notification
notify() {
    if command -v notify-send >/dev/null 2>&1; then
        notify-send "Work Scripts" "$1"
    fi
    printf "${PURPLE}${BOLD}[NOTIFICATION]${RESET} %s\n" "$1"
}

# Function to print a stylish header
print_header() {
    printf "\n${DARK_GRAY}╭─────────────────────────────────────────────────────────╮${RESET}\n"
    printf "${DARK_GRAY}│${RESET}       ${GOLD}${BOLD}✨ WORK-SCRIPTS UPDATER ✨${RESET}                    ${DARK_GRAY}│${RESET}\n"
    printf "${DARK_GRAY}│${RESET}                                                         ${DARK_GRAY}│${RESET}\n"
    printf "${DARK_GRAY}│${RESET}  ${SILVER}Repo:${RESET} ${CYAN}yurisuki/work-scripts${RESET}                        ${DARK_GRAY}│${RESET}\n"
    printf "${DARK_GRAY}╰─────────────────────────────────────────────────────────╯${RESET}\n"
}

# Function to print a fancy separator
print_separator() {
    printf "\n${DARK_GRAY}╭─────────────────────────────────────────────────────────╮${RESET}\n"
    printf "${DARK_GRAY}│${RESET}                                                         ${DARK_GRAY}│${RESET}\n"
    printf "${DARK_GRAY}╰─────────────────────────────────────────────────────────╯${RESET}\n"
}

# Function to animate typing effect
type_text() {
    local text="$1"
    for ((i=0; i<${#text}; i++)); do
        printf "%c" "${text:$i:1}"
        sleep 0.005 2>/dev/null || sleep 0.01
    done
    printf "\n"
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
    printf "\n${BLUE}${BOLD}▶ Checking for updates...${RESET}\n"

    # Check if git is installed
    if ! command -v git &> /dev/null; then
        printf "\n${RED}${BOLD}✗ Git not installed. Cannot check for updates.${RESET}\n"
        exit 1
    fi

    # Clone repository if it doesn't exist
    if [ ! -d "$LOCAL_DIR/.git" ]; then
        printf "\n${BLUE}${BOLD}▶ First time setup. Cloning repository...${RESET}\n"
        
        git clone --quiet "$REPO_URL" "$LOCAL_DIR"
        if [ $? -ne 0 ]; then
            printf "\n${RED}${BOLD}✗ Failed to clone repository.${RESET}\n"
            exit 1
        fi
        printf "\n${GREEN}${BOLD}✓ Repository cloned successfully.${RESET}\n"
        
        # Create timestamp file
        date +%s > "$TIMESTAMP_FILE"
        
        # Check if install script exists and is executable
        if [ -f "$INSTALL_SCRIPT" ]; then
            printf "\n${BLUE}${BOLD}▶ Running install script...${RESET}\n"
            
            # Make it executable if it's not
            [ -x "$INSTALL_SCRIPT" ] || chmod +x "$INSTALL_SCRIPT"
            
            # Run the install script
            "$INSTALL_SCRIPT"
            
            printf "\n${GREEN}${BOLD}✓ Installation complete.${RESET}\n"
        fi
        
        printf "\n${GREEN}${BOLD}✓ Setup complete. You're good to go!${RESET}\n"
        exit 0
    fi

    # Change to repository directory
    cd "$LOCAL_DIR" || {
        printf "\n${RED}${BOLD}✗ Failed to change to repository directory.${RESET}\n"
        exit 1
    }

    # Get the current state of the repository
    printf "\n${BLUE}${BOLD}▶ Fetching latest changes...${RESET}\n"
    git fetch

    # Check if there are any updates
    UPSTREAM=${2:-'@{u}'}
    LOCAL=$(git rev-parse @)
    REMOTE=$(git rev-parse "$UPSTREAM")
    BASE=$(git merge-base @ "$UPSTREAM")

    if [ "$LOCAL" = "$REMOTE" ]; then
        # Up-to-date
        printf "\n${GREEN}${BOLD}✓ Your system is up-to-date!${RESET}\n"
        
        # Update timestamp anyway
        date +%s > "$TIMESTAMP_FILE"
        
        # Show last update time
        LAST_UPDATE=$(date -d @$(cat "$TIMESTAMP_FILE") "+%Y-%m-%d %H:%M:%S")
        printf "\n${SILVER}Last checked: ${CYAN}%s${RESET}\n" "$LAST_UPDATE"
        
        exit 0
    elif [ "$LOCAL" = "$BASE" ]; then
        # Need to pull
        printf "\n${ORANGE}${BOLD}⚠ Updates available!${RESET}\n"
        
        # Show what's new
        printf "\n${SILVER}Changes:${RESET}\n"
        git --no-pager log --pretty=format:"%h - %s (%an, %ar)" HEAD..$REMOTE | head -n 5
        
        # If there are more than 5 commits, show a message
        COMMIT_COUNT=$(git rev-list --count HEAD..$REMOTE)
        if [ "$COMMIT_COUNT" -gt 5 ]; then
            printf "${SILVER}...and %d more${RESET}\n" $(($COMMIT_COUNT - 5))
        fi
        
        # Ask if user wants to update
        printf "\n${BLUE}${BOLD}Do you want to update now? (y/n)${RESET} "
        read -r ANSWER
        
        if [[ "$ANSWER" =~ ^[Yy]$ ]]; then
            # Pull the changes
            printf "\n${BLUE}${BOLD}▶ Pulling updates...${RESET}\n"
            
            if git pull --quiet; then
                printf "\n${GREEN}${BOLD}✓ Repository updated successfully.${RESET}\n"

                # Update timestamp
                date +%s > "$TIMESTAMP_FILE"

                # Check if install script exists and is executable
                if [ -f "$INSTALL_SCRIPT" ]; then
                    printf "\n${BLUE}${BOLD}▶ Running install script...${RESET}\n"
                    
                    # Make it executable if it's not
                    [ -x "$INSTALL_SCRIPT" ] || chmod +x "$INSTALL_SCRIPT"
                    
                    # Run the install script
                    "$INSTALL_SCRIPT"
                    
                    printf "\n${GREEN}${BOLD}✓ Installation complete.${RESET}\n"
                else
                    printf "\n${RED}${BOLD}⚠ Install script not found.${RESET}\n"
                fi
            else
                printf "\n${RED}${BOLD}✗ Failed to update repository.${RESET}\n"
            fi
        else
            printf "\n${ORANGE}${BOLD}⚠ Update canceled.${RESET}\n"
        fi
    else
        # Diverged
        printf "\n${RED}${BOLD}✗ Your repository has diverged from the remote.${RESET}\n"
        printf "${SILVER}This might be due to local changes. Consider resetting your repository.${RESET}\n"
    fi
    
    # Display closing message
    print_separator
    printf "${GOLD}${BOLD}Installation complete. Please close this window.${RESET}\n"
    printf "\n${DARK_GRAY}Press Enter to exit...${RESET}"
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
