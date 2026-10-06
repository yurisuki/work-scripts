#!/usr/bin/env python3
"""Clipboard picker with cached image thumbnails and entry deletion."""
import hashlib
import os
from pathlib import Path
import re
import subprocess
import tempfile

import gi

gi.require_version('GdkPixbuf', '2.0')
from gi.repository import GdkPixbuf

IMAGE = re.compile(r'^\[\[ binary data .*\b(?:png|jpe?g|gif|webp|bmp|tiff?|svg)\b', re.IGNORECASE)


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


def main():
    cache = Path(os.environ['XDG_RUNTIME_DIR']) / 'violet-clipboard-thumbnails'
    cache.mkdir(mode=0o700, exist_ok=True)
    lines = subprocess.check_output(['cliphist', 'list'], text=True, timeout=5).splitlines()
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
        # Strip Rofi metadata delimiters from text without altering the stored entry.
        label = preview.replace('\0', '').replace('\x1f', ' ')
        if icon:
            details = re.search(r'\b(png|jpe?g|gif|webp|bmp|tiff?|svg)\b(?:\s+(\d+)x(\d+))?', preview, re.IGNORECASE)
            if details:
                label = 'Image · ' + details[1].upper()
                if details[2] and details[3]:
                    label += f' · {details[2]} × {details[3]}'
        row = label.encode()
        row += b'\0icon\x1f' + (str(icon).encode() if icon else b'text-x-generic')
        rows.append(row)
    for path in cache.glob('*.png'):
        if path.name not in used:
            path.unlink(missing_ok=True)
    result = subprocess.run([
        'rofi', '-no-config', '-theme', str(Path.home() / '.config/rofi/clipboard.rasi'),
        '-dmenu', '-show-icons', '-no-custom', '-format', 'i', '-p', 'Clipboard',
        '-kb-cancel', 'Escape,Control+g', '-kb-delete-entry', '', '-kb-custom-1', 'Shift+Delete',
        '-mesg', 'Enter  Copy    ·    Shift+Delete  Remove    ·    Esc  Close',
    ], input=b'\n'.join(rows), stdout=subprocess.PIPE, check=False)
    if result.returncode not in (0, 10):
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
    else:
        data = subprocess.check_output(['cliphist', 'decode'], input=line.encode(), timeout=5)
        subprocess.run(['wl-copy'], input=data, check=True, timeout=5)


if __name__ == '__main__':
    try:
        main()
    except (OSError, subprocess.SubprocessError) as error:
        subprocess.run(['notify-send', 'Clipboard unavailable', str(error)], check=False)
        raise SystemExit(1)
