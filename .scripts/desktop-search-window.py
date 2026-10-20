#!/usr/bin/env python3
"""Search apps immediately; reveal local file/browser results only for a query."""
import fcntl
import ast
import json
import math
import operator
import os
from pathlib import Path
import runpy
import subprocess
import threading
import time

import gi
gi.require_version('Gtk', '3.0')
gi.require_version('GtkLayerShell', '0.1')
gi.require_version('GdkPixbuf', '2.0')
from gi.repository import Gtk, Gdk, GdkPixbuf, Gio, GLib, Pango, GtkLayerShell


def matches(text, query):
    return all(word in text.casefold() for word in query.casefold().split())


def calculate(query):
    explicit = query.startswith('=')
    expression = query.lstrip('=').strip().replace('^', '**').replace(',', '.')
    if not expression or len(expression) > 160:
        return None
    try:
        tree = ast.parse(expression, mode='eval')
        nodes = list(ast.walk(tree))
        if len(nodes) > 64 or not explicit and not any(isinstance(n, ast.BinOp) for n in nodes):
            return None
        operations = {ast.Add: operator.add, ast.Sub: operator.sub, ast.Mult: operator.mul,
                      ast.Div: operator.truediv, ast.FloorDiv: operator.floordiv,
                      ast.Mod: operator.mod, ast.Pow: operator.pow}
        def evaluate(node):
            if isinstance(node, ast.Constant) and type(node.value) in (int, float):
                value = float(node.value)
            elif isinstance(node, ast.UnaryOp) and isinstance(node.op, (ast.UAdd, ast.USub)):
                value = evaluate(node.operand) * (-1 if isinstance(node.op, ast.USub) else 1)
            elif isinstance(node, ast.BinOp) and type(node.op) in operations:
                left, right = evaluate(node.left), evaluate(node.right)
                if isinstance(node.op, ast.Pow) and abs(right) > 12:
                    raise ValueError('Exponent too large')
                value = operations[type(node.op)](left, right)
            else:
                raise ValueError('Unsupported expression')
            if not isinstance(value, (int, float)) or not math.isfinite(value) or abs(value) > 1e100:
                raise ValueError('Out of range')
            return value
        return format(evaluate(tree.body), '.12g')
    except (SyntaxError, ValueError, TypeError, ArithmeticError):
        return None


def pinned_apps():
    try:
        data = json.loads(recent_path().with_name('pinned-apps.json').read_text())
        return [name for name in data if isinstance(name, str)] if isinstance(data, list) else []
    except (OSError, ValueError):
        return []


def toggle_pin(app_id):
    if not app_id:
        return pinned_apps()
    path = recent_path().with_name('pinned-apps.json')
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    with path.with_suffix('.lock').open('w') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        pins = pinned_apps()
        pins.remove(app_id) if app_id in pins else pins.append(app_id)
        temporary = path.with_suffix('.tmp')
        with os.fdopen(os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600), 'w') as output:
            json.dump(pins, output)
        temporary.replace(path)
        return pins


def open_windows():
    try:
        windows = json.loads(subprocess.check_output(['hyprctl', '-j', 'clients'], text=True, timeout=2))
        return [{'kind': 'WINDOW', 'name': (w.get('title') or w.get('class', 'Window')) + ' · ' + w.get('class', ''),
                 'search': w.get('title', '') + ' ' + w.get('class', ''),
                 'target': {'window': w['address']}} for w in windows if w.get('mapped')]
    except (OSError, ValueError, KeyError, subprocess.SubprocessError):
        return []


def recent_path():
    return Path(os.environ.get('XDG_STATE_HOME', Path.home() / '.local/state')) / 'desktop-search/recent-apps.json'


def recent_apps():
    try:
        data = json.loads(recent_path().read_text())
        return {key: float(value) for key, value in data.items() if isinstance(key, str)}
    except (OSError, ValueError, TypeError, AttributeError):
        return {}


def remember_app(app_id):
    if not app_id:
        return
    try:
        path = recent_path()
        path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
        with path.with_suffix('.lock').open('w') as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            history = recent_apps()
            history[app_id] = time.time()
            history = dict(sorted(history.items(), key=lambda pair: pair[1], reverse=True)[:100])
            temporary = path.with_suffix('.tmp')
            fd = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
            with os.fdopen(fd, 'w') as output:
                json.dump(history, output)
            temporary.replace(path)
    except OSError:
        pass


def main():
    lock = (Path(os.environ['XDG_RUNTIME_DIR']) / 'violet-search.lock').open('w')
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        return
    source = runpy.run_path(str(Path(__file__).with_name('desktop-search.py')), run_name='search_source')
    try:
        engine_name = source['search_provider']()[0]
    except ValueError:
        engine_name = 'default search engine'
    history = recent_apps()
    pins = pinned_apps()
    apps = sorted((app for app in Gio.AppInfo.get_all() if app.should_show()),
                  key=lambda app: (app.get_id() not in pins, -history.get(app.get_id(), 0), app.get_display_name().casefold()))
    entries = [{'kind': 'APP', 'name': app.get_display_name(),
                'search': ' '.join([app.get_display_name(), app.get_description() or '', app.get_executable() or '']),
                'app': app} for app in apps]
    ready = False
    favicon_images = {}
    closed = False
    window = Gtk.Window()
    window.set_name('desktop-search')
    window.set_app_paintable(True)
    window.set_visual(window.get_screen().get_rgba_visual())
    GtkLayerShell.init_for_window(window)
    GtkLayerShell.set_namespace(window, 'violet-search')
    GtkLayerShell.set_layer(window, GtkLayerShell.Layer.OVERLAY)
    GtkLayerShell.set_keyboard_mode(window, GtkLayerShell.KeyboardMode.EXCLUSIVE)
    window.set_default_size(720, 490)
    mainbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
    mainbox.set_name('search-content')
    entry = Gtk.SearchEntry()
    entry.set_placeholder_text('Search apps, windows, files, Brave, or calculate…')
    status = Gtk.Label(xalign=0)
    status.set_name('search-status')
    scroll = Gtk.ScrolledWindow()
    scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
    scroll.set_size_request(670, 370)
    results = Gtk.ListBox()
    results.set_selection_mode(Gtk.SelectionMode.SINGLE)
    results.set_activate_on_single_click(True)
    scroll.add(results)
    mainbox.pack_start(entry, False, False, 0)
    mainbox.pack_start(status, False, False, 0)
    mainbox.pack_start(scroll, True, True, 0)
    window.add(mainbox)
    css = Gtk.CssProvider()
    css.load_from_data(b'''
      #desktop-search { background: transparent; }
      #search-content { background: #171020; border: 1px solid #493455; border-radius: 14px; padding: 18px; }
      #desktop-search entry { background: #241a30; color: #ede3f5; border: none; border-radius: 8px; padding: 12px; font: 14px Inter; }
      #desktop-search list, #desktop-search row { background: transparent; color: #ede3f5; border-radius: 8px; }
      #desktop-search row { padding: 10px; margin-bottom: 3px; }
      #desktop-search row:selected { background: #392247; }
      #desktop-search label { font: 13px Inter; }
      #desktop-search #search-kind { color: #cf9bff; font: 11px "JetBrainsMono Nerd Font"; }
      #desktop-search #search-status { color: #b4a3c4; font: 11px Inter; }
    ''')
    Gtk.StyleContext.add_provider_for_screen(Gdk.Screen.get_default(), css, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)

    def activate(row):
        if row is None:
            return
        item = row.item
        try:
            if 'app' in item:
                item['app'].launch([], None)
                remember_app(item['app'].get_id())
            elif 'copy' in item:
                subprocess.run(['wl-copy', '--', item['copy']], check=True, timeout=3)
            elif 'window' in item.get('target', {}):
                address = item['target']['window']
                if not address.startswith('0x') or any(c not in '0123456789abcdefABCDEF' for c in address[2:]):
                    return
                subprocess.run(['hyprctl', 'dispatch', 'hl.dsp.focus({ window = ' + json.dumps('address:' + address) + ' })'],
                               check=True, timeout=3)
            else:
                source['activate'](item['target'])
        except (GLib.Error, OSError, ValueError, subprocess.SubprocessError):
            status.set_text('Could not open this result.')
            return
        window.destroy()

    def refresh():
        if closed:
            return False
        query = entry.get_text().strip()
        pool = [item for item in entries if (query or item['kind'] == 'APP') and matches(item['search'], query)]
        if query:
            pool.sort(key=lambda item: (not item['name'].casefold().startswith(query.casefold()),
                                       item['app'].get_id() not in pins if 'app' in item else True,
                                       {'WINDOW': 0, 'APP': 1}.get(item['kind'], 2),
                                       -history.get(item['app'].get_id(), 0) if 'app' in item else 0, len(item['name'])))
            answer = calculate(query)
            if answer is not None:
                pool.insert(0, {'kind': 'CALC', 'name': answer + ' · Enter to copy', 'copy': answer})
            if query.startswith('>'):
                command = query[1:].strip()
                pool = ([{'kind': 'CMD', 'name': 'Run in background · ' + command,
                          'target': {'command': command}}] if command else [])
            else:
                pool = pool[:48]
                pool.append({'kind': 'WEB', 'name': 'Search ' + engine_name + ' for “' + query + '”',
                             'target': {'search': query}})
                pool.append({'kind': 'CMD', 'name': 'Run in background · ' + query,
                             'target': {'command': query}})
        else:
            pool.sort(key=lambda item: (item['app'].get_id() not in pins, -history.get(item['app'].get_id(), 0), item['name'].casefold()))
        for child in results.get_children():
            results.remove(child)
        for item in pool[:50]:
            row = Gtk.ListBoxRow()
            row.item = item
            line = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
            category = Gtk.Label(label=item['kind'] + ' |', xalign=1)
            category.set_name('search-kind')
            category.set_size_request(100, -1)
            if item.get('favicon'):
                url = item['target']['url']
                if url not in favicon_images:
                    try:
                        loader = GdkPixbuf.PixbufLoader()
                        loader.set_size(24, 24)
                        loader.write(item['favicon'])
                        loader.close()
                        favicon_images[url] = loader.get_pixbuf()
                    except GLib.Error:
                        favicon_images[url] = None
                if favicon_images[url]:
                    image = Gtk.Image.new_from_pixbuf(favicon_images[url])
                else:
                    image = Gtk.Image.new_from_icon_name('user-bookmarks', Gtk.IconSize.LARGE_TOOLBAR)
            elif 'app' in item and item['app'].get_icon():
                image = Gtk.Image.new_from_gicon(item['app'].get_icon(), Gtk.IconSize.LARGE_TOOLBAR)
            else:
                icon_name = {'APP': 'application-x-executable', 'FILES': 'text-x-generic',
                             'BOOKMARKS': 'user-bookmarks', 'HISTORY': 'document-open-recent',
                             'WINDOW': 'preferences-system-windows', 'CALC': 'accessories-calculator',
                             'WEB': 'web-browser', 'CMD': 'utilities-terminal'}[item['kind']]
                image = Gtk.Image.new_from_icon_name(icon_name, Gtk.IconSize.LARGE_TOOLBAR)
            image.set_pixel_size(24)
            image.set_size_request(24, 24)
            is_pinned = 'app' in item and item['app'].get_id() in pins
            label = Gtk.Label(label=('★ ' if is_pinned else '') + item['name'], xalign=0)
            label.set_ellipsize(Pango.EllipsizeMode.END)
            label.set_max_width_chars(65)
            line.pack_start(category, False, False, 0)
            line.pack_start(image, False, False, 0)
            line.pack_start(label, True, True, 0)
            row.add(line)
            results.add(row)
        results.show_all()
        results.select_row(results.get_row_at_index(0))
        if not query:
            status.set_text('Ctrl+P to pin/unpin · > command to run in background')
        else:
            status.set_text(f'{len(pool)} results' + (' · loading local sources…' if not ready else ''))
        return False

    def load():
        extra = open_windows()
        def collect(name, target, icon, meta=''):
            kind = 'FILES' if 'path' in target else ('BOOKMARKS' if icon == 'user-bookmarks' else 'HISTORY')
            extra.append({'kind': kind, 'name': source['clean'](name), 'search': name + ' ' + meta, 'target': target})
        source['file_entries'].__globals__['row'] = collect
        source['file_entries']()
        source['brave_entries']()
        icons = source['bookmark_favicons']({item['target']['url'] for item in extra if item['kind'] == 'BOOKMARKS'})
        for item in extra:
            if item['kind'] == 'BOOKMARKS':
                item['favicon'] = icons.get(item['target']['url'])
        def publish():
            nonlocal ready
            entries.extend(extra)
            ready = True
            refresh()
            return False
        GLib.idle_add(publish)

    def keys(widget, event):
        nonlocal pins
        if event.state & Gdk.ModifierType.CONTROL_MASK and event.keyval in (Gdk.KEY_p, Gdk.KEY_P):
            selected = results.get_selected_row()
            if selected is not None and 'app' in selected.item:
                try:
                    pins = toggle_pin(selected.item['app'].get_id())
                    refresh()
                except OSError:
                    status.set_text('Could not save pinned apps.')
            return True
        if event.keyval == Gdk.KEY_Escape:
            window.destroy()
            return True
        if event.keyval in (Gdk.KEY_Down, Gdk.KEY_Up):
            selected = results.get_selected_row()
            index = selected.get_index() if selected else -1
            next_row = results.get_row_at_index(max(0, index + (1 if event.keyval == Gdk.KEY_Down else -1)))
            if next_row:
                results.select_row(next_row)
                adjustment = scroll.get_vadjustment()
                area = next_row.get_allocation()
                if area.y < adjustment.get_value():
                    adjustment.set_value(area.y)
                elif area.y + area.height > adjustment.get_value() + adjustment.get_page_size():
                    adjustment.set_value(area.y + area.height - adjustment.get_page_size())
            return True
        return False

    def destroy(widget):
        nonlocal closed
        closed = True
        Gtk.main_quit()

    entry.connect('search-changed', lambda widget: refresh())
    entry.connect('key-press-event', keys)
    entry.connect('activate', lambda widget: activate(results.get_selected_row()))
    results.connect('row-activated', lambda widget, row: activate(row))
    window.connect('key-press-event', keys)
    window.connect('destroy', destroy)
    refresh()
    window.show_all()
    entry.grab_focus()
    threading.Thread(target=load, daemon=True).start()
    Gtk.main()


if __name__ == '__main__':
    main()
