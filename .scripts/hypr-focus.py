#!/usr/bin/env python3
"""Toggle DND and a systemd idle inhibitor, preserving the prior DND setting."""
import fcntl
import json
import os
from pathlib import Path
import subprocess
import sys

UNIT = 'violet-focus.service'


def run(*args):
    return subprocess.check_output(args, text=True, timeout=10).strip()


def active():
    return subprocess.run(['systemctl', '--user', 'is-active', '--quiet', UNIT], timeout=5).returncode == 0


def notify_state(enabled):
    subprocess.run([
        'notify-send', '--app-name=Violet Night', '--expire-time=3000',
        '--hint=boolean:SWAYNC_BYPASS_DND:true',
        'Focus mode enabled' if enabled else 'Focus mode disabled',
        'Do not disturb is on. The screen will stay awake.' if enabled
        else 'Previous notification and idle settings restored.',
    ], check=False, timeout=5)


def main():
    runtime = Path(os.environ['XDG_RUNTIME_DIR'])
    state = runtime / 'violet-focus.json'
    action = sys.argv[1] if len(sys.argv) > 1 else 'toggle'
    if action == 'status':
        enabled = active()
        print(json.dumps({'text': '󰒳' if enabled else '󰾰', 'class': 'active' if enabled else 'inactive',
                          'tooltip': 'Work mode: DND + keep screen awake' if enabled else 'Work mode off · click to enable'}))
        return
    if action != 'toggle':
        raise ValueError(f'Unknown action: {action}')
    with (runtime / 'violet-focus.lock').open('w') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        enabled = not active()
        if not enabled:
            run('systemctl', '--user', 'stop', UNIT)
            previous = json.loads(state.read_text())['dnd'] if state.exists() else False
            run('swaync-client', '-dn' if previous else '-df', '-sw')
            state.unlink(missing_ok=True)
        else:
            previous = run('swaync-client', '-D', '-sw').lower() == 'true'
            state.write_text(json.dumps({'dnd': previous}))
            try:
                run('systemd-run', '--user', '--collect', '--unit=violet-focus',
                    '--property=PartOf=graphical-session.target',
                    'systemd-inhibit', '--what=idle', '--who=Violet Night', '--why=Work mode',
                    '--mode=block', 'sleep', 'infinity')
                run('swaync-client', '-dn', '-sw')
            except Exception:
                run('systemctl', '--user', 'stop', UNIT)
                state.unlink(missing_ok=True)
                raise
        notify_state(enabled)


if __name__ == '__main__':
    try:
        main()
    except (subprocess.SubprocessError, OSError, ValueError) as error:
        subprocess.run(['notify-send', 'Work mode failed', str(error)], check=False)
        raise SystemExit(1)
