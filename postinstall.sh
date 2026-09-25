#!/usr/bin/env bash
# Full desktop + work tools. Run as a normal sudo-capable user from this checkout.
set -euo pipefail
source_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
mode=all
upgrade=1
force_greetd=0
usage() {
    cat <<'EOF'
Usage: ./install.sh [--config-only|--packages-only] [--no-upgrade] [--greetd]
  default          Install packages, work scripts, desktop and user services.
  --config-only    Copy configuration with backups; no packages or service changes.
  --packages-only  Install dependencies only.
  --no-upgrade     Use existing package databases (only on an up-to-date system).
  --greetd         Use tuigreet at next boot, replacing an existing login manager.
Existing login managers are kept by default; greetd is configured if none exists.
EOF
}
for argument in "$@"; do
    case "$argument" in
        --all) mode=all ;;
        --config-only) mode=config ;;
        --packages-only) mode=packages ;;
        --no-upgrade) upgrade=0 ;;
        --greetd) force_greetd=1 ;;
        --help|-h) usage; exit 0 ;;
        *) usage >&2; exit 2 ;;
    esac
done
(( EUID != 0 )) || { echo 'Run as your normal user, not root or sudo.' >&2; exit 1; }
[[ -f "$source_dir/install/deploy.py" ]] || { echo 'Clone the whole repository first.' >&2; exit 1; }
trap 'printf "Installation failed at line %s. Fix the error above and rerun the same command.\n" "$LINENO" >&2' ERR
if [[ $mode == config ]]; then
    exec python3 "$source_dir/install/deploy.py" "$source_dir" "$HOME"
fi
command -v pacman >/dev/null || { echo 'Requires Arch Linux or Manjaro.' >&2; exit 1; }
command -v sudo >/dev/null || { echo 'Configure sudo access for your normal user first.' >&2; exit 1; }
[[ $(uname -m) == x86_64 ]] || { echo 'The bundled binary AUR packages require x86_64.' >&2; exit 1; }
source "$source_dir/install/packages.sh"
printf '\nInstalling Violet Night + work tools. Package managers will show their transactions.\n'
sudo -v
if (( upgrade )); then
    sudo pacman -Syu --needed "${REPO_PACKAGES[@]}"
else
    sudo pacman -S --needed "${REPO_PACKAGES[@]}"
fi
version=$(pacman -Q hyprland | cut -d ' ' -f2)
[[ $(vercmp "$version" 0.55) -ge 0 ]] || { echo 'Hyprland 0.55+ is required for this Lua configuration.' >&2; exit 1; }
command -v start-hyprland >/dev/null
if ! command -v yay >/dev/null; then
    build_dir=$(mktemp -d)
    git clone https://aur.archlinux.org/yay-bin.git "$build_dir/yay-bin"
    (cd "$build_dir/yay-bin" && makepkg -si)
    rm -rf -- "$build_dir"
fi
# Keep AUR review and package conflict prompts available.
yay -S --needed "${AUR_PACKAGES[@]}"
uv tool install 'calcure==3.4'
[[ $mode != packages ]] || { echo 'All package dependencies installed.'; exit 0; }
python3 "$source_dir/install/deploy.py" "$source_dir" "$HOME"
xdg-user-dirs-update
fc-cache -f
update-desktop-database "$HOME/.local/share/applications"
sudo systemctl enable --now NetworkManager.service bluetooth.service cups.service
# usbmuxd is socket/udev activated by its distribution package.
sudo modprobe i2c-dev || echo 'i2c-dev unavailable; laptop brightness still works.'
systemctl --user enable --now pipewire.socket pipewire-pulse.socket wireplumber.service
bash "$HOME/.scripts/install-quote-download-watcher.sh"
if (( force_greetd )) || [[ ! -e /etc/systemd/system/display-manager.service ]]; then
    bash "$HOME/.scripts/setup-greetd.sh" --configure-only
fi
printf '\nInstallation complete. Select Hyprland at your next login, or run start-hyprland from a TTY.\n'
printf 'Weather: ~/.config/waybar/weather.json; monitor/input overrides: ~/.config/hypr/local.lua\n'
printf 'Configure your printer in CUPS and sign in to work applications. Zoho WorkDrive requires its vendor installer.\n'
printf 'No automatic update job is installed. No reboot or logout was performed.\n'
