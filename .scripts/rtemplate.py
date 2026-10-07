#!/usr/bin/env python3
"""Select, preview, and copy text templates using the Violet Night Rofi theme."""
from datetime import datetime
import fcntl
import html
import os
from pathlib import Path
import re
import subprocess

VARIABLE = re.compile(r'\$\{(DATETIME|DATE|TIME|CLIPBOARD)\}|\$(DATETIME|DATE|TIME|CLIPBOARD)\b')


def render_template(content, clipboard, now=None):
    now = now or datetime.now()
    values = {
        'DATE': now.strftime('%Y-%m-%d'),
        'TIME': now.strftime('%H:%M'),
        'DATETIME': now.strftime('%Y-%m-%d %H:%M'),
        'CLIPBOARD': clipboard,
    }
    # Expand each token once; clipboard text is never evaluated or re-expanded.
    return VARIABLE.sub(lambda match: values[match[1] or match[2]], content)


def read_template(path):
    with path.open(encoding='utf-8-sig', newline='') as stream:
        return stream.read()


def list_templates(directory):
    templates = []
    for path in sorted(directory.rglob('*'), key=lambda path: str(path.relative_to(directory)).casefold()):
        if not path.is_file() or any(part.startswith('.') for part in path.relative_to(directory).parts):
            continue
        try:
            content = read_template(path)
        except (OSError, UnicodeError):
            continue
        if '\0' not in content:
            templates.append((path, content))
    return templates


def menu_rows(templates, directory):
    rows = []
    for path, content in templates:
        name = str(path.relative_to(directory)).replace('\n', ' ')
        preview = ' '.join(content.split())[:95] or 'Empty template'
        label = html.escape(name) + '&#10;<span size="small" foreground="#b4a3c4">' + html.escape(preview) + '</span>'
        rows.append(label.encode() + b'\0icon\x1ftext-x-generic')
    return b'\n'.join(rows)


def notify(summary, body):
    subprocess.run(['notify-send', '--app-name=rtemplate', '--icon=edit-copy',
                    '--expire-time=2500', summary, body], check=False)


def main():
    runtime = Path(os.environ['XDG_RUNTIME_DIR'])
    with (runtime / 'violet-rtemplate.lock').open('w') as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return
        directory = Path.home() / 'Dokumenty/Ralakde/Zoho WorkDrive (Ralakde)/My Folders/rtemplate list'
        directory.mkdir(parents=True, exist_ok=True)
        templates = list_templates(directory)
        # Snapshot text before Rofi takes focus; binary clipboard data stays untouched.
        clipboard = subprocess.run(['wl-paste', '--type', 'text', '--no-newline'],
                                   capture_output=True, timeout=3, check=False)
        snapshot = clipboard.stdout.decode('utf-8', errors='replace') if clipboard.returncode == 0 else ''
        result = subprocess.run([
            'rofi', '-no-config', '-theme', str(Path.home() / '.config/rofi/templates.rasi'),
            '-dmenu', '-i', '-show-icons', '-markup-rows', '-format', 'i',
            *(['-no-custom'] if templates else []),
            '-p', 'Templates', '-selected-row', '0', '-kb-cancel', 'Escape,Control+g',
            '-kb-custom-1', 'Alt+o', '-kb-custom-2', 'Alt+e',
            '-mesg', 'Enter  Copy    ·    Alt+E  Edit    ·    Alt+O  Folder    ·    Esc  Close',
        ], input=menu_rows(templates, directory), stdout=subprocess.PIPE, check=False)
        if result.returncode not in (0, 10, 11):
            return
        if result.returncode == 10:
            subprocess.Popen(['kitty', '--title', 'superfile', '--directory', str(directory), '-e', 'spf'])
            return
        try:
            index = int(result.stdout.strip())
        except ValueError:
            return
        if not 0 <= index < len(templates):
            return
        path = templates[index][0]
        if result.returncode == 11:
            subprocess.Popen(['kitty', '--title', 'Template editor', '-e', 'nvim', str(path)])
            return
        content = read_template(path)
        processed = render_template(content, snapshot)
        subprocess.run(['wl-copy', '--type', 'text/plain;charset=utf-8'], input=processed.encode(), check=True, timeout=5)
        notify('Template copied', str(path.relative_to(directory)))


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        notify('Templates unavailable', str(error))
        raise SystemExit(1)
