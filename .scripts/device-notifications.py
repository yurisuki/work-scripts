#!/usr/bin/env python3
"""Desktop device notifications and volume sounds; run once per session."""
import fcntl
import html
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import threading
import time

ASSETS = Path.home() / '.local/share/device-notifications'
SOUNDS = ASSETS / 'sounds'
PLAYBACK_VOLUME = '0.25'
EVENT_SOUNDS = {
    'device-added': 'device-connected.wav',
    'device-removed': 'device-disconnected.wav',
    'battery-low': 'battery-low.wav',
    'screenshot': 'screenshot.wav',
    'charger-connected': 'charger-connected.wav',
    'session-end': 'session-end.wav',
    'session-start': 'session-start.wav',
}
last_played = {}
play_lock = threading.Lock()
last_output_change = 0.0


def focus_active():
    try:
        return subprocess.run(
            ['systemctl', '--user', 'is-active', '--quiet', 'violet-focus.service'],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=2,
        ).returncode == 0
    except (OSError, subprocess.TimeoutExpired):
        return False


def max_volume_sound():
    """Share a 1.5-second cooldown between key presses and volume monitoring."""
    if focus_active():
        return
    runtime = Path(os.environ.get('XDG_RUNTIME_DIR', f'/tmp/system-sounds-{os.getuid()}'))
    runtime.mkdir(mode=0o700, exist_ok=True)
    with (runtime / 'device-notifications-volume.lock').open('a+') as state:
        fcntl.flock(state, fcntl.LOCK_EX)
        state.seek(0)
        previous = state.read().strip()
        now = time.monotonic()
        if previous and now - float(previous) < 1.5:
            return
        subprocess.Popen(
            ['pw-play', '--volume=' + PLAYBACK_VOLUME, str(SOUNDS / 'max-volume.wav')],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )
        state.seek(0)
        state.truncate()
        state.write(str(now))
        state.flush()


def play(event, wait=False):
    if event == 'audio-volume-change':
        max_volume_sound()
        return
    if focus_active():
        return
    with play_lock:
        now = time.monotonic()
        if now - last_played.get(event, -10) < 1.5:
            return
        last_played[event] = now
        # Fixed, modest gain; never change the user's volume or mute state.
        player = subprocess.Popen(
            ['pw-play', '--volume=' + PLAYBACK_VOLUME,
             str(SOUNDS / EVENT_SOUNDS[event])],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )
        if wait:
            try:
                player.wait(timeout=3)
            except subprocess.TimeoutExpired:
                player.kill()
                player.wait()


def device_event(kind, name, connected):
    if kind == 'Charger':
        if connected:
            play('charger-connected')
    else:
        play('device-added' if connected else 'device-removed')
    icon = {'USB': 'usb', 'Bluetooth': 'bluetooth', 'Charger': 'charger'}[kind]
    subprocess.Popen(
        ['notify-send', '--app-name=Devices', '--expire-time=5000',
         '--hint=boolean:suppress-sound:true',
         '--icon=' + str(ASSETS / 'icons' / (
             icon +
             ('-connected.svg' if connected else '-disconnected.svg'))),
         f'{kind}{"" if kind == "Charger" else " device"} {"connected" if connected else "disconnected"}',
         html.escape(str(name))],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    )


def usb_devices():
    # Physical USB devices only: ignore hubs and their individual interfaces.
    devices = {}
    for device in Path('/sys/bus/usb/devices').glob('*'):
        try:
            if ':' not in device.name and (device / 'bDeviceClass').read_text().strip() != '09':
                product = device / 'product'
                devices[device.name] = product.read_text().strip() if product.exists() else f'USB device ({device.name})'
        except OSError:
            pass
    return devices


def volume():
    try:
        result = subprocess.run(
            ['wpctl', 'get-volume', '@DEFAULT_AUDIO_SINK@'],
            capture_output=True, text=True, timeout=2,
        )
        match = re.search(r'Volume:\s+([\d.]+)', result.stdout)
        return (float(match[1]), '[MUTED]' in result.stdout) if match else None
    except (OSError, subprocess.TimeoutExpired):
        return None


def show_volume(current):
    if current:
        args = [str(Path.home() / '.scripts/hypr-osd.py'), 'volume', str(round(current[0] * 100))]
        if current[1]:
            args.append('muted')
        subprocess.Popen(args, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def audio_label(*values):
    for value in values:
        if isinstance(value, str) and value.strip() and value.strip().lower() not in ('(null)', 'null', 'none'):
            return value.strip()
    return ''


def audio_output():
    try:
        default = subprocess.check_output(['pactl', 'get-default-sink'], text=True, timeout=2).strip()
        sinks = json.loads(subprocess.check_output(['pactl', '-f', 'json', 'list', 'sinks'], text=True, timeout=2))
        for sink in sinks:
            if sink['name'] != default:
                continue
            port = sink.get('active_port') or ''
            props = sink.get('properties') or {}
            description = audio_label(sink.get('description'), props.get('node.nick'),
                                      props.get('device.description'), props.get('device.product.name'), default)
            active = next((p for p in (sink.get('ports') or []) if p.get('name') == port), {})
            port_label = audio_label(active.get('description'))
            if not port_label:
                port_label = {'analog-output-headphones': 'Headphones',
                              'analog-output-lineout': 'Line Out',
                              'analog-output-speaker': 'Speakers'}.get(port, '')
                if port.startswith('hdmi-output'):
                    port_label = 'HDMI / DisplayPort'
            if port_label:
                description += ' · ' + port_label
            icon = 2 if default.startswith('bluez') else (1 if 'headphone' in (port + port_label).lower() else 0)
            return (default, port), description, icon
    except (OSError, ValueError, KeyError, subprocess.SubprocessError):
        pass
    return None


def output_watch():
    global last_output_change
    previous = None
    while True:
        try:
            with subprocess.Popen(['pactl', 'subscribe'], stdout=subprocess.PIPE,
                                  stderr=subprocess.DEVNULL, text=True) as events:
                previous = audio_output()
                for event in events.stdout:
                    if not re.search(r" on (server|sink) #", event):
                        continue
                    current = audio_output()
                    if current is None:
                        continue
                    if previous and current[0] != previous[0]:
                        last_output_change = time.monotonic()
                        subprocess.Popen(
                            [str(Path.home() / '.scripts/hypr-osd.py'), '--output',
                             str(current[2]), current[1]],
                            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                        )
                    previous = current
        except (OSError, subprocess.SubprocessError):
            pass
        time.sleep(2)


def power_state():
    batteries, adapters = {}, []
    for supply in Path('/sys/class/power_supply').glob('*'):
        try:
            kind = (supply / 'type').read_text().strip()
            if kind == 'Battery':
                # Ignore peripheral batteries (mouse, keyboard, etc.).
                scope = supply / 'scope'
                if scope.exists() and scope.read_text().strip() == 'Device':
                    continue
                batteries[supply.name] = (int((supply / 'capacity').read_text()),
                                          (supply / 'status').read_text().strip())
            elif (supply / 'online').exists():
                adapters.append((supply / 'online').read_text().strip() == '1')
        except (OSError, ValueError):
            continue
    online = any(adapters) if adapters else (
        any(status in ('Charging', 'Full') for _, status in batteries.values())
        if batteries else None)
    return online, batteries


def power_events(previous, current):
    old_online, old_batteries = previous
    online, batteries = current
    if old_online is not None and online is not None and old_online != online:
        device_event('Charger', 'External power' if online else 'Running on battery', online)
    for name, (level, status) in batteries.items():
        old = old_batteries.get(name)
        if status == 'Discharging' and old and any(
                level <= threshold and (old[0] > threshold or old[1] != 'Discharging')
                for threshold in (25, 10)):
            play('battery-low')



def bluetooth_battery_events(previous, current):
    """Alert once per threshold crossing for each connected Bluetooth device."""
    for address, (name, level) in current.items():
        old = previous.get(address)
        if any(level <= threshold and (old is None or old[1] > threshold)
               for threshold in (20, 10)):
            play('battery-low')
            subprocess.Popen(
                ['notify-send', '--app-name=Devices', '--expire-time=10000',
                 '--urgency=' + ('critical' if level <= 10 else 'normal'),
                 '--hint=boolean:suppress-sound:true',
                 '--icon=' + str(ASSETS / 'icons' / 'bluetooth-connected.svg'),
                 'Bluetooth battery low', f'{html.escape(name)} · {level}% remaining'],
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            )


def bluetooth_watch():
    try:
        import dbus
        from dbus.mainloop.glib import DBusGMainLoop
        from gi.repository import GLib
        DBusGMainLoop(set_as_default=True)
        bus = dbus.SystemBus()

        names = {}
        try:
            manager = dbus.Interface(bus.get_object('org.bluez', '/'), 'org.freedesktop.DBus.ObjectManager')
            for path, interfaces in manager.GetManagedObjects().items():
                info = interfaces.get('org.bluez.Device1', {})
                if info:
                    names[str(path)] = str(info.get('Alias', info.get('Name', 'Bluetooth device')))
        except dbus.DBusException:
            pass

        previous_batteries = {}

        def check_batteries():
            nonlocal previous_batteries
            try:
                manager = dbus.Interface(bus.get_object('org.bluez', '/'),
                                         'org.freedesktop.DBus.ObjectManager')
                current = {}
                for path, interfaces in manager.GetManagedObjects().items():
                    device = interfaces.get('org.bluez.Device1', {})
                    battery = interfaces.get('org.bluez.Battery1', {})
                    if device.get('Connected') and 'Percentage' in battery:
                        current[str(path)] = (
                            str(device.get('Alias', device.get('Name', 'Bluetooth device'))),
                            int(battery['Percentage']))
                bluetooth_battery_events(previous_batteries, current)
                previous_batteries = current
            except dbus.DBusException:
                pass
            return True

        def changed(interface, properties, invalidated, path=None):
            if interface == 'org.bluez.Battery1':
                check_batteries()
                return
            if interface != 'org.bluez.Device1':
                return
            if 'Alias' in properties or 'Name' in properties:
                names[str(path)] = str(properties.get('Alias', properties.get('Name')))
            if interface == 'org.bluez.Device1' and 'Connected' in properties:
                if str(path) not in names:
                    try:
                        info = dbus.Interface(bus.get_object('org.bluez', path), 'org.freedesktop.DBus.Properties')
                        names[str(path)] = str(info.Get('org.bluez.Device1', 'Alias'))
                    except dbus.DBusException:
                        pass
                device_event('Bluetooth', names.get(str(path), 'Bluetooth device'), bool(properties['Connected']))
                check_batteries()

        bus.add_signal_receiver(
            changed, signal_name='PropertiesChanged',
            dbus_interface='org.freedesktop.DBus.Properties',
            bus_name='org.bluez',
            path_keyword='path',
        )
        check_batteries()
        # Catch batteries first exposed after connection, and BlueZ restarts.
        GLib.timeout_add_seconds(30, check_batteries)
        GLib.MainLoop().run()
    except Exception as error:
        print(f'Bluetooth sound monitoring unavailable: {error}', file=sys.stderr)


def main():
    if len(sys.argv) == 2 and sys.argv[1] in ('--volume-up', '--volume-down', '--volume-mute'):
        action = sys.argv[1]
        if action != '--volume-mute':
            unmute = subprocess.run(['wpctl', 'set-mute', '@DEFAULT_AUDIO_SINK@', '0'])
            if unmute.returncode != 0:
                return
        command = (['wpctl', 'set-mute', '@DEFAULT_AUDIO_SINK@', 'toggle'] if action == '--volume-mute'
                   else ['wpctl', 'set-volume', '-l', '1', '@DEFAULT_AUDIO_SINK@',
                         '5%+' if action == '--volume-up' else '5%-'])
        result = subprocess.run(command)
        if result.returncode == 0:
            current = volume()
            show_volume(current)
            if action == '--volume-up' and current and current[0] >= 0.995 and not current[1]:
                max_volume_sound()
        return
    if len(sys.argv) == 3 and sys.argv[1] in ('--preview', '--play-and-wait'):
        if sys.argv[2] not in (*EVENT_SOUNDS, 'audio-volume-change'):
            raise SystemExit('Unknown sound')
        play(sys.argv[2], wait=sys.argv[1] == '--play-and-wait')
        return
    runtime = Path(os.environ.get('XDG_RUNTIME_DIR', f'/tmp/system-sounds-{os.getuid()}'))
    runtime.mkdir(mode=0o700, exist_ok=True)
    with (runtime / 'system-sounds.lock').open('w') as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return
        threading.Thread(target=bluetooth_watch, daemon=True).start()
        threading.Thread(target=output_watch, daemon=True).start()
        previous_usb, previous_volume = usb_devices(), volume()
        previous_power = power_state()
        while True:
            time.sleep(0.5)
            current_usb, current_volume = usb_devices(), volume()
            current_power = power_state()
            power_events(previous_power, current_power)
            previous_power = current_power
            for device in current_usb.keys() - previous_usb.keys():
                device_event('USB', current_usb[device], True)
            for device in previous_usb.keys() - current_usb.keys():
                device_event('USB', previous_usb[device], False)
            if current_volume and previous_volume:
                if current_volume != previous_volume and time.monotonic() - last_output_change > 2.2:
                    show_volume(current_volume)
                level, muted = current_volume
                if level >= 0.995 and previous_volume[0] < 0.995 and not muted:
                    play('audio-volume-change')
            previous_usb, previous_volume = current_usb, current_volume


if __name__ == '__main__':
    main()
