#!/usr/bin/env python3
"""Show Caps Lock only while enabled, without intercepting keyboard input."""
import fcntl
import json
import os
from pathlib import Path
import sys
import time


def enabled():
    for device in Path('/sys/class/leds').glob('*::capslock'):
        try:
            if int((device / 'brightness').read_text()) > 0:
                return True
        except (OSError, ValueError):
            pass
    return False


def main():
    # A Waybar config reload spawns a new watcher without killing this one.
    # One instance at a time; the heartbeat below notices the closed stdout pipe.
    runtime = Path(os.environ['XDG_RUNTIME_DIR'])
    with (runtime / 'violet-bar-capslock.lock').open('w') as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return
        previous = None
        last_beat = 0.0
        while True:
            current = enabled()
            now = time.monotonic()
            if current != previous or now - last_beat >= 2:
                print(json.dumps({'text': '󰘲' if current else '',
                                  'tooltip': 'Caps Lock is on' if current else '',
                                  'class': 'active' if current else 'inactive'}), flush=True)
                previous = current
                last_beat = now
            time.sleep(0.1)


if __name__ == '__main__':
    try:
        main()
    except BrokenPipeError:
        os.dup2(os.open(os.devnull, os.O_WRONLY), sys.stdout.fileno())
        sys.exit(0)
