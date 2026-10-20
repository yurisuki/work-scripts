#!/usr/bin/env python3
"""Render the bar's shared weather reading for Hyprlock."""
import html
import json
from pathlib import Path
import subprocess
import sys

from weather_common import read_settings


def main():
    settings = read_settings()
    if not settings['location']:
        return
    bar = Path(__file__).with_name('bar-weather.py')
    try:
        result = json.loads(subprocess.check_output(
            [sys.executable, str(bar)], timeout=18, text=True,
        ))
    except (OSError, ValueError, subprocess.SubprocessError):
        result = {}
    saved = json.loads((Path.home() / '.cache/waybar/weather.json').read_text())
    if saved.get('query') != settings['query'] or saved.get('units') != settings['units']:
        return
    text = saved.get('lock_text') or (
        saved.get('result', {}).get('text', '') + '\n' + saved['location']
    )
    if saved.get('lock_text') and not saved.get('icons_version'):
        text = '☁ ' + text
    # Replace the location in older cached readings as well as new ones.
    text = text.partition('\n')[0] + '\n' + settings['location']
    if text and (not result or 'Offline' in result.get('tooltip', '')):
        text += '\nOffline · last available weather'
    print(html.escape(text))


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, KeyError):
        pass
