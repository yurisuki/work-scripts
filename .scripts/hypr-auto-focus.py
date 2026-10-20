#!/usr/bin/env python3
"""Request focus mode for fullscreen video and games."""
import fcntl
import json
import os
from pathlib import Path
import select
import signal
import socket
import subprocess

BROWSER_CLASSES = {
    'brave', 'brave-browser', 'chromium', 'chromium-browser',
    'google-chrome', 'google-chrome-stable', 'firefox', 'librewolf',
    'vivaldi', 'microsoft-edge', 'floorp', 'zen',
}
GAME_MARKERS = (
    'steam_app_', 'osu', 'minecraft', 'lutris', 'heroic', 'wine',
    'godot', 'unity', 'unreal', 'proton', 'gamescope',
)
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
    if not (bool(window.get('address')) and bool(window.get('mapped', True)) and bool(window.get('fullscreen', 0))):
        return False
    app = str(window.get('class') or window.get('initialClass') or '').lower()
    if app in BROWSER_CLASSES:
        return True
    return any(marker in app for marker in GAME_MARKERS)

def recording_screen():
    """Return true while PipeWire has an active screen-capture stream."""
    try:
        nodes = json.loads(subprocess.check_output(['pw-dump'], text=True, timeout=2))
    except (OSError, subprocess.SubprocessError):
        return False
    for node in nodes:
        props = (node.get('info') or {}).get('props') or {}
        if (props.get('media.class') == 'Stream/Input/Video' and
                props.get('media.category') == 'Capture'):
            return True
    return False

def requires_focus(window):
    if recording_screen():
        return True
    app = str(window.get('class') or window.get('initialClass') or '').lower()
    return is_fullscreen(window)

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
            enabled = requires_focus(active_window())
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
                    # Recorder processes can start or stop without a Hyprland event.
                    update()
        finally:
            if previous:
                request(False)

if __name__ == '__main__':
    main()
