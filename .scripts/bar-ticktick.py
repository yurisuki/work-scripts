#!/usr/bin/env python3
"""Read the Inbox with TickTick TUI's existing authentication; never write tasks."""
import html
import json
import os
from pathlib import Path
import tomllib
from urllib.error import URLError
from urllib.request import Request, urlopen


def inbox_tasks(tasks):
    return [task for task in tasks if task.get('status', 0) == 0
            and str(task.get('projectId', '')).startswith('inbox')]


def render(tasks, stale=False):
    tasks = inbox_tasks(tasks)
    if not tasks:
        return {'text': '', 'tooltip': '', 'class': 'empty'}
    lines = [f'TickTick Inbox · {len(tasks)} open tasks']
    if stale:
        lines.append('Cached data · open TickTick TUI to check sync/sign-in')
    lines.extend('• ' + str(task.get('title', 'Untitled')).replace('\n', ' ') for task in tasks[:10])
    if len(tasks) > 10:
        lines.append(f'… and {len(tasks) - 10} more')
    return {'text': f'  {len(tasks)}', 'tooltip': html.escape('\n'.join(lines)),
            'class': 'stale' if stale else 'inbox'}


def main():
    config = Path(os.environ.get('XDG_CONFIG_HOME', Path.home() / '.config')) / 'ttui'
    cache = Path(os.environ.get('XDG_CACHE_HOME', Path.home() / '.cache')) / 'ttui/snapshot.json'
    try:
        auth = tomllib.loads((config / 'auth.toml').read_text())
        server = auth.get('server', 'ticktick.com')
        if server not in ('ticktick.com', 'dida365.com'):
            raise ValueError('Unsupported server')
        token = auth['access_token']
        if not token:
            raise ValueError('Not signed in')
        request = Request(f'https://api.{server}/open/v1/project/inbox/data',
                          headers={'Authorization': 'Bearer ' + token})
        with urlopen(request, timeout=10) as response:
            data = json.load(response)
        tasks = data['tasks']
        # The Inbox endpoint already selects the project; tolerate missing IDs.
        tasks = [dict(task, projectId=task.get('projectId') or 'inbox') for task in tasks]
        result = render(tasks)
    except (OSError, URLError, ValueError, KeyError, TypeError):
        try:
            result = render(json.loads(cache.read_text())['Tasks'], stale=True)
        except (OSError, ValueError, KeyError, TypeError):
            result = {'text': '', 'tooltip': '', 'class': 'unavailable'}
    print(json.dumps(result))


if __name__ == '__main__':
    main()
