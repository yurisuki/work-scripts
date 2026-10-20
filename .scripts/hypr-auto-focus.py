#!/usr/bin/env python3
"""Request focus mode while the active Hyprland window is fullscreen."""
import fcntl
import json
import os
from pathlib import Path
import select
import signal
import socket
import subprocess

def request(enabled):
    subprocess.run([str(Path.home() / '.scripts/hypr-focus.py'),
                    'fullscreen-on' if enabled else 'fullscreen-off'],
                   check=True, timeout=15)

def active_window():
    try:
        return json.loads(subprocess.check_output(['hyprctl', '-j', 'activewindow'], text=True, timeout=3))
    except (OSError, ValueError, subprocess.SubprocessError):
        return {}

def is_fullscreen(window):
    return bool(window.get('address')) and bool(window.get('mapped', True)) and bool(window.get('fullscreen', 0))

def main():
    runtime = Path(os.environ['XDG_RUNTIME_DIR'])
    with (runtime / 'violet-auto-focus.lock').open('w') as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return
        signature = os.environ['HYPRLAND_INSTANCE_SIGNATURE']
        path = runtime / 'hypr' / signature / '.socket2.sock'
        previous = None

        def update():
            nonlocal previous
            enabled = is_fullscreen(active_window())
            if enabled != previous:
                request(enabled)
                previous = enabled

        def stop(signum, frame):
            if previous:
                request(False)
            raise SystemExit(0)

        signal.signal(signal.SIGTERM, stop)
        signal.signal(signal.SIGINT, stop)
        try:
            with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as events:
                events.connect(str(path))
                events.setblocking(False)
                update()
                pending = ''
                while True:
                    readable, _, _ = select.select([events], [], [], 0.5)
                    if readable:
                        chunk = events.recv(65536)
                        if not chunk:
                            break
                        pending += chunk.decode(errors='replace')
                        while '\n' in pending:
                            event, pending = pending.split('\n', 1)
                            if event.startswith(('activewindow>>', 'activewindowv2>>', 'closewindow>>', 'fullscreen>>')):
                                update()
        finally:
            if previous:
                request(False)

if __name__ == '__main__':
    main()
