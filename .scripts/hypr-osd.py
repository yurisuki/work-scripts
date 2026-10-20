#!/usr/bin/env python3
"""Passive volume/brightness overlay, independent of notification history."""
import fcntl
import json
import os
from pathlib import Path
import socket
import subprocess
import sys
import time

RUNTIME = Path(os.environ['XDG_RUNTIME_DIR'])
SOCKET = RUNTIME / 'violet-osd.sock'


def level_icon(kind, value, muted=False):
    if kind == 'microphone':
        return '󰍬' if value else '󰍭'
    if kind == 'capslock':
        return '󰘲'
    if kind == 'focus':
        return '󰂛' if value else '󰂚'
    if kind == 'keyboard':
        return '󰌐' if value == 0 else '󰌌'
    if kind == 'volume':
        if muted or value == 0:
            return '󰝟'
        return '󰕿' if value <= 33 else ('󰖀' if value <= 66 else '󰕾')
    return '󰃞' if value <= 33 else ('󰃟' if value <= 66 else '󰃠')


def keyboard_level(root=Path('/sys/class/leds')):
    for device in sorted(root.glob('*kbd_backlight*')):
        try:
            maximum = int((device / 'max_brightness').read_text())
            current = int((device / 'brightness').read_text())
            if maximum > 0:
                return max(0, min(100, round(current * 100 / maximum)))
        except (OSError, ValueError):
            continue
    return None


def caps_lock(root=Path('/sys/class/leds')):
    states = []
    for device in root.glob('*::capslock'):
        try:
            states.append(int((device / 'brightness').read_text()) > 0)
        except (OSError, ValueError):
            continue
    return any(states) if states else None


def toggle_microphone():
    result = subprocess.run(['wpctl', 'set-mute', '@DEFAULT_AUDIO_SOURCE@', 'toggle'])
    if result.returncode == 0:
        status = subprocess.run(['wpctl', 'get-volume', '@DEFAULT_AUDIO_SOURCE@'],
                                capture_output=True, text=True, timeout=2)
        if status.returncode == 0:
            show('microphone', 0 if '[MUTED]' in status.stdout else 100)


def show(kind, value, muted=False):
    payload = json.dumps({'kind': kind, 'value': max(0, min(100, int(value))),
                          'muted': bool(muted)}).encode()
    with socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM) as client:
        for attempt in range(20):
            try:
                client.sendto(payload, str(SOCKET))
                return
            except (FileNotFoundError, ConnectionRefusedError):
                if attempt == 0:
                    subprocess.Popen([sys.executable, __file__, '--daemon'],
                                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                                     start_new_session=True)
                time.sleep(0.05)


def daemon():
    import gi
    gi.require_version('Gtk', '3.0')
    gi.require_version('GtkLayerShell', '0.1')
    from gi.repository import Gtk, Gdk, GLib, GtkLayerShell
    lock = (RUNTIME / 'violet-osd.lock').open('w')
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        return
    SOCKET.unlink(missing_ok=True)
    server = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM)
    server.bind(str(SOCKET))
    os.chmod(SOCKET, 0o600)
    server.setblocking(False)
    window = Gtk.Window()
    window.set_name('violet-osd')
    window.set_app_paintable(True)
    window.set_visual(window.get_screen().get_rgba_visual())
    GtkLayerShell.init_for_window(window)
    GtkLayerShell.set_namespace(window, 'violet-osd')
    GtkLayerShell.set_layer(window, GtkLayerShell.Layer.OVERLAY)
    GtkLayerShell.set_keyboard_mode(window, GtkLayerShell.KeyboardMode.NONE)
    GtkLayerShell.set_anchor(window, GtkLayerShell.Edge.BOTTOM, True)
    GtkLayerShell.set_margin(window, GtkLayerShell.Edge.BOTTOM, 90)
    GtkLayerShell.set_exclusive_zone(window, -1)
    box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=16)
    box.set_name('osd-content')
    icon = Gtk.Label()
    icon.set_name('osd-icon')
    caps_icon = Gtk.Image()
    caps_icon.set_pixel_size(32)
    caps_icon.set_valign(Gtk.Align.CENTER)
    meter = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
    meter.set_valign(Gtk.Align.CENTER)
    icon.set_valign(Gtk.Align.CENTER)
    header = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
    title = Gtk.Label(xalign=0)
    number = Gtk.Label(xalign=1)
    header.pack_start(title, True, True, 0)
    header.pack_end(number, False, False, 0)
    bar = Gtk.ProgressBar()
    bar.set_size_request(225, 6)
    meter.pack_start(header, False, False, 0)
    meter.pack_start(bar, False, False, 0)
    box.pack_start(icon, False, False, 0)
    box.pack_start(caps_icon, False, False, 0)
    box.pack_start(meter, True, True, 0)
    window.add(box)
    css = Gtk.CssProvider()
    css.load_from_data(b'''
        #violet-osd { background: transparent; }
        #osd-content { background: rgba(36, 24, 46, 0.96); border: 1px solid #705184;
                       border-radius: 18px; padding: 18px 22px; }
        #violet-osd label { color: #eee3f7; font: 12px Inter; }
        #violet-osd #osd-icon { color: #d8b8f4; font: 28px "Symbols Nerd Font"; min-width: 32px; }
        #violet-osd trough { background: #513b60; border: none; border-radius: 8px; min-height: 6px; }
        #violet-osd progress { background: #cf9bff; border: none; border-radius: 8px; min-height: 6px; }
    ''')
    Gtk.StyleContext.add_provider_for_screen(Gdk.Screen.get_default(), css,
                                             Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)
    hide_timer = None

    def receive(source, condition):
        nonlocal hide_timer
        latest = None
        while True:
            try:
                latest = json.loads(server.recv(4096))
            except BlockingIOError:
                break
            except (ValueError, UnicodeError):
                continue
        if latest is None:
            return True
        try:
            kind, value, muted = latest['kind'], int(latest['value']), latest.get('muted', False)
            if kind not in ('volume', 'brightness', 'keyboard', 'focus', 'capslock', 'microphone'):
                return True
        except (KeyError, TypeError, ValueError):
            return True
        title.set_text(('Focus mode · On' if value else 'Focus mode · Off') if kind == 'focus' else 'Keyboard backlight' if kind == 'keyboard' else (
            'Brightness' if kind == 'brightness' else ('Volume muted' if muted else 'Volume')))
        if kind == 'capslock':
            title.set_text('Caps Lock · On' if value else 'Caps Lock · Off')
        elif kind == 'microphone':
            title.set_text('Microphone · Live' if value else 'Microphone · Muted')
        number.set_text(('On' if value else 'Off') if kind == 'focus' else
                        ('Off' if value == 0 else ('Low' if value <= 50 else 'High'))
                        if kind == 'keyboard' else f'{value}%')
        icon.set_text(level_icon(kind, value, muted))
        icon.set_opacity((0.4 if value == 0 else (0.7 if value <= 50 else 1.0))
                         if kind == 'keyboard' else 1.0)
        bar.set_fraction(0 if muted else max(0, min(100, value)) / 100)
        if hide_timer:
            GLib.source_remove(hide_timer)
        window.show_all()
        if kind == 'capslock':
            icon.hide()
            caps_icon.set_from_file(str(Path.home() / '.local/share/device-notifications/icons' /
                                        ('capslock-on.svg' if value else 'capslock-off.svg')))
        else:
            caps_icon.hide()
        if kind in ('focus', 'capslock', 'microphone'):
            bar.hide()
            number.hide()
        window.resize(1, 1)
        # Keep the overlay passive: clicks go through to the underlying window.
        window.get_window().input_shape_combine_region(__import__('cairo').Region(), 0, 0)
        def hide():
            nonlocal hide_timer
            window.hide()
            hide_timer = None
            return False
        hide_timer = GLib.timeout_add(1800 if kind in ('focus', 'capslock', 'microphone') else 1200, hide)
        return True

    GLib.io_add_watch(server.fileno(), GLib.IO_IN, receive)
    previous_keyboard = keyboard_level()
    previous_caps = caps_lock()

    def watch_keyboard():
        nonlocal previous_keyboard, previous_caps
        current = keyboard_level()
        if current is not None and previous_keyboard is not None and current != previous_keyboard:
            show('keyboard', current)
        previous_keyboard = current
        current_caps = caps_lock()
        if current_caps is not None and previous_caps is not None and current_caps != previous_caps:
            show('capslock', 100 if current_caps else 0)
        previous_caps = current_caps
        return True

    GLib.timeout_add(100, watch_keyboard)
    try:
        Gtk.main()
    finally:
        server.close()
        SOCKET.unlink(missing_ok=True)


if __name__ == '__main__':
    if sys.argv[1:] == ['--mic-toggle']:
        toggle_microphone()
    elif sys.argv[1:] == ['--daemon']:
        daemon()
    else:
        show(sys.argv[1], sys.argv[2], len(sys.argv) > 3 and sys.argv[3] == 'muted')
