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

if [[ -n $backend ]]; then
    mode=$(ask --title "Installation mode" --radiolist \
        "Choose what to install:" 18 68 3 \
        full "Packages, configs and user services" ON \
        config "Dotfiles and scripts only" OFF \
        packages "Dependencies only" OFF) || { printf 'Cancelled.\n'; exit 0; }
else
    printf '\nChoose what to install:\n'
    printf '  1) full       Packages, configs and user services\n'
    printf '  2) config     Dotfiles and scripts only\n'
    printf '  3) packages   Dependencies only\n'
    while :; do
        read -r -p 'Choice [1-3, q to quit]: ' choice || { printf 'Cancelled.\n'; exit 0; }
        case $choice in
            1|full)    mode=full; break ;;
            2|config)  mode=config; break ;;
            3|packages) mode=packages; break ;;
            q|Q|quit)  printf 'Cancelled.\n'; exit 0 ;;
            *)         printf 'Invalid choice.\n' ;;
        esac
    done
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
