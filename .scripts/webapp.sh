#!/bin/sh
# Open a URL as a web app using the default Chromium-based browser.

if [ "$#" -ne 1 ]; then
    printf 'Usage: %s <URL>\n' "$0" >&2
    exit 1
fi

DESKTOP=$(xdg-settings get default-web-browser) || exit 1
BROWSER_FILE="/usr/share/applications/$DESKTOP"

if [ ! -r "$BROWSER_FILE" ]; then
    printf 'Browser desktop file not found: %s\n' "$BROWSER_FILE" >&2
    exit 1
fi

BROWSER=$(awk -F= '/^Exec=/ {
    sub(/^Exec=/, "")
    split($0, args, " ")
    print args[1]
    exit
}' "$BROWSER_FILE")

if [ -z "$BROWSER" ] || ! command -v "$BROWSER" >/dev/null 2>&1; then
    printf 'Browser executable not found: %s\n' "$BROWSER" >&2
    exit 1
fi

exec "$BROWSER" --app="$1"
