#!/usr/bin/env python3
"""Store clipboard text in cliphist, keeping rich text alongside plain text.

wl-paste --watch runs this with the plain-text selection on stdin. When the
selection also offers text/html, keep both forms in one cliphist entry so the
picker can restore either one with the correct MIME type.
"""
import base64
import os
import subprocess
import sys

MARKER = b'\x1e[[ rich:text/html ]]\x1e'


def main():
    state = os.environ.get('CLIPBOARD_STATE', '')
    plain = sys.stdin.buffer.read()

    # Preserve cliphist's handling of cleared and sensitive selections.
    if state == 'sensitive':
        return
    if state == 'clear':
        subprocess.run(['cliphist', 'store'], input=b'', check=False, timeout=5)
        return

    payload = plain
    try:
        types = subprocess.check_output(['wl-paste', '--list-types'], text=True, timeout=5).split()
        if 'text/html' in types:
            html = subprocess.check_output(['wl-paste', '--type', 'text/html', '--no-newline'], timeout=5)
            if html.strip():
                payload = plain + MARKER + base64.b64encode(html)
    except (OSError, subprocess.SubprocessError):
        pass  # Fall back to the plain text already received on stdin.

    if payload.strip():
        subprocess.run(['cliphist', 'store'], input=payload, check=False, timeout=5)


if __name__ == '__main__':
    try:
        main()
    except (OSError, subprocess.SubprocessError):
        raise SystemExit(1)
