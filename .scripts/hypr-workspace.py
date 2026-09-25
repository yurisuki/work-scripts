#!/usr/bin/env python3
import json
import subprocess
import sys

def query(command):
    return json.loads(subprocess.check_output(['hyprctl', '-j', command], text=True, timeout=3))

action = sys.argv[1]
if action == 'status':
    target = int(sys.argv[2])
    active = query('activeworkspace')['id']
    workspaces = {workspace['id']: workspace for workspace in query('workspaces') if workspace['id'] > 0}
    occupied = workspaces.get(target, {}).get('windows', 0) > 0
    state = ['active' if active == target else 'inactive']
    if occupied:
        state.append('occupied')
    marker = ' •' if occupied else ''
    print(json.dumps({
        'text': f'{target}{marker}' if target <= 5 or occupied or active == target else '',
        'class': state,
        'tooltip': f'Workspace {target}' + (' · open window' if occupied else ' · empty'),
    }))
else:
    if action == 'focus':
        target = int(sys.argv[2])
    else:
        current = query('activeworkspace')['id']
        ids = sorted(set(range(1, 6)) | {w['id'] for w in query('workspaces') if w['id'] > 0})
        target = ids[(ids.index(current) + (1 if action == 'next' else -1)) % len(ids)]
    subprocess.run(['hyprctl', 'dispatch', f'hl.dsp.focus({{ workspace = {target} }})'], check=True, timeout=3)
