#!/usr/bin/env bash
# Run as root during full installation; leave access rules untouched.
set -euo pipefail
(( EUID == 0 )) || { echo 'Run this helper with sudo.' >&2; exit 1; }
visudo -cf /etc/sudoers
directory=/etc/sudoers.d
target="$directory/99-work-scripts-pwfeedback"
install -d -m 0750 "$directory"
staged=$(mktemp "$directory/.work-scripts-pwfeedback.XXXXXXXX")
backup=
changed=0
cleanup() {
    status=$?
    trap - EXIT
    if (( status != 0 && changed )); then
        if [[ -n $backup ]]; then
            cp -a -- "$backup" "$target"
        else
            rm -f -- "$target"
        fi
    fi
    rm -f -- "$staged"
    exit "$status"
}
trap cleanup EXIT
printf '%s\n' 'Defaults pwfeedback' > "$staged"
chmod 0440 "$staged"
visudo -cf "$staged"
if [[ -f $target ]] && cmp -s "$staged" "$target"; then
    echo 'Sudo password feedback already configured.'
    exit 0
fi
if [[ -e $target || -L $target ]]; then
    backup=$(mktemp "$directory/99-work-scripts-pwfeedback.backup.XXXXXXXX")
    cp -a -- "$target" "$backup"
fi
changed=1
mv -fT -- "$staged" "$target"
visudo -cf /etc/sudoers
echo 'Sudo password feedback enabled.'
