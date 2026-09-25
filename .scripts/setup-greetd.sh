#!/usr/bin/env bash
set -euo pipefail
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
case ${1:-} in
    '') sudo pacman -S --needed greetd greetd-tuigreet ;;
    --configure-only) ;;
    *) echo "Usage: $0 [--configure-only]" >&2; exit 2 ;;
esac
command -v start-hyprland >/dev/null
[[ -f "$script_dir/../.config/greetd/config.toml" ]]
# Back up login configuration and only change the next boot; never stop a session.
if sudo test -f /etc/greetd/config.toml; then
    backup=$(sudo mktemp /etc/greetd/config.toml.backup.XXXXXXXX)
    sudo cp -a /etc/greetd/config.toml "$backup"
fi
sudo install -Dm644 "$script_dir/../.config/greetd/config.toml" /etc/greetd/config.toml
if [[ -L /etc/systemd/system/display-manager.service ]]; then
    previous=$(basename "$(readlink -f /etc/systemd/system/display-manager.service)")
    if [[ "$previous" != greetd.service ]]; then sudo systemctl disable "$previous"; fi
fi
sudo systemctl enable greetd.service
printf '%s\n' 'greetd will launch start-hyprland at the next login after reboot.'
