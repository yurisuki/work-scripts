#!/usr/bin/env python3
"""One quiet login reminder for all incomplete TickTick tasks."""
import fcntl
import html
import json
import os
from pathlib import Path
import re
import subprocess
import time
import tomllib
from urllib.error import URLError
from urllib.request import Request, urlopen


def api(path, payload=None):
    config = Path(os.environ.get('XDG_CONFIG_HOME', Path.home() / '.config')) / 'ttui/auth.toml'
    auth = tomllib.loads(config.read_text())
    server = auth.get('server', 'ticktick.com')
    if server not in ('ticktick.com', 'dida365.com') or not auth.get('access_token'):
        raise ValueError('TickTick sign-in unavailable')
    request = Request('https://api.' + server + '/open/v1' + path,
                      data=json.dumps(payload).encode() if payload is not None else None,
                      headers={'Authorization': 'Bearer ' + auth['access_token'],
                               'Content-Type': 'application/json'})
    with urlopen(request, timeout=10) as response:
        return json.load(response)


def incomplete(tasks):
    seen = set()
    result = []
    for task in tasks:
        identity = task.get('id')
        if task.get('status', 0) == 0 and identity and identity not in seen:
            seen.add(identity)
            result.append(task)
    return result


def fetch_tasks():
    tasks = api('/task/filter', {'status': [0]})
    if not isinstance(tasks, list):
        raise ValueError('Unexpected task response')
    # The TUI's filter endpoint is capped at 200: fetch each list if saturated.
    if len(tasks) >= 200:
        projects = api('/project')
        ids = ['inbox'] + [p['id'] for p in projects if not p.get('closed')]
        tasks = []
        for project in ids:
            tasks.extend(api('/project/' + project + '/data')['tasks'])
    return incomplete(tasks)


def cached_tasks():
    cache = Path(os.environ.get('XDG_CACHE_HOME', Path.home() / '.cache')) / 'ttui/snapshot.json'
    return incomplete(json.loads(cache.read_text())['Tasks'])


def notification(tasks, stale=False):
    if not tasks:
        return None
    lines = ['Cached tasks · last synced in TickTick TUI'] if stale else []
    lines += ['• ' + str(t.get('title', 'Untitled')).replace('\n', ' ') for t in tasks[:8]]
    if len(tasks) > 8:
        lines.append(f'… and {len(tasks) - 8} more')
    lines.append('Super+U opens TickTick TUI.')
    title = f'TickTick · {len(tasks)} incomplete ' + ('task' if len(tasks) == 1 else 'tasks')
    return title, html.escape('\n'.join(lines))


def main():
    runtime = Path(os.environ['XDG_RUNTIME_DIR'])
    signature = re.sub(r'[^a-zA-Z0-9_-]', '_', os.environ.get('HYPRLAND_INSTANCE_SIGNATURE', 'session'))
    marker = runtime / ('ticktick-startup-' + signature + '.done')
    with (runtime / 'ticktick-startup.lock').open('w') as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return
        if marker.exists():
            return
        time.sleep(8)
        tasks = None
        stale = False
        for delay in (0, 10, 20):
            if delay:
                time.sleep(delay)
            try:
                tasks = fetch_tasks()
                break
            except (OSError, ValueError, KeyError, TypeError, URLError):
                continue
        if tasks is None:
            try:
                tasks = cached_tasks()
                stale = True
            except (OSError, ValueError, KeyError, TypeError):
                return
        message = notification(tasks, stale)
        if message:
            result = subprocess.run(
                ['notify-send', '--app-name=TickTick', '--expire-time=12000',
                 '--hint=boolean:suppress-sound:true',
                 '--icon=' + str(Path.home() / '.local/share/device-notifications/icons/ticktick.svg'),
                 message[0], message[1]], timeout=5,
            )
            if result.returncode != 0:
                return
        marker.touch(mode=0o600)


if __name__ == '__main__':
    main()
