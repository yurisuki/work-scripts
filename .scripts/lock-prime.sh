#!/usr/bin/env bash
# First hyprlock label: prepare all dynamic content in parallel, then print time.
# Other labels use lock-read.sh and wait for the ready marker, so everything
# appears in a single wave instead of popping in one by one.
set -uo pipefail

dir="${XDG_RUNTIME_DIR:-/tmp}/violet-lock-cache"
scripts="$HOME/.scripts"
mkdir -p -- "$dir"
rm -f -- "$dir/ready"

date +'%A, %d %B' > "$dir/date" &
python3 "$scripts/lock-weather.py" > "$dir/weather" &
python3 "$scripts/lock-music.py" art > "$dir/art" &
"$scripts/lock-capslock.sh" > "$dir/capslock" &
wait

# Music fields are written by lock-music.py into its own cache directory.
music_dir="${XDG_RUNTIME_DIR:-/tmp}/violet-lock-music-text"
for field in title artist previous play next hint; do
    cp -f -- "$music_dir/$field" "$dir/music-$field" 2>/dev/null || : > "$dir/music-$field"
done

printf '%s\n' '󰍃  Log out' > "$dir/button-logout"
printf '%s\n' '󰜉  Restart' > "$dir/button-restart"
printf '%s\n' '󰐥  Shut down' > "$dir/button-shutdown"

notif=$(swaync-client -c 2>/dev/null || printf 0)
case $notif in
    ''|*[!0-9]*|0) : > "$dir/notifications" ;;
    *) printf '󰂚  %s\n' "$notif" > "$dir/notifications" ;;
esac
python3 - <<'PY' > "$dir/ticktick"
import json
from pathlib import Path
try:
    data = json.loads((Path.home() / '.cache/ttui/snapshot.json').read_text())
    tasks = [t for t in data.get('Tasks', []) if t.get('status', 0) == 0
             and str(t.get('projectId', '')).startswith('inbox')]
    print(f'  {len(tasks)}' if tasks else '')
except Exception:
    print('')
PY
if grep -qw mem /sys/power/state 2>/dev/null; then
    printf '%s\n' '󰤄  Suspend' > "$dir/button-suspend"
else
    : > "$dir/button-suspend"
fi

date +'%H:%M' > "$dir/time"
touch -- "$dir/ready"
cat -- "$dir/time"
