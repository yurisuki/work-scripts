#!/usr/bin/env python3
"""Add the UWSM login block without replacing the distribution's profile."""
from pathlib import Path
import re
import shutil
import sys
import tempfile

BLOCK = '''if uwsm check may-start && uwsm select; then
    exec uwsm start default
fi
'''


def configure(profile):
    original = profile.read_text()
    # Recognize the existing hand-written block, including different indentation.
    pattern = r'if\s+uwsm check may-start\s*&&\s*uwsm select;\s*then\s+exec\s+uwsm start default\s*;?\s*fi\b'
    if re.search(pattern, original):
        return None
    if re.search(r'^[^#\n]*\buwsm\b', original, re.MULTILINE):
        raise ValueError('Unrecognized UWSM configuration in profile; refusing to add a second launcher.')
    with tempfile.NamedTemporaryFile(prefix=profile.name + '.backup.', dir=profile.parent, delete=False) as saved:
        backup = Path(saved.name)
    shutil.copy2(profile, backup)
    try:
        profile.write_text(original.rstrip('\n') + '\n\n# UWSM: start the selected session on an eligible TTY login.\n' + BLOCK)
    except BaseException:
        shutil.copy2(backup, profile)
        raise
    return backup


if __name__ == '__main__':
    backup = configure(Path(sys.argv[1]))
    print(f'UWSM profile configured; backup: {backup}' if backup else 'UWSM profile already configured.')
