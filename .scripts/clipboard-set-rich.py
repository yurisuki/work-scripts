#!/usr/bin/env python3
"""Serve formatted clipboard text with distinct HTML and plain-text payloads.

wl-copy can only offer one payload, so plain-text apps pasting an HTML copy
receive raw tags. GTK can offer both MIME types with their own data.
Reads {"plain": <base64>, "html": <base64>} from stdin and owns the clipboard
until another application takes it over.
"""
import base64
import json
import os
import subprocess
import sys

os.environ.pop('DISPLAY', None)
os.environ['GDK_BACKEND'] = 'wayland'

import gi

gi.require_version('Gtk', '4.0')
gi.require_version('Gdk', '4.0')
from gi.repository import Gtk, Gdk, GLib


def main():
    data = json.load(sys.stdin)
    plain = base64.b64decode(data['plain'])
    html = base64.b64decode(data['html'])

    try:
        Gtk.init()
        display = Gdk.Display.get_default()
    except Exception:
        display = None
    if display is None:
        subprocess.run(['wl-copy', '--type', 'text/html', '--trim-newline'],
                       input=html, check=False, timeout=5)
        return

    providers = [
        Gdk.ContentProvider.new_for_bytes('text/plain;charset=utf-8', GLib.Bytes.new(plain)),
        Gdk.ContentProvider.new_for_bytes('text/html', GLib.Bytes.new(html)),
    ]
    provider = Gdk.ContentProvider.new_union(providers)
    clipboard = display.get_clipboard()
    clipboard.set_content(provider)

    loop = GLib.MainLoop()

    def still_owner():
        current = clipboard.get_content()
        if current is None or current != provider:
            loop.quit()
            return False
        return True

    GLib.timeout_add_seconds(2, still_owner)
    loop.run()


if __name__ == '__main__':
    main()
