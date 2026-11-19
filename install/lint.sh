#!/usr/bin/env bash
# Lint the repository: shell scripts, Python syntax and patch whitespace.
set -uo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd -- "$repo" || exit 1

status=0

printf '== shellcheck ==\n'
if ! command -v shellcheck >/dev/null 2>&1; then
    printf 'shellcheck is not installed; skipping (pacman -S shellcheck).\n' >&2
    status=1
else
    mapfile -d '' scripts < <(
        find . -path ./.git -prune -o -type f -name '*.sh' -print0
        find .local/bin -maxdepth 1 -type f ! -name '*.py' -print0
    )
    shellcheck "${scripts[@]}" || status=1
fi

printf '== python syntax ==\n'
python3 -m compileall -q .scripts install || status=1

printf '== patch whitespace ==\n'
if git rev-parse --verify --quiet 'HEAD^' >/dev/null; then
    git diff --check 'HEAD^' HEAD || status=1
else
    git diff --check || status=1
fi

exit "$status"
