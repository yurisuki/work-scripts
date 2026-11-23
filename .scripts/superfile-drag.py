#!/usr/bin/env python3
"""Turn superfile's selected path(s) into a native Wayland file drag."""
import os
from pathlib import Path
import subprocess
import sys
from urllib.parse import quote

import gi

gi.require_version('Gtk', '4.0')
gi.require_version('Gdk', '4.0')
gi.require_version('GLib', '2.0')
from gi.repository import Gdk, GLib, Gtk  # noqa: E402


def main():
    paths = []
    for line in sys.stdin.read().splitlines():
        line = line.strip()
        if not line:
            continue
        path = Path(line).expanduser()
        if path.exists():
            paths.append(str(path.resolve()))
    if not paths:
        sys.exit('superfile-drag: no existing path on stdin')

    uris = '\r\n'.join('file://' + quote(path, safe='/') for path in paths) + '\r\n'
    text = '\n'.join(paths)
    content = Gdk.ContentProvider.new_union([
        Gdk.ContentProvider.new_for_bytes('text/uri-list', GLib.Bytes.new(uris.encode())),
        Gdk.ContentProvider.new_for_bytes('UTF8_STRING', GLib.Bytes.new(text.encode())),
    ])

    # No application_id: each invocation is independent, so overlapping drags
    # cannot be merged into one existing GTK application instance.
    app = Gtk.Application()

    def activate(application):
        window = Gtk.ApplicationWindow(application=application)
        window.set_default_size(1, 1)
        window.set_decorated(False)
        window.set_focusable(False)
        window.set_can_focus(False)

        def realize(widget):
            seat = Gdk.Display.get_default().get_default_seat()
            drag = Gdk.Drag.begin(
                widget.get_surface(), seat.get_pointer(), content,
                Gdk.DragAction.COPY, 0, 0,
            )
            if os.environ.get('SUPERFILE_DRAG_DEBUG'):
                print('superfile-drag: started', drag, file=sys.stderr, flush=True)
            if not drag:
                application.quit()
                return

            finished = {'done': False}

            def finish(source, success=True):
                if finished['done']:
                    return
                finished['done'] = True
                try:
                    # Required so GDK releases the pointer grab and restores
                    # the normal cursor instead of leaving it invisible.
                    source.drop_done(success)
                except Exception:
                    pass
                theme = os.environ.get('XCURSOR_THEME', 'breeze_cursors')
                size = os.environ.get('HYPRCURSOR_SIZE', '24')
                subprocess.run(
                    ['hyprctl', 'setcursor', theme, size],
                    stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                    timeout=2, check=False,
                )
                application.quit()

            drag.connect('dnd-finished', lambda d: finish(
                d, d.get_selected_action() != Gdk.DragAction.NONE,
            ))
            drag.connect('drop-performed', lambda d: finish(d, True))
            drag.connect('cancel', lambda d, reason: finish(d, False))

        window.connect('realize', realize)
        # Realizing creates the GdkSurface Gdk.Drag needs, but does not map a
        # toplevel window or steal focus.
        window.realize()
        # GTK4 has no drag-end signal. Exit cleanly after a short drag window;
        # no toplevel is ever mapped, so nothing is left visible.
        GLib.timeout_add_seconds(15, application.quit)

    app.connect('activate', activate)
    app.run([])


if __name__ == '__main__':
    main()
