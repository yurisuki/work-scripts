#!/usr/bin/env bash
# Enable pacman's appearance options without changing repositories or access rules.
set -euo pipefail
target=$(readlink -f -- "${1:-/etc/pacman.conf}")
[[ -f $target && -w $target ]] || { echo 'Pacman configuration is missing or not writable; run with sudo.' >&2; exit 1; }
staged=$(mktemp "${target}.style.XXXXXXXX")
trap 'rm -f -- "$staged"' EXIT
awk '
function finish_options() {
    if (!color) print "Color"
    if (!candy) print "ILoveCandy"
}
/^[[:space:]]*\[[^]]+\]/ {
    if (options) finish_options()
    options = ($0 ~ /^[[:space:]]*\[options\][[:space:]]*(#.*)?$/)
    if (options) found = 1
}
options && /^[[:space:]]*#?[[:space:]]*Color[[:space:]]*(#.*)?$/ {
    if (!color++) print "Color"
    next
}
options && /^[[:space:]]*#?[[:space:]]*ILoveCandy[[:space:]]*(#.*)?$/ {
    if (!candy++) print "ILoveCandy"
    next
}
{ print }
END {
    if (!found) exit 2
    if (options) finish_options()
}
' "$target" > "$staged" || { echo 'Could not find a valid [options] section; configuration unchanged.' >&2; exit 1; }
if cmp -s "$target" "$staged"; then
    echo 'Pacman Color and ILoveCandy are already enabled.'
    exit 0
fi
pacman-conf --config "$staged" --repo-list >/dev/null
chmod --reference="$target" "$staged"
chown --reference="$target" "$staged"
backup=$(mktemp "${target}.backup.XXXXXXXX")
cp -a -- "$target" "$backup"
mv -f -- "$staged" "$target"
printf 'Enabled pacman Color and ILoveCandy. Backup: %s\n' "$backup"
