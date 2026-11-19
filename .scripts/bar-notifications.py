#!/usr/bin/env python3
"""Preserve SwayNC's live status and highlight it while focus mode is active."""
import fcntl
import json
import os
from pathlib import Path
import selectors
import subprocess
import sys
import time


def notification_count(payload):
    text = str(payload.get('text', ''))
    digits = ''.join(value for value in text if value.isdigit())
    return int(digits) if digits else 0


def decorate(payload, focus):
    result = dict(payload)
    classes = result.get('class', [])
    if isinstance(classes, str):
        classes = [classes]
    result['class'] = [value for value in classes if value not in ('focus', 'unread')]
    if notification_count(result) >= 1:
        result['class'].append('unread')
    result['alt'] = 'focus-on' if focus else 'focus-off'
    if focus:
        result['class'].append('focus')
        result['tooltip'] = 'Focus mode active · DND + keep screen awake\nSuper+Ctrl+F to disable'
    return result


def main():
    # A Waybar config reload spawns a new watcher without killing this one.
    # One instance at a time; the heartbeat below notices the closed stdout pipe.
    runtime = Path(os.environ['XDG_RUNTIME_DIR'])
    with (runtime / 'violet-bar-notifications.lock').open('w') as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return
        child = subprocess.Popen(['swaync-client', '-swb'], stdout=subprocess.PIPE)
        selector = selectors.DefaultSelector()
        selector.register(child.stdout, selectors.EVENT_READ)
        payload = None
        previous = None
        pending = b''
        last_beat = 0.0
        try:
            while True:
                if selector.select(timeout=1):
                    chunk = os.read(child.stdout.fileno(), 65536)
                    if not chunk:
                        break
                    pending += chunk
                    while b'\n' in pending:
                        line, pending = pending.split(b'\n', 1)
                        try:
                            payload = json.loads(line)
                        except (ValueError, UnicodeError):
                            continue
                if payload is None:
                    continue
                try:
                    focus = subprocess.run(
                        ['systemctl', '--user', 'is-active', '--quiet', 'violet-focus.service'],
                        timeout=2, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                    ).returncode == 0
                except (OSError, subprocess.TimeoutExpired):
                    focus = False
                current = json.dumps(decorate(payload, focus), ensure_ascii=False)
                now = time.monotonic()
                if current != previous or now - last_beat >= 3:
                    print(current, flush=True)
                    previous = current
                    last_beat = now
        finally:
            selector.close()
            child.terminate()
            child.wait()


if __name__ == '__main__':
    try:
        main()
    except BrokenPipeError:
        os.dup2(os.open(os.devnull, os.O_WRONLY), sys.stdout.fileno())
        sys.exit(0)
