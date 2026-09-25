#!/usr/bin/env bash
# Run this from the repository, not the copy in ~/.scripts.
# No display-manager configuration, session switch, or reboot is performed.
set -euo pipefail
SOURCE_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
PACKAGES=(
    hyprland waybar swaync kitty rofi hyprlock hypridle hyprpolkitagent
    swaybg cliphist wl-clipboard brightnessctl ddcutil networkmanager
    network-manager-applet pavucontrol pipewire wireplumber pipewire-pulse
    xdg-desktop-portal-hyprland xdg-desktop-portal-gtk xdg-utils
    qt5ct qt6ct breeze breeze-gtk breeze-icons ttf-jetbrains-mono-nerd noto-fonts
    grim slurp libnotify python zsh util-linux
)
case ${1:---all} in
    --packages-only|--all)
        if (( EUID == 0 )); then
            pacman -S --needed --noconfirm "${PACKAGES[@]}"
            # ddcutil ships the boot-time module rule; load it for this session too.
            modprobe i2c-dev
        else
            sudo pacman -S --needed --noconfirm "${PACKAGES[@]}"
            sudo modprobe i2c-dev
        fi
        [[ ${1:---all} != --packages-only ]] || exit 0
        ;;
    --config-only) ;;
    *) printf 'Usage: %s [--all|--packages-only|--config-only]\n' "$0" >&2; exit 2 ;;
esac
(( EUID != 0 )) || { echo 'Install user configuration as your normal user, not root.' >&2; exit 1; }
[[ -f "$SOURCE_DIR/.config/hypr/hyprland.lua" ]] || { echo 'Run this installer from the work-scripts checkout.' >&2; exit 1; }
state="$HOME/.local/state/work-scripts"
mkdir -p "$state"
backup=$(mktemp -d "$state/hyprland-backup.XXXXXXXX")
chmod 700 "$backup"
copy_file() {
    local relative=$1 target="$HOME/$1"
    if [[ -e "$target" || -L "$target" ]]; then
        mkdir -p "$backup/files/$(dirname "$relative")"
        cp -a "$target" "$backup/files/$relative"
        printf 'replaced\t%s\n' "$relative" >> "$backup/manifest.tsv"
    else
        printf 'created\t%s\n' "$relative" >> "$backup/manifest.tsv"
    fi
    mkdir -p "$(dirname "$target")"
    # Replace a symlink instead of writing through it to an unrelated file.
    cp --remove-destination "$SOURCE_DIR/$relative" "$target"
}
for directory in .config/hypr .config/waybar .config/swaync .config/kitty \
    .config/qt6ct .config/qt5ct .local/share/themes/VioletNight; do
    while IFS= read -r -d '' path; do
        copy_file "${path#"$SOURCE_DIR/"}"
    done < <(find "$SOURCE_DIR/$directory" -type f -print0)
done
copy_file .config/rofi/violet-night.rasi
copy_file .config/xdg-desktop-portal/hyprland-portals.conf
copy_file .local/share/backgrounds/violet-night.png
copy_file .local/share/backgrounds/violet-night.svg
for name in hypr-session.sh hypr-menu.sh hypr-brightness.sh hypr-brightness.py; do
    copy_file ".scripts/$name"
    chmod +x "$HOME/.scripts/$name"
done
# qtct stores absolute palette paths; render the placeholder on deployment.
python3 - "$HOME" <<'PY'
from pathlib import Path
import sys
home = Path(sys.argv[1])
for qt in ('qt5ct', 'qt6ct'):
    path = home / '.config' / qt / (qt + '.conf')
    path.write_text(path.read_text().replace('@HOME@', str(home)))
PY
fc-cache -f >/dev/null
printf '\nViolet Night configuration installed. Backup: %s\n' "$backup"
printf 'SDDM is unchanged. At your next login, select the Hyprland session.\n'
printf 'Your current Plasma session has not been restarted.\n'
