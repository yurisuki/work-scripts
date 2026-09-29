#!/usr/bin/env python3
"""Search the bundled Unicode emoji set in rofi and copy a selection."""
from pathlib import Path
import os
import subprocess
import sys


def main():
    # Works both from the repository and after installation into ~/.scripts.
    root = Path(__file__).resolve().parent.parent
    data = root / '.local/share/emoji/emoji-test.txt'
    entries = []
    group = subgroup = ''
    for line in data.read_text(encoding='utf-8').splitlines():
        if line.startswith('# group: '):
            group = line.removeprefix('# group: ')
        elif line.startswith('# subgroup: '):
            subgroup = line.removeprefix('# subgroup: ')
        elif line and not line.startswith('#'):
            definition, description = line.split('#', 1)
            codepoints, status = definition.split(';')
            if status.strip() not in ('fully-qualified', 'component'):
                continue
            emoji = ''.join(chr(int(code, 16)) for code in codepoints.split())
            name = description.strip().split(' ', 2)[2]
            entries.append((emoji, f'{emoji}  {name}  · {group} / {subgroup}'))

    command = ['rofi', '-no-config']
    config = Path(os.environ.get('XDG_CONFIG_HOME', str(Path.home() / '.config')))
    theme = config / 'rofi/violet-night.rasi'
    if theme.is_file():
        command += ['-theme', str(theme)]
    command += ['-dmenu', '-i', '-no-custom', '-matching', 'normal',
                '-normalize-match', '-format', 'i', '-p', 'Emoji',
                '-mesg', 'Search English names • Enter: copy • Esc: cancel']
    result = subprocess.run(command, input='\n'.join(row for _, row in entries) + '\n',
                            text=True, encoding='utf-8', stdout=subprocess.PIPE)
    if result.returncode == 1:
        return 0  # Escape leaves the clipboard untouched.
    if result.returncode != 0:
        return result.returncode
    selected = result.stdout.strip()
    if not selected.isdecimal() or int(selected) >= len(entries):
        return 1
    subprocess.run(['wl-copy', '--type', 'text/plain;charset=utf-8'],
                   input=entries[int(selected)][0].encode('utf-8'), check=True)
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        print(f'Emoji picker: {error}', file=sys.stderr)
        sys.exit(1)
