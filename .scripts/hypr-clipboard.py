#!/usr/bin/env python3
"""Clipboard picker with cached image thumbnails and entry deletion."""
import base64
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile

import gi

gi.require_version('GdkPixbuf', '2.0')
from gi.repository import GdkPixbuf

IMAGE = re.compile(r'^\[\[ binary data .*\b(?:png|jpe?g|gif|webp|bmp|tiff?|svg)\b', re.IGNORECASE)
ICON = Path.home() / '.local/share/device-notifications/icons/clipboard.svg'
TRASH = Path.home() / '.local/share/device-notifications/icons/clipboard-deleted.svg'
# cliphist stores rich text as: plain text + MARKER + base64(text/html)
MARKER = b'\x1e[[ rich:text/html ]]\x1e'


def notify(summary, body, icon=ICON):
    subprocess.run([
        'notify-send', '--app-name=Clipboard', '--icon=' + str(icon),
        '--expire-time=3000', '--hint=boolean:suppress-sound:true', summary, body,
    ], check=False)


def thumbnail(line, cache):
    key = hashlib.sha256(line.encode()).hexdigest()
    target = cache / (key + '.png')
    if target.exists():
        return target
    try:
        data = subprocess.check_output(['cliphist', 'decode'], input=line.encode(), timeout=5)
        with tempfile.NamedTemporaryFile(dir=cache, suffix='.image') as raw:
            raw.write(data)
            raw.flush()
            image = GdkPixbuf.Pixbuf.new_from_file_at_scale(raw.name, 192, 144, True)
            # Atomic replacement keeps parallel pickers from seeing partial PNGs.
            with tempfile.NamedTemporaryFile(dir=cache, suffix='.png', delete=False) as staged:
                staged_path = Path(staged.name)
            try:
                image.savev(str(staged_path), 'png', [], [])
                staged_path.replace(target)
            finally:
                staged_path.unlink(missing_ok=True)
        return target
    except Exception:
        return None


def confirm_clear():
    result = subprocess.run([
        'rofi', '-no-config', '-theme', str(Path.home() / '.config/rofi/violet-night-dialog.rasi'),
        '-dmenu', '-no-custom', '-p', 'Clear all clipboard history?',
    ], input=b'Cancel\nClear all', stdout=subprocess.PIPE, check=False)
    return result.returncode == 0 and result.stdout.strip() == b'Clear all'


def main():
    cache = Path(os.environ['XDG_RUNTIME_DIR']) / 'violet-clipboard-thumbnails'
    cache.mkdir(mode=0o700, exist_ok=True)
    # split('\n') rather than splitlines(): \x1e in rich entries is a line separator to Python.
    lines = [line for line in subprocess.check_output(['cliphist', 'list'], text=True, timeout=5).split('\n') if line]
    if not lines:
        notify('Clipboard is empty', 'Nothing copied yet.')
        return
    rows = []
    used = set()
    for line in lines:
        _, separator, preview = line.partition('\t')
        if not separator:
            preview = line
        icon = None
        if IMAGE.match(preview):
            icon = thumbnail(line, cache)
            if icon:
                used.add(icon.name)
        # Strip Rofi metadata delimiters and the rich-text payload from the label.
        label = preview.split('\x1e')[0].replace('\0', '').replace('\x1f', ' ')
        if icon:
            details = re.search(r'\b(png|jpe?g|gif|webp|bmp|tiff?|svg)\b(?:\s+(\d+)x(\d+))?', preview, re.IGNORECASE)
            if details:
                label = 'Image · ' + details[1].upper()
                if details[2] and details[3]:
                    label += f' · {details[2]} × {details[3]}'
        label = " ".join(label.split())
        if len(label) > 70:
            label = label[:69] + "…"
        row = label.encode()
        row += b'\0icon\x1f' + (str(icon).encode() if icon else b'text-x-generic')
        rows.append(row)
    for path in cache.glob('*.png'):
        if path.name not in used:
            path.unlink(missing_ok=True)
    result = subprocess.run([
        'rofi', '-no-config', '-theme', str(Path.home() / '.config/rofi/clipboard.rasi'),
        '-dmenu', '-show-icons', '-no-custom', '-format', 'i', '-p', 'Clipboard',
        '-kb-cancel', 'Escape,Control+g', '-kb-delete-entry', '',
        '-kb-accept-alt', '', '-kb-accept-custom', '',
        '-kb-custom-1', 'Shift+Delete', '-kb-custom-2', 'Control+Delete',
        '-kb-custom-3', 'Shift+Return,Shift+KP_Enter',
        '-mesg', 'Enter  Copy    ·    Shift+Enter  Plain text    ·    Shift+Del  Remove    ·    Ctrl+Del  Clear all    ·    Esc  Close',
    ], input=b'\n'.join(rows), stdout=subprocess.PIPE, check=False)
    if result.returncode not in (0, 10, 11, 12):
        return
    if result.returncode == 11:
        if confirm_clear():
            subprocess.run(['cliphist', 'wipe'], check=True, timeout=5)
            subprocess.run(['wl-copy', '--clear'], check=True, timeout=5)
            notify('Clipboard history cleared', 'All copied items have been removed.', TRASH)
        return
    try:
        index = int(result.stdout.strip())
    except ValueError:
        return
    if not 0 <= index < len(lines):
        return
    line = lines[index]
    if result.returncode == 10:
        subprocess.run(['cliphist', 'delete'], input=line.encode(), check=True, timeout=5)
        (cache / (hashlib.sha256(line.encode()).hexdigest() + '.png')).unlink(missing_ok=True)
        entry = label if len(label) <= 80 else label[:77] + '…'
        notify('Clipboard entry removed', entry or 'One copied item removed.', TRASH)
    else:
        data = subprocess.check_output(['cliphist', 'decode'], input=line.encode(), timeout=5)
        if MARKER in data:
            # Enter serves the original HTML; Shift+Enter serves the plain text.
            plain, _, encoded = data.partition(MARKER)
            if result.returncode == 12:
                subprocess.run(['wl-copy', '--type', 'text/plain;charset=utf-8', '--trim-newline'],
                               input=plain, check=True, timeout=5)
            else:
                # Offer HTML and clean text as separate payloads in one selection.
                html = base64.b64decode(encoded)
                payload = json.dumps({
                    'plain': base64.b64encode(plain).decode(),
                    'html': base64.b64encode(html).decode(),
                }).encode()
                helper = subprocess.Popen(
                    [str(Path.home() / '.scripts/clipboard-set-rich.py')],
                    stdin=subprocess.PIPE, stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL, start_new_session=True,
                )
                helper.stdin.write(payload)
                helper.stdin.close()
        else:
            subprocess.run(['wl-copy'], input=data, check=True, timeout=5)


if __name__ == '__main__':
    try:
        main()
    except (OSError, subprocess.SubprocessError) as error:
        subprocess.run(['notify-send', 'Clipboard unavailable', str(error)], check=False)
        raise SystemExit(1)
