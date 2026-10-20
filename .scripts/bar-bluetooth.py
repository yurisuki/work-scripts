#!/usr/bin/env python3
"""Show connected Bluetooth devices with a visible low-battery warning."""
import html
import json

from gi.repository import Gio

ICONS = ['󰁺', '󰁼', '󰁾', '󰂀', '󰁹']
LOW_BATTERY = 20


def render(devices):
    if not devices:
        return {'text': '', 'tooltip': '', 'class': 'disconnected'}
    # Prefer the lowest known battery so an urgent device is always visible.
    devices = sorted(devices, key=lambda d: d[1] if d[1] is not None else 101)
    alias, battery = devices[0]
    text = ' ' + html.escape(alias)
    if battery is not None:
        text += f' · {battery}% {ICONS[min(battery // 20, 4)]}'
    tooltip = '\n'.join(html.escape(name) + (f': {level}%' if level is not None else '')
                        for name, level in devices)
    low = battery is not None and battery <= LOW_BATTERY
    return {'text': text, 'tooltip': tooltip, 'class': 'critical' if low else 'connected'}


def main():
    bus = Gio.bus_get_sync(Gio.BusType.SYSTEM, None)
    reply = bus.call_sync('org.bluez', '/', 'org.freedesktop.DBus.ObjectManager',
                          'GetManagedObjects', None, None, Gio.DBusCallFlags.NONE, 3000, None)
    devices = []
    for interfaces in reply.unpack()[0].values():
        device = interfaces.get('org.bluez.Device1', {})
        if device.get('Connected'):
            battery = interfaces.get('org.bluez.Battery1', {}).get('Percentage')
            devices.append((device.get('Alias', device.get('Address', 'Bluetooth')), battery))
    print(json.dumps(render(devices)))


if __name__ == '__main__':
    try:
        main()
    except Exception:
        print(json.dumps({'text': '', 'class': 'unavailable'}))
