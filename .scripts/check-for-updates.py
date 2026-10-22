#!/usr/bin/env python3
"""Notify once when the work-scripts checkout has new upstream commits."""
import fcntl
import json
import os
from pathlib import Path
import subprocess
import sys
import time

REMOTE = 'origin'
TIMEOUT = 30
ICON = Path.home() / '.local/share/device-notifications/icons/update-available.svg'


def state_dir():
    return Path(os.environ.get('XDG_STATE_HOME', Path.home() / '.local/state')) / 'work-scripts'


def git(repository, *arguments):
    """Return stripped stdout, or None when git fails or times out."""
    try:
        result = subprocess.run(
            ['git', '-C', str(repository), *arguments],
            capture_output=True, text=True, timeout=TIMEOUT,
        )
    except (OSError, subprocess.SubprocessError):
        return None
    return result.stdout.strip() if result.returncode == 0 else None


def repository():
    """Prefer an explicit override, then the checkout path recorded at deploy time."""
    candidates = [os.environ.get('WORK_SCRIPTS_REPO')]
    recorded = state_dir() / 'source'
    try:
        candidates.append(recorded.read_text().strip() if recorded.is_file() else None)
    except OSError:
        candidates.append(None)
    candidates.append(str(Path.home() / 'work-scripts'))
    for candidate in candidates:
        if candidate and (Path(candidate).expanduser() / '.git').exists():
            return Path(candidate).expanduser()
    return None


def branch(repository_path):
    name = git(repository_path, 'rev-parse', '--abbrev-ref', 'HEAD')
    return name if name and name != 'HEAD' else 'main'


def read_state(path):
    try:
        return json.loads(path.read_text())
    except (OSError, ValueError):
        return {}


def write_state(path, state):
    try:
        path.write_text(json.dumps(state, indent=2, sort_keys=True) + '\n')
    except OSError:
        pass


def notify(summary, body):
    """Return whether the notification daemon accepted the message."""
    icon = str(ICON) if ICON.is_file() else 'system-software-update'
    try:
        subprocess.run(
            ['notify-send', '--app-name=Work Scripts', '--expire-time=10000',
             '--urgency=normal', '--icon=' + icon,
             '--hint=boolean:suppress-sound:true', summary, body],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=10, check=True,
        )
        return True
    except (OSError, subprocess.SubprocessError):
        return False


def check(state_file):
    repository_path = repository()
    if repository_path is None:
        print('No work-scripts checkout found; set WORK_SCRIPTS_REPO.', file=sys.stderr)
        return 0
    tracking = branch(repository_path)
    local = git(repository_path, 'rev-parse', 'HEAD')
    if not local:
        print(f'{repository_path} is not a usable git checkout.', file=sys.stderr)
        return 0
    # Refresh only the remote-tracking ref; the working tree and HEAD stay untouched.
    refspec = f'+refs/heads/{tracking}:refs/remotes/{REMOTE}/{tracking}'
    if git(repository_path, 'fetch', '--quiet', '--no-tags', REMOTE, refspec) is None:
        print(f'Could not reach {REMOTE}/{tracking}; trying again on the next run.', file=sys.stderr)
        return 0
    upstream = git(repository_path, 'rev-parse', f'{REMOTE}/{tracking}')
    if not upstream:
        return 0
    state = read_state(state_file)
    now = time.strftime('%Y-%m-%dT%H:%M:%S%z')
    state.update({'source': str(repository_path), 'branch': tracking, 'checked': now,
                  'behind': 0, 'subject': ''})
    behind = git(repository_path, 'rev-list', '--count', f'HEAD..{REMOTE}/{tracking}')
    if upstream == local or behind in (None, '0'):
        # Up to date, or local commits are ahead of the upstream branch.
        if upstream != local:
            print(f'Local {tracking} is ahead of {REMOTE}/{tracking}.', file=sys.stderr)
        state['notified'] = None
        write_state(state_file, state)
        return 0
    subject = git(repository_path, 'log', '-1', '--format=%s', f'{REMOTE}/{tracking}') or ''
    state.update({'behind': int(behind), 'subject': subject})
    if state.get('notified') == upstream:
        write_state(state_file, state)
        return 0
    lines = [f'{behind} new commit{"" if behind == "1" else "s"} on {tracking}']
    if subject:
        lines.append('Latest: ' + subject[:90] + ('...' if len(subject) > 90 else ''))
    lines.append('Run upd to update.')
    if notify('work-scripts update available', '\n'.join(lines)):
        state.update({'notified': upstream, 'notified_at': now})
    write_state(state_file, state)
    return 0


def main():
    directory = state_dir()
    try:
        directory.mkdir(parents=True, exist_ok=True)
        lock = (directory / 'update-check.lock').open('a+')
    except OSError:
        return 1
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        return 0
    try:
        return check(directory / 'update-check.json')
    finally:
        lock.close()


if __name__ == '__main__':
    raise SystemExit(main())
