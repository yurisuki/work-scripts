#!/usr/bin/python
"""Remember keyboard brightness and restore it after lid-open or resume."""
from pathlib import Path
import subprocess
import time

import dbus
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib

DEVICE = "tpacpi::kbd_backlight"
BRIGHTNESS = Path("/sys/class/leds") / DEVICE / "brightness"
DBusGMainLoop(set_as_default=True)
bus = dbus.SystemBus()
properties = dbus.Interface(
    bus.get_object("org.freedesktop.UPower", "/org/freedesktop/UPower"),
    "org.freedesktop.DBus.Properties",
)
closed = bool(properties.Get("org.freedesktop.UPower", "LidIsClosed"))
sleeping = False
settling_until = 0.0
remembered = int(BRIGHTNESS.read_text())


def restore():
    if not closed and not sleeping:
        subprocess.run(
            ["/usr/bin/brightnessctl", "-q", "-d", DEVICE, "set", str(remembered)],
            check=True,
        )
    return GLib.SOURCE_REMOVE


def schedule_restore():
    global settling_until
    settling_until = time.monotonic() + 3
    for delay in (200, 1000, 2000):
        GLib.timeout_add(delay, restore)


def lid_changed(interface, changed, invalidated):
    global closed
    if interface == "org.freedesktop.UPower" and "LidIsClosed" in changed:
        was_closed = closed
        closed = bool(changed["LidIsClosed"])
        if was_closed and not closed:
            schedule_restore()


def prepare_for_sleep(active):
    global sleeping
    sleeping = bool(active)
    if not sleeping:
        schedule_restore()


def remember():
    global remembered
    if not closed and not sleeping and time.monotonic() >= settling_until:
        remembered = int(BRIGHTNESS.read_text())
    return GLib.SOURCE_CONTINUE


bus.add_signal_receiver(
    lid_changed,
    signal_name="PropertiesChanged",
    dbus_interface="org.freedesktop.DBus.Properties",
    bus_name="org.freedesktop.UPower",
    path="/org/freedesktop/UPower",
)
bus.add_signal_receiver(
    prepare_for_sleep,
    signal_name="PrepareForSleep",
    dbus_interface="org.freedesktop.login1.Manager",
    bus_name="org.freedesktop.login1",
    path="/org/freedesktop/login1",
)
GLib.timeout_add(250, remember)
GLib.MainLoop().run()
