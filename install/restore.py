#!/usr/bin/env python3
"""Restore the most recent work-scripts deployment from its backup manifest."""
import json
import os
from pathlib import Path
import shutil
import sys

STATE = Path(os.environ.get('XDG_STATE_HOME', Path.home() / '.local/state')) / 'work-scripts'


def latest_backup():
    backups = sorted(STATE.glob('install-backup.*'), key=lambda path: path.stat().st_mtime, reverse=True)
    for backup in backups:
        if (backup / 'manifest.json').is_file():
            return backup
    return None


def safe_target(home, relative):
    # Mirror deploy.py: never write through a symlinked parent directory.
    for parent in (home / relative).parents:
        if parent == home:
            break
        if parent.is_symlink():
            raise OSError(f'Symlinked parent directory: {parent}')
    return home / relative


def restore(backup, home):
    records = json.loads((backup / 'manifest.json').read_text())
    restored, removed = [], []
    for record in records:
        relative = Path(record['path'])
        target = safe_target(home, relative)
        action = record.get('action')
        if action in ('replaced', 'removed'):
            saved = backup / 'files' / relative
            if not (saved.is_file() or saved.is_symlink()):
                continue
            target.parent.mkdir(parents=True, exist_ok=True)
            if target.is_symlink() or target.exists():
                if target.is_dir() and not target.is_symlink():
                    raise OSError(f'Expected a file but found a directory: {target}')
                target.unlink()
            if saved.is_symlink():
                target.symlink_to(os.readlink(saved))
            else:
                shutil.copy2(saved, target)
            restored.append(str(relative))
        elif action == 'created':
            if target.is_symlink() or target.exists():
                target.unlink()
                removed.append(str(relative))
    return restored, removed


if __name__ == '__main__':
    home = Path(sys.argv[1]).expanduser().resolve() if len(sys.argv) > 1 else Path.home()
    backup = latest_backup()
    if backup is None:
        print(f'No deployment backup found in {STATE}')
        raise SystemExit(1)
    print(f'Restoring from {backup}')
    restored, removed = restore(backup, home)
    print(f'Restored {len(restored)} file(s); removed {len(removed)} created file(s).')
