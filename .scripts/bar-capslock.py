#!/usr/bin/env python3
"""Show Caps Lock only while enabled, without intercepting keyboard input."""
import json
from pathlib import Path
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
    previous = None
    while True:
        current = enabled()
        if current != previous:
            print(json.dumps({'text': '󰘲' if current else '',
                              'tooltip': 'Caps Lock is on' if current else '',
                              'class': 'active' if current else 'inactive'}), flush=True)
            previous = current
        time.sleep(0.1)


if __name__ == '__main__':
    try:
        main()
    except BrokenPipeError:
        pass
