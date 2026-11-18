#!/usr/bin/env python3
"""Show a printer indicator only while CUPS still has unfinished jobs."""
import html
import json
import subprocess

ICON = '󰐪'  # nf-md-printer


def queue():
    result = subprocess.run(
        ['lpstat', '-W', 'not-completed', '-o'],
        capture_output=True, text=True, timeout=3, check=False,
    )
    if result.returncode != 0:
        return []
    return [line for line in result.stdout.splitlines() if line.strip()]


def render(jobs):
    if not jobs:
        return {'text': '', 'tooltip': '', 'class': 'idle'}
    count = len(jobs)
    text = f'{ICON}  {count}'
    lines = [f'{count} print job{"" if count == 1 else "s"} in progress']
    lines.extend(html.escape(line)[:120] for line in jobs)
    lines.append('Click to open Print Settings')
    return {'text': text, 'tooltip': '\n'.join(lines), 'class': 'active'}


if __name__ == '__main__':
    try:
        print(json.dumps(render(queue()), ensure_ascii=False), flush=True)
    except (OSError, subprocess.SubprocessError):
        print(json.dumps({'text': '', 'tooltip': '', 'class': 'idle'}), flush=True)
