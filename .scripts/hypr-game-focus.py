#!/usr/bin/env python3
"""Silently request focus mode while osu! owns the active window."""
import fcntl
import json
import os
from pathlib import Path
import signal
import socket
import subprocess


def is_osu(window):
    for key in ('class', 'initialClass'):
        name = window.get(key, '').lower()
        if name.startswith('osu!') or name in ('osu', 'osu.exe', 'osu-lazer', 'osu-lazer-bin', 'sh.ppy.osu'):
            return True
    return False


def request(enabled):
    subprocess.run([str(Path.home() / '.scripts/hypr-focus.py'),
                    'osu-on' if enabled else 'osu-off'], check=True, timeout=15)


def main():
    runtime = Path(os.environ['XDG_RUNTIME_DIR'])
    with (runtime / 'violet-game-focus.lock').open('w') as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return
        signature = os.environ['HYPRLAND_INSTANCE_SIGNATURE']
        path = runtime / 'hypr' / signature / '.socket2.sock'
        previous = None

        def update():
            nonlocal previous
            try:
                result = subprocess.check_output(['hyprctl', '-j', 'activewindow'], text=True, timeout=3)
                enabled = is_osu(json.loads(result))
            except (OSError, ValueError, subprocess.SubprocessError):
                return
            if enabled != previous:
                request(enabled)
                previous = enabled

        def stop(signum, frame):
            raise SystemExit(0)

        signal.signal(signal.SIGTERM, stop)
        signal.signal(signal.SIGINT, stop)
        try:
            with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as events:
                events.connect(str(path))
                update()
                with events.makefile('r') as stream:
                    for event in stream:
                        if event.startswith(('activewindow>>', 'activewindowv2>>', 'closewindow>>')):
                            update()
        finally:
            request(False)


if __name__ == '__main__':
    main()
