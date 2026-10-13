#!/usr/bin/env python3
"""Small cached MPRIS snapshot for Hyprlock labels and album artwork."""
import base64
import fcntl
import hashlib
import html
import importlib.util
import json
import os
from pathlib import Path
import sys
import time
from urllib.parse import unquote, urlparse
from urllib.request import urlopen

spec = importlib.util.spec_from_file_location('bar_music', Path(__file__).with_name('bar-music.py'))
music = importlib.util.module_from_spec(spec)
spec.loader.exec_module(music)
runtime = Path(os.environ['XDG_RUNTIME_DIR'])
cache = Path.home() / '.cache/violet-lock-music'
snapshot_path = runtime / 'violet-lock-music.json'


def snapshot():
    with (runtime / 'violet-lock-music.lock').open('w') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        try:
            old = json.loads(snapshot_path.read_text())
        except (OSError, ValueError):
            old = {}
        if time.monotonic() - old.get('updated', 0) < .8:
            return old
        seen = set(old.get('seen', []))
        try:
            selected = json.loads(music.STATE.read_text()).get('player')
            if selected:
                seen.add(selected)
        except (OSError, ValueError):
            pass
        players = []
        for name in music.Playerctl.list_players():
            try:
                players.append(music.Playerctl.Player.new_from_name(name))
            except music.GLib.Error:
                pass
        seen.intersection_update(p.props.player_instance for p in players)
        player = music.select_player(players, seen)
        data = {'updated': time.monotonic(), 'seen': sorted(seen)}
        if player:
            metadata = player.props.metadata.unpack()
            data.update(player=player.props.player_instance,
                        title=player.get_title() or 'Přehrávané médium',
                        artist=player.get_artist() or '',
                        playing=player.props.playback_status == music.Playerctl.PlaybackStatus.PLAYING,
                        art=metadata.get('mpris:artUrl', ''))
        snapshot_path.write_text(json.dumps(data))
        return data


def artwork(uri):
    cache.mkdir(parents=True, exist_ok=True)
    empty = cache / 'empty.png'
    if not empty.exists():
        empty.write_bytes(base64.b64decode(
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR42mNgAAIAAAUA'
            'AXpeqz8AAAAASUVORK5CYII='))
    if not uri:
        return str(empty)
    url = urlparse(uri)
    try:
        if url.scheme == 'file' and url.netloc in ('', 'localhost'):
            with Path(unquote(url.path)).open('rb') as source:
                data = source.read(5_000_001)
        elif url.scheme in ('https', 'http'):
            target = cache / (hashlib.sha256(uri.encode()).hexdigest() + '.png')
            if target.exists():
                return str(target)
            with urlopen(uri, timeout=3) as source:
                data = source.read(5_000_001)
        else:
            return str(empty)
        if len(data) > 5_000_000:
            return str(empty)
        if url.scheme == 'file':
            target = cache / (hashlib.sha256(data).hexdigest() + '.png')
        if not target.exists():
            tmp = target.with_suffix(f'.{os.getpid()}.tmp')
            tmp.write_bytes(data)
            tmp.replace(target)
        return str(target)
    except (OSError, ValueError):
        return str(empty)


def label(data, field):
    if not data.get('player'):
        return ''
    if field in ('title', 'artist'):
        text = ' '.join(data.get(field, '').split())
        limit = 32 if field == 'title' else 44
        return html.escape(text if len(text) <= limit else text[:limit - 1] + '…')
    return {'previous': '󰒮', 'next': '󰒭',
            'play': '󰏤' if data.get('playing') else '󰐊',
            'hint': 'Super+Ctrl  ← předchozí  ·  mezerník pauza  ·  → další'}.get(field, '')


if __name__ == '__main__':
    field = sys.argv[1] if len(sys.argv) > 1 else 'title'
    try:
        data = snapshot()
        print(artwork(data.get('art', '')) if field == 'art' else label(data, field))
    except (OSError, ValueError, music.GLib.Error):
        print(artwork('') if field == 'art' else '')
