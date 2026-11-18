#!/usr/bin/env bash
# Interactive option picker for the installer, called by install.sh with no flags.
# The dialog boxes are the only fancy part; postinstall.sh keeps its usual log output.
set -euo pipefail
source_dir=${1:?usage: tui.sh SOURCE_DIR}

backend=
if [[ -t 0 && -t 1 ]]; then
    for candidate in whiptail dialog; do
        if command -v "$candidate" >/dev/null 2>&1; then
            backend=$candidate
            break
        fi
    done
fi

# Run a dialog box: the answer goes to fd 3 and back on stdout, while the UI is
# kept on the terminal (newt draws on stdout, dialog may use stderr).
ask() {
    local answer
    answer=$(mktemp)
    if ! "$backend" --output-fd 3 --backtitle "Violet Night installer" "$@" 1>&2 3>"$answer"; then
        rm -f "$answer"
        return 1
    fi
    cat "$answer"
    rm -f "$answer"
}

plain_yesno() {
    local prompt=$1 default=$2 reply
    read -r -p "$prompt " reply || return 1
    if [[ -z $reply ]]; then
        reply=$default
    fi
    [[ $reply == [Yy]* ]]
}

pause() {
    printf '\nPress Enter to continue...'
    read -r _ || true
}

if [[ -n $backend ]]; then
    mode=$(ask --title "Work-scripts installer" --radiolist \
        "Choose an action:" 20 72 5 \
        full "Packages, configs and user services" ON \
        config "Dotfiles and scripts only" OFF \
        packages "Dependencies only" OFF \
        check "Check local changes (read-only)" OFF \
        restore "Restore last deployment from backup" OFF) || { printf 'Cancelled.\n'; exit 0; }
else
    printf '\nChoose an action:\n'
    printf '  1) full       Packages, configs and user services\n'
    printf '  2) config     Dotfiles and scripts only\n'
    printf '  3) packages   Dependencies only\n'
    printf '  4) check      Check local changes (read-only)\n'
    printf '  5) restore    Restore last deployment from backup\n'
    while :; do
        read -r -p 'Choice [1-5, q to quit]: ' choice || { printf 'Cancelled.\n'; exit 0; }
        case $choice in
            1|full)    mode=full; break ;;
            2|config)  mode=config; break ;;
            3|packages) mode=packages; break ;;
            4|check)   mode=check; break ;;
            5|restore) mode=restore; break ;;
            q|Q|quit)  printf 'Cancelled.\n'; exit 0 ;;
            *)         printf 'Invalid choice.\n' ;;
        esac
    done
fi

if [[ $mode == check ]]; then
    python3 "$source_dir/install/check-config.py" || true
    pause
    exit 0
fi
if [[ $mode == restore ]]; then
    if [[ -n $backend ]]; then
        ask --title "Restore deployment" --defaultno --yesno \
            "Restore the most recent deployment backup?\n\nManaged files go back to their saved state, and files created by the last deployment are removed." 12 68 || { printf 'Cancelled.\n'; exit 0; }
    else
        plain_yesno 'Restore the last deployment? [y/N]' n || { printf 'Cancelled.\n'; exit 0; }
    fi
    python3 "$source_dir/install/restore.py"
    pause
    exit 0
fi

args=()
case $mode in
    full)     args+=(--all) ;;
    config)   args+=(--config-only) ;;
    packages) args+=(--packages-only) ;;
esac

upgrade=1
force_greetd=0
if [[ $mode == full ]]; then
    if [[ -n $backend ]]; then
        if ask --title "Package databases" --yesno \
            "Refresh pacman databases first (pacman -Syu)?\n\nChoose No only when the databases are already current." 11 68; then
            upgrade=1
        else
            upgrade=0
        fi
    elif plain_yesno 'Refresh pacman databases first? [Y/n]' y; then
        upgrade=1
    else
        upgrade=0
    fi
    if (( ! upgrade )); then
        args+=(--no-upgrade)
    fi

    if [[ -n $backend ]]; then
        if ask --title "Display manager" --defaultno --yesno \
            "Force greetd/tuigreet at next boot, replacing the current display manager?\n\nLeave No to keep your current one. Greetd is still configured when none exists." 13 68; then
            force_greetd=1
        fi
    elif plain_yesno 'Force greetd as the display manager? [y/N]' n; then
        force_greetd=1
    fi
    if (( force_greetd )); then
        args+=(--greetd)
    fi
fi

summary="Install mode: $mode"
if [[ $mode == full ]]; then
    if (( upgrade )); then
        summary+=$'\n'"Package databases: refresh"
    else
        summary+=$'\n'"Package databases: use as-is"
    fi
    if (( force_greetd )); then
        summary+=$'\n'"Display manager: force greetd"
    else
        summary+=$'\n'"Display manager: keep current"
    fi
fi

if [[ -n $backend ]]; then
    ask --title "Ready to install" --yesno "$summary" 12 68 || { printf 'Cancelled.\n'; exit 0; }
else
    printf '\n%s\n' "$summary"
    plain_yesno 'Start the installation? [Y/n]' y || { printf 'Cancelled.\n'; exit 0; }
fi

printf '\nStarting installer: %s\n' "${args[*]}"
exec bash "$source_dir/postinstall.sh" "${args[@]}"
