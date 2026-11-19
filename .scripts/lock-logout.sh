#!/usr/bin/env bash
# Log out from the lockscreen. hyprlock is not inside a logind session,
# so `loginctl terminate-session self` cannot resolve "self" here.
set -uo pipefail

if ! hyprctl --instance 0 dispatch 'hl.dsp.exit()' >/dev/null 2>&1; then
    loginctl terminate-user "$(id -un)" >/dev/null 2>&1 || true
fi
