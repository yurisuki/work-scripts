#!/usr/bin/env python3
"""Show how many upstream work-scripts commits are waiting, if any."""
import json
import os
from pathlib import Path
import time

ICON = '\uf409'
STATE = (Path(os.environ.get('XDG_STATE_HOME', Path.home() / '.local/state'))
         / 'work-scripts/update-check.json')


def checked_line(value):
    try:
        moment = time.strptime(str(value)[:19], '%Y-%m-%dT%H:%M:%S')
    except ValueError:
        return None
    return 'Checked ' + time.strftime('%H:%M', moment)


def payload():
    try:
        state = json.loads(STATE.read_text())
    except (OSError, ValueError):
        state = {}
    try:
        behind = int(state.get('behind') or 0)
    except (TypeError, ValueError):
        behind = 0
    if behind < 1:
        return {'text': '', 'tooltip': '', 'class': 'current'}
    branch = state.get('branch') or 'main'
    lines = [f'{behind} new commit{"" if behind == 1 else "s"} on {branch}']
    if state.get('subject'):
        lines.append('Latest: ' + str(state['subject'])[:90])
    checked = checked_line(state.get('checked')) if state.get('checked') else None
    if checked:
        lines.append(checked)
    lines.append('Click to update')
    return {'text': f'{ICON}\u2002{behind}', 'tooltip': '\n'.join(lines), 'class': 'update'}


if __name__ == '__main__':
    print(json.dumps(payload(), ensure_ascii=False), flush=True)
