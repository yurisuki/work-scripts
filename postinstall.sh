#!/usr/bin/env bash
#
# Ralakde Installation Script for Arch/Manjaro Linux
# Author: adamnvrtil
# Description: Sets up a customized Arch/Manjaro Linux environment with required applications
# Version: 2.5.0
# License: MIT

# Set strict error handling
set -eo pipefail

# Define colors and formatting
readonly BOLD="\e[1m"
readonly GREEN="\e[32m"
readonly BLUE="\e[34m"
readonly RED="\e[31m"
readonly YELLOW="\e[33m"
readonly RESET="\e[0m"
readonly BG_BLUE="\e[44m"
readonly FG_WHITE="\e[97m"

# Configuration variables
readonly HEADER="${BOLD}${FG_WHITE}${BG_BLUE}"
readonly SCRIPTS_DIR="${HOME}/.scripts"
readonly RALAKDE_DIR="${HOME}/Dokumenty/Ralakde"
readonly RALAKDE_SUBDIRS=("1!QUOTES" "Accountant" "Our inquires" "Temp")
readonly APPLICATIONS_DIR="${HOME}/.local/share/applications"
readonly CONFIG_DIR="${HOME}/.config"
readonly ROFI_CONFIG_DIR="${CONFIG_DIR}/rofi"
readonly GIT_TEMP_DIR="/tmp/work-scripts-$(date +%s)"
readonly GIT_REPO="https://github.com/yurisuki/work-scripts.git"
readonly ZOHO_WORKDRIVE_PATH="${HOME}/.zohoworkdrive/bin/zohoworkdrive"

# Program defaults
readonly WHIPTAIL_TITLE="Ralakde Installation"
readonly WHIPTAIL_BACKTITLE="Arch/Manjaro Linux - Ralakde Setup"
readonly WHIPTAIL_WIDTH=70
readonly WHIPTAIL_HEIGHT=15

#------------------------------------------------------------------------------
# Utility functions
#------------------------------------------------------------------------------

# Display a message with a colored prefix
log() {
    local level=$1
    local message=$2
    local color=""
    local prefix=""

    case $level in
        info)  color="$BLUE"; prefix="[INFO]";;
        ok)    color="$GREEN"; prefix="[OK]";;
        warn)  color="$YELLOW"; prefix="[WARNING]";;
        error) color="$RED"; prefix="[ERROR]";;
        *)     color="$RESET"; prefix="[$level]";;
    esac

    echo -e "${color}${BOLD}${prefix}${RESET} ${message}"
}

# Show a progress message using whiptail
show_progress() {
    whiptail --backtitle "$WHIPTAIL_BACKTITLE" \
             --title "$WHIPTAIL_TITLE" \
             --infobox "$1" 8 $WHIPTAIL_WIDTH
    sleep 1
}

# Display an error message and exit
die() {
    log error "$1"
    exit 1
}

# Check if a command exists
command_exists() {
    command -v "$1" &>/dev/null
}

# Run a command with error handling
run_cmd() {
    if ! "$@"; then
        die "Command failed: $*"
    fi
}

# Display a fancy header
show_header() {
    clear
    echo -e "${HEADER}                                                                ${RESET}"
    echo -e "${HEADER}  WELCOME ${USER} TO RALAKDE INSTALLATION - ARCH/MANJARO LINUX  ${RESET}"
    echo -e "${HEADER}                                                                ${RESET}"
    echo
}

#------------------------------------------------------------------------------
# Installation functions
#------------------------------------------------------------------------------

# Check and install whiptail if missing
ensure_whiptail() {
    if ! command_exists whiptail; then
        log info "Installing whiptail..."
        sudo pacman -S --noconfirm libnewt || die "Failed to install whiptail"
    fi
}

# Install a package if not already installed
install_package() {
    if ! pacman -Q "$1" &>/dev/null; then
        show_progress "Installing $1..."
        log info "Installing package: $1"
        sudo pacman -S --noconfirm "$1" || {
            whiptail --backtitle "$WHIPTAIL_BACKTITLE" \
                     --title "Error" \
                     --msgbox "Failed to install $1." 8 $WHIPTAIL_WIDTH
            return 1
        }
        log ok "Package installed: $1"
    else
        show_progress "$1 is already installed, skipping."
        log info "Package already installed: $1"
    fi
}

# Ensure yay (AUR helper) is installed
ensure_yay() {
    if ! command_exists yay; then
        show_progress "Installing yay (AUR helper)..."
        log info "Installing yay AUR helper..."

        # Install build dependencies
        sudo pacman -S --needed --noconfirm base-devel git || die "Failed to install base-devel or git"

        # Clone and build yay
        git clone https://aur.archlinux.org/yay.git /tmp/yay || die "Failed to clone yay repository"
        (cd /tmp/yay && makepkg -si --noconfirm) || die "Failed to build yay"
        rm -rf /tmp/yay

        log ok "Yay installed successfully"
    else
        log info "Yay is already installed"
    fi
}

# Install an AUR package if not already installed
install_aur_package() {
    if ! yay -Q "$1" &>/dev/null; then
        show_progress "Installing $1 from AUR..."
        log info "Installing AUR package: $1"
        yay -S --noconfirm "$1" || {
            whiptail --backtitle "$WHIPTAIL_BACKTITLE" \
                     --title "Error" \
                     --msgbox "Failed to install $1 from AUR." 8 $WHIPTAIL_WIDTH
            return 1
        }
        log ok "AUR package installed: $1"
    else
        show_progress "$1 is already installed, skipping."
        log info "AUR package already installed: $1"
    fi
}

# Install Python packages
install_python_packages() {
    show_progress "Installing Python packages..."
    log info "Installing required Python packages..."

    local python_packages=("python-pandas" "python-numpy" "python-pyqt6")
    for pkg in "${python_packages[@]}"; do
        install_package "$pkg"
    done

    log ok "Python packages installed"
}

# Update system packages
update_system() {
    show_progress "Updating system packages..."
    log info "Updating system packages..."
    sudo pacman -Syu --noconfirm || die "System update failed"
    log ok "System packages updated"

    show_progress "Updating AUR packages..."
    log info "Updating AUR packages..."
    yay -Syu --noconfirm || log warn "AUR update completed with warnings"
    log ok "AUR packages updated"
}

# Setup directories and files
setup_directories() {
    show_progress "Setting up directories..."
    log info "Ensuring Ralakde directories exist..."

    # Create main directory if it doesn't exist
    if [ ! -d "$RALAKDE_DIR" ]; then
        mkdir -p "$RALAKDE_DIR"
        log info "Created main Ralakde directory"
    fi

    # Create subdirectories if they don't exist
    for dir in "${RALAKDE_SUBDIRS[@]}"; do
        if [ ! -d "$RALAKDE_DIR/$dir" ]; then
            mkdir -p "$RALAKDE_DIR/$dir"
            log info "Created $dir directory"
        fi
    done

    # Create .config/rofi directory if it doesn't exist
    if [ ! -d "$ROFI_CONFIG_DIR" ]; then
        mkdir -p "$ROFI_CONFIG_DIR"
        log info "Created Rofi configuration directory"
    fi

    log ok "Directory structure verified"
}

# Clone and setup scripts
setup_scripts() {
    show_progress "Setting up scripts..."
    log info "Cloning scripts repository..."

    # Clone repository to temporary directory
    git clone "$GIT_REPO" "$GIT_TEMP_DIR" || die "Failed to clone repository"

    # Make scripts directory if it doesn't exist
    if [ ! -d "$SCRIPTS_DIR" ]; then
        mkdir -p "$SCRIPTS_DIR"
    fi

    # Copy and make shell scripts executable
    log info "Setting up shell scripts..."
    find "$GIT_TEMP_DIR" -name "*.sh" -exec chmod +x {} \;
    find "$GIT_TEMP_DIR" -name "*.sh" -exec cp {} "$SCRIPTS_DIR/" \;

    # Copy XLSX files if they don't exist
    log info "Setting up inquiry template..."
    find "$GIT_TEMP_DIR" -name "*.xlsx" -exec cp -n {} "$RALAKDE_DIR/Our inquires/" \;

    # Setup desktop files
    log info "Setting up desktop files..."
    if [ ! -d "$APPLICATIONS_DIR" ]; then
        mkdir -p "$APPLICATIONS_DIR"
    fi

    find "$GIT_TEMP_DIR" -name "*.desktop" -exec chmod +x {} \;
    find "$GIT_TEMP_DIR" -name "*.desktop" -exec cp {} "$APPLICATIONS_DIR/" \;

    # Setup rofi config if it exists in the repo
    if [ -f "$GIT_TEMP_DIR/.config/rofi/config.rasi" ]; then
        log info "Setting up Rofi configuration..."
        cp "$GIT_TEMP_DIR/.config/rofi/config.rasi" "$ROFI_CONFIG_DIR/"
    fi

    # Clean up
    rm -rf "$GIT_TEMP_DIR"

    log ok "Scripts setup completed"
}

# Configure system services
configure_services() {
    show_progress "Configuring system services..."
    log info "Enabling usbmuxd service..."

    sudo systemctl enable usbmuxd.service || log warn "Failed to enable usbmuxd service"
    sudo systemctl start usbmuxd.service || log warn "Failed to start usbmuxd service"

    log ok "Services configured"
}

# Create update-checker startup file
setup_update_checker() {
    show_progress "Setting up update checker autostart..."
    log info "Creating update-checker autostart file..."

    # Make sure the autostart directory exists
    if [ ! -d "${HOME}/.config/autostart" ]; then
        mkdir -p "${HOME}/.config/autostart"
        log info "Created autostart directory"
    fi

    # Create the desktop entry file
    cat > "${HOME}/.config/autostart/update-checker.sh.desktop" << EOF
[Desktop Entry]
Exec=/home/${USER}/.scripts/update-checker.sh
Icon=
Name=update-checker.sh
Path=
Terminal=False
Type=Application
EOF

    # Make sure the file has proper permissions
    chmod 644 "${HOME}/.config/autostart/update-checker.sh.desktop"

    log ok "Update checker autostart file created successfully"
}

# Show summary of installation
show_summary() {
    local package_list="firefox thunderbird onlyoffice-desktopeditors xournalpp libimobiledevice rofi-wayland"
    local python_packages="python-pandas python-numpy python-pyqt6"
    local aur_package_list="zoho-cliq zapzap ttf-apple-emoji"

    whiptail --backtitle "$WHIPTAIL_BACKTITLE" \
             --title "Installation Complete" \
             --msgbox "Ralakde Linux setup has been successfully completed!\n\nPress OK to view the summary." 10 $WHIPTAIL_WIDTH

    clear
    echo -e "${HEADER}                                                   ${RESET}"
    echo -e "${HEADER}  RALAKDE INSTALLATION COMPLETED!                  ${RESET}"
    echo -e "${HEADER}                                                   ${RESET}"
    echo
    echo -e "${BOLD}Installation Summary:${RESET}"
    echo "-----------------------------------------------"
    echo -e "${BOLD}1.${RESET} System updated and upgraded"
    echo -e "${BOLD}2.${RESET} Standard packages installed: ${BLUE}$package_list${RESET}"
    echo -e "${BOLD}3.${RESET} Python packages installed: ${BLUE}$python_packages${RESET}"
    echo -e "${BOLD}4.${RESET} AUR packages installed: ${YELLOW}$aur_package_list${RESET}"
    echo -e "${BOLD}5.${RESET} Yay AUR helper installed (if missing)"
    if [ ! -f "$ZOHO_WORKDRIVE_PATH" ]; then
        echo -e "${BOLD}6.${RESET} Zoho WorkDrive download page opened for manual installation"
    else
        echo -e "${BOLD}6.${RESET} Zoho WorkDrive already installed at ${BLUE}$ZOHO_WORKDRIVE_PATH${RESET}"
    fi
    echo -e "${BOLD}7.${RESET} Git repository cloned and scripts moved to ${BLUE}$SCRIPTS_DIR${RESET}"
    echo -e "${BOLD}8.${RESET} Ralakde directories verified under ${BLUE}$RALAKDE_DIR${RESET}"
    echo -e "${BOLD}9.${RESET} Desktop files added to ${BLUE}$APPLICATIONS_DIR${RESET}"
    echo -e "${BOLD}10.${RESET} Rofi configuration added to ${BLUE}$ROFI_CONFIG_DIR${RESET}"
    echo -e "${BOLD}11.${RESET} usbmuxd service enabled and started"
    echo
    echo -e "${GREEN}${BOLD}Thank you for installing Ralakde!${RESET}"
    echo -e "${BLUE}Installation completed at: $(date '+%Y-%m-%d %H:%M:%S')${RESET}"
    echo -e "${YELLOW}Installed by: ${USER}${RESET}"
    echo "-----------------------------------------------"
}

# Handle the Zoho WorkDrive installation
setup_zoho_workdrive() {
    # Check if Zoho WorkDrive is already installed
    if [ -f "$ZOHO_WORKDRIVE_PATH" ]; then
        log info "Zoho WorkDrive is already installed, skipping installation"
        return 0
    fi

    whiptail --backtitle "$WHIPTAIL_BACKTITLE" \
             --title "Zoho WorkDrive Installation" \
             --msgbox "To install Zoho WorkDrive manually, follow these steps:\n\n1. Download the WorkDrive .tar.gz file from the website\n2. Extract it using: tar -xzf zoho-workdrive*.tar.gz\n3. Run the installer as instructed on the website\n\nPress OK to open the download page." 12 $WHIPTAIL_WIDTH

    show_progress "Opening Zoho WorkDrive download page..."
    xdg-open "https://www.zoho.com/workdrive/desktop-sync.html"

    whiptail --backtitle "$WHIPTAIL_BACKTITLE" \
             --title "Zoho WorkDrive" \
             --msgbox "Please install Zoho WorkDrive manually.\nOnce done, press OK to continue." 8 $WHIPTAIL_WIDTH
}

#------------------------------------------------------------------------------
# Main script execution
#------------------------------------------------------------------------------

main() {
    # Ensure we have whiptail before anything else
    ensure_whiptail

    # Show welcome header
    show_header

    # Welcome message
    if ! whiptail --backtitle "$WHIPTAIL_BACKTITLE" \
                 --title "Welcome" \
                 --yesno "Welcome to the Ralakde Linux installation.\n\nUser: ${USER}\n\nThis script will set up your system with required applications and configurations.\n\nDo you want to continue?" 12 $WHIPTAIL_WIDTH; then
        log info "Installation cancelled by user"
        exit 0
    fi

    # Ensure yay is available for AUR packages
    ensure_yay

    # Update system
    update_system

    # Install standard packages
    local packages=("firefox" "thunderbird" "onlyoffice-desktopeditors" "xournalpp" "libimobiledevice" "rofi-wayland")
    for pkg in "${packages[@]}"; do
        install_package "$pkg"
    done

    # Install Python packages
    install_python_packages

    # Install AUR packages
    local aur_packages=("zoho-cliq" "zapzap" "ttf-apple-emoji")
    for pkg in "${aur_packages[@]}"; do
        install_aur_package "$pkg"
    done

    # Handle Zoho WorkDrive installation
    setup_zoho_workdrive

    # Setup directories and structure
    setup_directories

    # Setup scripts
    setup_scripts

    # Setup update checker autostart
    setup_update_checker

    # Configure services
    configure_services

    # Show installation summary
    show_summary
}

# Execute main function
main "$@"