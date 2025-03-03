#!/bin/bash

# Show a large font header at the beginning
clear
echo -e "\033[1;37;44mWELCOME $USER TO RALAKDE INSTALLATION - ARCH/MANJARO LINUX INSTALLER\033[0m"
sleep 2  # Timeout for 2 seconds

# Check if dialog is installed, install if necessary
if ! command -v dialog &> /dev/null; then
    echo "dialog is not installed. Installing now..."
    sudo pacman -S --noconfirm dialog
fi

# Function to show a progress box
show_progress() {
    dialog --title "Arch/Manjaro Linux - Ralakde Installation" --infobox "$1" 5 50
    sleep 2
}

# Function to install a package if not installed
install_package() {
    if ! pacman -Q $1 &> /dev/null; then
        show_progress "Installing $1..."
        sudo pacman -S --noconfirm $1 || dialog --title "Error" --msgbox "Failed to install $1." 8 50
    else
        show_progress "$1 is already installed, skipping."
    fi
}

# Ensure yay is installed
if ! command -v yay &> /dev/null; then
    show_progress "Installing yay (AUR helper)..."
    sudo pacman -S --needed --noconfirm base-devel git
    git clone https://aur.archlinux.org/yay.git /tmp/yay
    cd /tmp/yay && makepkg -si --noconfirm
    cd ~ && rm -rf /tmp/yay
fi

# Function to install AUR package if not installed
install_aur_package() {
    if ! yay -Q $1 &> /dev/null; then
        show_progress "Installing $1 from AUR..."
        yay -S --noconfirm $1 || dialog --title "Error" --msgbox "Failed to install $1." 8 50
    else
        show_progress "$1 is already installed, skipping."
    fi
}

# Show a welcome message
dialog --title "Welcome" --msgbox "Welcome $USER to the Ralakde Linux installation.\n\nPress OK to start the setup." 8 50

# Show start message
dialog --title "Arch/Manjaro Linux - Ralakde Installation" --msgbox "Press OK to begin the Ralakde installation.\n\nIt will proceed with updating and installing packages." 8 50

# Update system and AUR packages
show_progress "Updating system and AUR packages..."
sudo pacman -Syu --noconfirm
yay -Syu --noconfirm

# Install packages individually
install_package firefox
install_package thunderbird
install_package onlyoffice-desktopeditors
install_package xournalpp
install_package libimobiledevice

# Install AUR packages individually
install_aur_package zoho-cliq
install_aur_package zapzap

# Show instructions for Zoho WorkDrive
dialog --title "Zoho WorkDrive Installation" --msgbox "To install Zoho WorkDrive manually, follow these steps:\n\n1. Download the WorkDrive .tar.gz file from the website.\n2. Extract it using: tar -xzf ZohoWorkDrive.tar.gz -C ~/ZohoWorkDrive\n3. Navigate to the extracted folder: cd ~/ZohoWorkDrive\n4. Make the setup file executable: chmod +x .setup\n5. Run the setup: ./setup\n\nPress OK to open the download page." 15 60

# Open Zoho WorkDrive download page and wait for user confirmation
show_progress "Opening Zoho WorkDrive download page. Please install it manually."
xdg-open "https://www.zoho.com/workdrive/desktop-sync.html"
dialog --title "Zoho WorkDrive" --msgbox "Please install Zoho WorkDrive manually. Once done, press OK to continue." 8 50

# Clone git repository
show_progress "Cloning scripts repository..."
git clone https://github.com/yurisuki/work-scripts.git ~/Git/work-scripts

# Make all scripts executable
show_progress "Making scripts executable..."
chmod +x ~/Git/work-scripts/*/*.sh

# Move scripts to ~/.scripts
show_progress "Setting up scripts..."
mkdir -p ~/.scripts
mv ~/Git/work-scripts/*/*.sh ~/.scripts/
mv ~/Git/work-scripts/*.sh ~/.scripts/
rm -rf ~/Git/work-scripts

# Create Ralakde directories
show_progress "Creating Ralakde directories..."
mkdir -p ~/Dokumenty/Ralakde/{1!QUOTES,Accountant,"Our inquires",Temp}

# Copy XLSX file to "Our inquires" folder
show_progress "Copying XLSX file to Our inquires..."
cp ~/.scripts/*.xlsx ~/Dokumenty/Ralakde/"Our inquires"/

# Move .desktop file to applications directory
show_progress "Moving .desktop file to applications directory..."
mkdir -p ~/.local/share/applications
cp ~/.scripts/*.desktop ~/.local/share/applications/

# Enable usbmuxd service
show_progress "Enabling usbmuxd service..."
sudo systemctl enable usbmuxd.service
sudo systemctl start usbmuxd.service

# Show completion message
dialog --title "Arch/Manjaro Linux - Ralakde Installation" --msgbox "Ralakde Linux setup has been successfully completed!\n\nPress OK to exit." 8 50

# Show a summary of what was done
clear
echo -e "\033[1;37;44mRALAKDE INSTALLATION COMPLETED!\033[0m"
echo "The following tasks have been completed:"
echo "1. System updated."
echo "2. Packages installed: firefox, thunderbird, onlyoffice-desktopeditors, xournalpp, libimobiledevice."
echo "3. AUR packages installed: zoho-cliq, zapzap."
echo "4. Yay AUR helper installed (if missing)."
echo "5. Zoho WorkDrive download page opened for manual installation."
echo "6. Git repository cloned and scripts moved to ~/.scripts."
echo "7. Ralakde directories created under ~/Dokumenty/Ralakde."
echo "8. XLSX file copied to 'Our inquires' folder."
echo "9. .desktop files moved to ~/.local/share/applications."
echo "10. usbmuxd service enabled and started."
