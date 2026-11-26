#!/bin/sh
# Waybar indicator: shows an alert glyph when NetworkManager reports no full internet.
if [ "$(LC_ALL=C nmcli -g CONNECTIVITY general 2>/dev/null)" = full ]; then
    printf '{"text":"","tooltip":"Internet OK"}\n'
else
    printf '{"text":"󰀦","tooltip":"No internet connectivity"}\n'
fi
