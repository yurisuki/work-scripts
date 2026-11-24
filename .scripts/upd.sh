#!/usr/bin/env bash
# Pull the work-scripts checkout, redeploy it, and clear the update indicator.
set -euo pipefail

state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/work-scripts"

usage() {
    cat <<'EOF'
Usage: upd [install.sh options]
  Fetch and fast-forward the work-scripts checkout, then redeploy it.
  Defaults to --config-only; --all, --packages-only, and --no-upgrade pass through.
EOF
}

case "${1:-}" in
    --help|-h) usage; exit 0 ;;
esac

repo=${WORK_SCRIPTS_REPO:-}
if [[ -z $repo && -f $state_dir/source ]]; then
    read -r repo <"$state_dir/source"
fi
repo=${repo:-$HOME/work-scripts}
if [[ ! -d $repo/.git ]]; then
    printf 'No work-scripts checkout at %s; clone it or set WORK_SCRIPTS_REPO.\n' "$repo" >&2
    exit 1
fi

cd -- "$repo"
if ! git diff --quiet || ! git diff --cached --quiet; then
    printf 'Note: %s has uncommitted changes; the working tree is deployed as it is.\n' "$repo" >&2
fi
before=$(git rev-parse HEAD)
if ! git pull --ff-only --quiet; then
    printf 'Could not fast-forward %s. Commit, stash, or discard local changes, then rerun.\n' "$repo" >&2
    exit 1
fi
after=$(git rev-parse HEAD)
if [[ $before == "$after" ]]; then
    printf 'Already up to date: %s\n' "$(git log -1 --format='%h %s')"
else
    printf 'Updated %s..%s\n' "${before:0:7}" "${after:0:7}"
    git --no-pager log --oneline "$before..$after"
fi

(( $# )) || set -- --config-only
bash "$repo/install.sh" "$@"

# Config-only redeploys skip postinstall.sh, so recheck the local fingerprint
# setting here. auto keeps an existing preference and only enables Hyprlock
# fingerprint auth when this machine reports a usable reader.
python3 "$HOME/.scripts/setup-fingerprint.py" auto ||
    printf 'Fingerprint availability check failed; Hyprlock setting left unchanged.\n' >&2

# Recompute the indicator from the refs git pull just fetched, before reloading
# the bar. --local avoids a second network round trip and cannot leave a stale
# count behind if the network drops right after the pull.
"$HOME/.scripts/check-for-updates.py" --local || true

if [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
    "$HOME/.scripts/hypr-reload.sh" || printf 'Reload reported errors; check the notifications.\n' >&2
else
    printf 'Reload skipped: not running inside Hyprland.\n'
fi
printf 'Update complete.\n'
