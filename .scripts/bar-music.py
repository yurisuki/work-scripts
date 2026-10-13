#!/usr/bin/env python3
"""Event-driven Waybar media controls using MPRIS."""
import html
import json
import os
from pathlib import Path
import sys
from types import SimpleNamespace

import gi
gi.require_version('Playerctl', '2.0')
from gi.repository import GLib, Playerctl

STATE = Path(os.environ['XDG_RUNTIME_DIR']) / 'violet-music-player.json'


def metadata_rank(player):
    try:
        title = (player.get_title() or '').strip()
        artist = (player.get_artist() or '').strip()
    except GLib.Error:
        return (True, True, True, player.props.player_instance)
    normalized = ' '.join(title.replace('\u200e', '').replace('\u200f', '').split()).casefold()
    generic = not title or (not artist and normalized in (
        'apple music - web player', 'apple music – web player',
        'spotify - web player', 'spotify – web player',
    ))
    return (generic, not bool(artist), player.props.player_name != 'plasma-browser-integration',
            player.props.player_instance)


class BrowserSession:
    """Use rich extension metadata with the browser's actual playback state."""
    def __init__(self, browser, metadata):
        self.browser = browser
        self.metadata_player = metadata
        self.props = SimpleNamespace(
            player_instance=browser.props.player_instance,
            player_name=metadata.props.player_name,
            playback_status=browser.props.playback_status,
            metadata=metadata.props.metadata,
            can_go_previous=browser.props.can_go_previous,
            can_go_next=browser.props.can_go_next,
        )

    def get_title(self):
        return self.metadata_player.get_title()

    def get_artist(self):
        return self.metadata_player.get_artist()

    def play_pause(self):
        self.browser.play_pause()

    def previous(self):
        self.browser.previous()

    def next(self):
        self.browser.next()


def combine_browser_sessions(players):
    players = list(players)
    for integration in list(players):
        if integration.props.player_name != 'plasma-browser-integration' or metadata_rank(integration)[0]:
            continue
        try:
            pid = integration.props.metadata.unpack().get('kde:pid')
        except (GLib.Error, AttributeError):
            continue
        if not pid:
            continue
        for browser in list(players):
            if (browser.props.player_name in ('brave', 'chromium', 'chrome', 'firefox')
                    and browser.props.player_instance == f'{browser.props.player_name}.instance{pid}'
                    and metadata_rank(browser)[0]):
                players.remove(browser)
                players.remove(integration)
                players.append(BrowserSession(browser, integration))
                break
    return players


def select_player(players, seen):
    players = combine_browser_sessions(players)
    playing = [p for p in players if p.props.playback_status == Playerctl.PlaybackStatus.PLAYING]
    seen.update(p.props.player_instance for p in playing)
    paused = [p for p in players
              if p.props.playback_status == Playerctl.PlaybackStatus.PAUSED
              and p.props.player_instance in seen]
    candidates = playing or paused
    return min(candidates, key=metadata_rank) if candidates else None


def render(player, role):
    if player is None:
        return {'text': '', 'tooltip': '', 'class': 'hidden'}
    playing = player.props.playback_status == Playerctl.PlaybackStatus.PLAYING
    title = player.get_title() or 'Přehrávané médium'
    artist = player.get_artist() or ''
    track = f'{artist} · {title}' if artist else title
    if role == 'previous':
        text, hint = '󰒮', 'Předchozí skladba'
    elif role == 'next':
        text, hint = '󰒭', 'Další skladba'
    else:
        text = ('󰏤' if playing else '󰐊') + '  ' + ' '.join(track.split())
        hint = 'Kliknutím pozastavit' if playing else 'Kliknutím pokračovat'
    return {'text': html.escape(text),
            'tooltip': html.escape(f'{track}\n{player.props.player_name}\n{hint}'),
            'class': 'playing' if playing else 'paused'}


def watch(role):
    manager = Playerctl.PlayerManager()
    seen = set()
    last = None

    def update(*_):
        nonlocal last
        player = select_player(manager.props.players, seen)
        if role == 'title':
            data = {'player': player.props.player_instance if player else None}
            temp = STATE.with_name(f'{STATE.name}.{os.getpid()}.tmp')
            temp.write_text(json.dumps(data))
            temp.replace(STATE)
        try:
            data = render(player, role)
        except GLib.Error:
            data = render(None, role)
        line = json.dumps(data, ensure_ascii=False)
        if line != last:
            print(line, flush=True)
            last = line

    def add(_manager, name):
        try:
            player = Playerctl.Player.new_from_name(name)
            player.connect('playback-status', update)
            player.connect('metadata', update)
            manager.manage_player(player)
            update()
        except GLib.Error:
            pass

    def remove(_manager, player):
        seen.discard(player.props.player_instance)
        update()

    manager.connect('name-appeared', add)
    manager.connect('player-vanished', remove)
    for name in manager.props.player_names:
        add(manager, name)
    update()
    GLib.MainLoop().run()


def control(action):
    try:
        try:
            selected = json.loads(STATE.read_text()).get('player')
        except (OSError, ValueError):
            selected = None
        players = []
        for name in Playerctl.list_players():
            try:
                players.append(Playerctl.Player.new_from_name(name))
            except GLib.Error:
                pass
        player = select_player(players, {selected} if selected else set())
        if player is None:
            # Explicit play/skip also works when Waybar has not observed playback.
            player = select_player(players, {p.props.player_instance for p in players})
        if player is None:
            return
        if action == 'play-pause':
            player.play_pause()
        elif action == 'previous' and player.props.can_go_previous:
            player.previous()
        elif action == 'next' and player.props.can_go_next:
            player.next()
    except (OSError, ValueError, GLib.Error):
        return


if __name__ == '__main__':
    try:
        if len(sys.argv) == 3 and sys.argv[1] == 'watch' and sys.argv[2] in ('title', 'previous', 'next'):
            watch(sys.argv[2])
        elif len(sys.argv) == 2 and sys.argv[1] in ('play-pause', 'previous', 'next'):
            control(sys.argv[1])
        else:
            raise SystemExit('Usage: bar-music.py watch title|previous|next OR play-pause|previous|next')
    except BrokenPipeError:
        pass
