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

# Function to install AUR package if not installed
install_aur_package() {
    if ! pamac search --installed $1 &> /dev/null; then
        show_progress "Installing $1 from AUR..."
        sudo pamac install --no-confirm $1 || dialog --title "Error" --msgbox "Failed to install $1." 8 50
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
sudo pamac update --no-confirm

# Install packages individually
install_package firefox
install_package thunderbird
install_package onlyoffice-desktopeditors
install_package xournalpp

# Install AUR packages individually
install_aur_package zoho-cliq
install_aur_package zapzap

# Check if Zoho WorkDrive is already installed by checking if the folder exists
if [ ! -d "$HOME/.zohoworkdrive" ]; then
    # Download and install Zoho WorkDrive
    show_progress "Downloading Zoho WorkDrive..."
    wget -O /tmp/ZohoWorkDrive.tar.gz "https://files-accl.zohopublic.com/public/wdbin/download/2014030a29db316e9cedd501f32270e8"
    mkdir -p /tmp/ZohoWorkDrive
    tar -xzf /tmp/ZohoWorkDrive.tar.gz -C /tmp/ZohoWorkDrive

    # Ensure the .setup script has execute permissions
    chmod +x /tmp/ZohoWorkDrive/.setup

    # Run the Zoho WorkDrive installer
    show_progress "Running Zoho WorkDrive setup..."
    cd /tmp/ZohoWorkDrive && ./.setup
else
    show_progress "Zoho WorkDrive is already installed, skipping installation."
fi

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

# Show completion message
dialog --title "Arch/Manjaro Linux - Ralakde Installation" --msgbox "Ralakde Linux setup has been successfully completed!\n\nPress OK to exit." 8 50

# Show a summary of what was done
clear
echo -e "\033[1;37;44mRALAKDE INSTALLATION COMPLETED!\033[0m"
echo "The following tasks have been completed:"
echo "1. System updated."
echo "2. Packages installed: firefox, thunderbird, onlyoffice-desktopeditors, xournalpp."
echo "3. AUR packages installed: zoho-cliq, zapzap."
echo "4. Zoho WorkDrive installed (if not already installed)."
echo "5. Git repository cloned and scripts moved to ~/.scripts."
echo "6. Ralakde directories created under ~/Dokumenty/Ralakde."
echo "7. XLSX file copied to 'Our inquires' folder."
echo "8. .desktop files moved to ~/.local/share/applications."

