#!/usr/bin/env python3
"""Waybar brightness for laptop backlights or the first DDC/CI monitor."""
import fcntl
import json
import os
from pathlib import Path
import re
import subprocess
import sys


def run(*args):
    return subprocess.check_output(args, text=True, stderr=subprocess.DEVNULL, timeout=5).strip()


def main():
    action = sys.argv[1] if len(sys.argv) > 1 else 'status'
    if action not in ('status', 'up', 'down', 'set'):
        raise ValueError('Expected status, up, down, or set PERCENT')
    runtime = Path(os.environ.get('XDG_RUNTIME_DIR', '/tmp'))
    with (runtime / f'violet-brightness-{os.getuid()}.lock').open('w') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        devices = sorted(Path('/sys/class/backlight').glob('*'))
        if devices:
            device = devices[0].name
            current = int(run('brightnessctl', '-d', device, 'get'))
            maximum = int(run('brightnessctl', '-d', device, 'max'))
            backend = 'Backlight'
        else:
            config = Path.home() / '.config/hypr/brightness.json'
            display = str(json.loads(config.read_text()).get('ddc_display', 1)) if config.exists() else '1'
            output = run('ddcutil', '--display', display, '--brief', 'getvcp', '10')
            match = re.search(r'VCP\s+10\s+C\s+(\d+)\s+(\d+)', output)
            if not match:
                raise RuntimeError('Monitor did not report brightness')
            current, maximum = map(int, match.groups())
            backend = f'DDC/CI monitor {display}'
        percent = round(current * 100 / maximum)
        if action == 'status':
            print(json.dumps({'text': f'󰃠  {percent}%', 'tooltip': f'{backend} · Scroll to adjust; click for presets', 'class': 'available'}))
            return
        target = int(sys.argv[2]) if action == 'set' else percent + (5 if action == 'up' else -5)
        target = max(5, min(100, target))
        if devices:
            run('brightnessctl', '-d', device, 'set', f'{target}%')
        else:
            run('ddcutil', '--display', display, 'setvcp', '10', str(round(target * maximum / 100)))
        subprocess.run(['pkill', '-RTMIN+8', '-x', 'waybar'], check=False)


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError, ZeroDivisionError, IndexError) as error:
        if len(sys.argv) < 2 or sys.argv[1] == 'status':
            print(json.dumps({'text': '󰃠  —', 'tooltip': 'Brightness unavailable. Enable DDC/CI in your monitor menu. For another monitor set ddc_display in ~/.config/hypr/brightness.json.', 'class': 'unavailable'}))
        else:
            subprocess.run(['notify-send', 'Brightness unavailable', str(error)], check=False)
            sys.exit(1)
