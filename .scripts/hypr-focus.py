#!/usr/bin/env python3
"""Toggle DND and a systemd idle inhibitor, preserving the prior DND setting."""
import fcntl
import json
import os
from pathlib import Path
import subprocess
import sys

UNIT = 'violet-focus.service'
NOTIFICATIONS_UNIT = 'violet-focus-notifications.service'
ICONS = Path.home() / '.local/share/device-notifications/icons'


def run(*args):
    return subprocess.check_output(args, text=True, timeout=10).strip()


def active():
    return subprocess.run(['systemctl', '--user', 'is-active', '--quiet', UNIT], timeout=5).returncode == 0


def notify_state(enabled):
    subprocess.run([
        str(Path.home() / '.scripts/hypr-osd.py'), 'focus', '100' if enabled else '0',
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
    if action not in ('toggle', 'osu-on', 'osu-off', 'fullscreen-on', 'fullscreen-off', 'inhibit-on', 'inhibit-off'):
        raise ValueError(f'Unknown action: {action}')
    with (runtime / 'violet-focus.lock').open('w') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        was_active = active()
        saved = json.loads(state.read_text()) if state.exists() else {}
        # Older sessions have only the saved DND state; treat them as manual.
        saved.setdefault('manual', was_active)
        saved.setdefault('osu', False)
        saved.setdefault('fullscreen', False)
        saved.setdefault('inhibit', False)
        if action == 'toggle':
            saved['manual'] = not saved['manual']
        else:
            if action.startswith('osu-'):
                saved['osu'] = action == 'osu-on'
            elif action.startswith('fullscreen-'):
                saved['fullscreen'] = action == 'fullscreen-on'
            else:
                saved['inhibit'] = action == 'inhibit-on'
        enabled = saved['manual'] or saved['osu'] or saved['fullscreen'] or saved['inhibit']
        if not enabled and was_active:
            run('systemctl', '--user', 'stop', UNIT)
            previous = saved.get('dnd', False)
            run('swaync-client', '-dn' if previous else '-df', '-sw')
            state.unlink(missing_ok=True)
            if saved.get('notifications'):
                try:
                    subprocess.run([str(Path.home() / '.scripts/hypr-focus-notifications.py'), 'replay'],
                                   check=True, timeout=20)
                finally:
                    run('systemctl', '--user', 'stop', NOTIFICATIONS_UNIT)
        elif enabled and not was_active:
            previous = run('swaync-client', '-D', '-sw').lower() == 'true'
            saved['dnd'] = previous
            try:
                # Start monitoring before DND, so even the first notification is captured.
                run('systemctl', '--user', 'start', NOTIFICATIONS_UNIT)
                saved['notifications'] = True
                run('systemd-run', '--user', '--collect', '--unit=violet-focus',
                    '--property=PartOf=graphical-session.target',
                    'systemd-inhibit', '--what=idle', '--who=Violet Night', '--why=Work mode',
                    '--mode=block', 'sleep', 'infinity')
                run('swaync-client', '-dn', '-sw')
            except Exception:
                subprocess.run(['systemctl', '--user', 'stop', UNIT, NOTIFICATIONS_UNIT], check=False)
                subprocess.run(['swaync-client', '-dn' if previous else '-df', '-sw'], check=False)
                state.unlink(missing_ok=True)
                raise
        if enabled:
            state.write_text(json.dumps(saved))
        else:
            state.unlink(missing_ok=True)
        if action == 'toggle':
            notify_state(enabled)


if __name__ == '__main__':
    try:
        main()
    except (subprocess.SubprocessError, OSError, ValueError) as error:
        subprocess.run(['notify-send', '--icon=' + str(ICONS / 'warning.svg'), 'Work mode failed', str(error)], check=False)
        raise SystemExit(1)
