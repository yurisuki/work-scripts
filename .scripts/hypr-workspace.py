#!/usr/bin/env python3
"""Lua-compatible workspace actions and an event-driven shared Waybar cache."""
import fcntl
import json
import os
from pathlib import Path
import select
import signal
import socket
import subprocess
import sys
import time


def query(command):
    return json.loads(subprocess.check_output(['hyprctl', '-j', command], text=True, timeout=3))


def status(target, active, workspaces):
    occupied = workspaces.get(target, {}).get('windows', 0) > 0
    classes = ['active' if active == target else 'inactive']
    if occupied:
        classes.append('occupied')
    return {
        'text': f'{target}' + (' •' if occupied else '') if target <= 5 or occupied or active == target else '',
        'class': classes,
        'tooltip': f'Workspace {target}' + (' · open window' if occupied else ' · empty'),
    }


def watch(parent, runtime):
    # One producer per Waybar launcher. Restarting the bar releases the old lock.
    with (runtime / 'violet-workspaces.lock').open('w') as lock:
        while True:
            try:
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
                break
            except BlockingIOError:
                if not Path(f'/proc/{parent}').exists():
                    return
                time.sleep(0.2)
        path = runtime / 'hypr' / os.environ['HYPRLAND_INSTANCE_SIGNATURE'] / '.socket2.sock'
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as sock:
            sock.connect(str(path))

            def refresh(notify=True):
                active = query('activeworkspace')['id']
                workspaces = {w['id']: w for w in query('workspaces') if w['id'] > 0}
                staged = runtime / 'violet-workspaces.tmp'
                staged.write_text(json.dumps({str(i): status(i, active, workspaces) for i in range(1, 11)}))
                staged.replace(runtime / 'violet-workspaces.json')
                # Before exec(), this PID is still Python: never signal it then.
                try:
                    if notify and Path(f'/proc/{parent}/comm').read_text().strip() == 'waybar':
                        os.kill(parent, signal.SIGRTMIN + 9)
                except FileNotFoundError:
                    pass

            refresh(notify=False)
            # Ensure modules receive initial state after the launcher execs Waybar.
            time.sleep(0.5)
            refresh()
            pending = b''
            events = ('workspace', 'focusedmon', 'createworkspace', 'destroyworkspace',
                      'openwindow', 'closewindow', 'movewindow', 'moveworkspace', 'activespecial')
            while Path(f'/proc/{parent}').exists():
                if not select.select([sock], [], [], 2)[0]:
                    continue
                data = sock.recv(65536)
                if not data:
                    return
                pending += data
                lines = pending.split(b'\n')
                pending = lines.pop()
                if any(line.decode(errors='replace').startswith(events) for line in lines):
                    refresh()


def main():
    action = sys.argv[1]
    runtime = Path(os.environ['XDG_RUNTIME_DIR'])
    if action == 'watch':
        watch(int(sys.argv[2]), runtime)
    elif action == 'status':
        target = sys.argv[2]
        try:
            result = json.loads((runtime / 'violet-workspaces.json').read_text())[target]
        except (FileNotFoundError, KeyError, json.JSONDecodeError):
            result = {'text': target if int(target) <= 5 else '', 'class': 'inactive'}
        print(json.dumps(result))
    else:
        if action == 'focus':
            target = int(sys.argv[2])
        elif action in ('next', 'prev'):
            current = query('activeworkspace')['id']
            ids = sorted(set(range(1, 6)) | {w['id'] for w in query('workspaces') if w['id'] > 0} | {current})
            target = ids[(ids.index(current) + (1 if action == 'next' else -1)) % len(ids)]
        else:
            raise ValueError(f'Unknown action: {action}')
        subprocess.run(['hyprctl', 'dispatch', f'hl.dsp.focus({{ workspace = {target} }})'], check=True, timeout=3)


if __name__ == '__main__':
    main()
