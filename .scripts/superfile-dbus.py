#!/usr/bin/python
"""Handle desktop file-manager requests with superfile in Hyprland."""
import os
from pathlib import Path
import subprocess
from urllib.parse import unquote, urlsplit

import dbus
import dbus.service
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib

INTERFACE = "org.freedesktop.FileManager1"


def folder_paths(uris, items=False):
    folders = []
    for uri in uris:
        parsed = urlsplit(str(uri))
        if parsed.scheme != "file" or parsed.netloc not in ("", "localhost"):
            raise dbus.exceptions.DBusException(
                "Only local file URIs are supported",
                name="org.freedesktop.DBus.Error.InvalidArgs",
            )
        path = Path(unquote(parsed.path))
        if not path.is_absolute():
            raise ValueError("Expected an absolute path")
        folder = path.parent if items else path
        if not folder.is_dir():
            raise ValueError(f"Not a directory: {folder}")
        if str(folder) not in folders:
            folders.append(str(folder))
    return folders


class FileManager(dbus.service.Object):
    def open_folders(self, uris, items=False):
        folders = folder_paths(uris, items)
        if folders:
            subprocess.Popen(
                ["/usr/bin/kitty", "--title", "superfile", "-e", "/usr/bin/spf", *folders],
                start_new_session=True,
            )

    @dbus.service.method(INTERFACE, in_signature="ass", out_signature="")
    def ShowFolders(self, uris, startup_id):
        self.open_folders(uris)

    @dbus.service.method(INTERFACE, in_signature="ass", out_signature="")
    def ShowItems(self, uris, startup_id):
        # superfile opens the containing directory; it has no CLI selection API.
        self.open_folders(uris, items=True)

    @dbus.service.method(INTERFACE, in_signature="ass", out_signature="")
    def ShowItemProperties(self, uris, startup_id):
        raise dbus.exceptions.DBusException(
            "superfile does not provide a properties dialog",
            name="org.freedesktop.DBus.Error.NotSupported",
        )


if __name__ == "__main__":
    if "Hyprland" not in os.environ.get("XDG_CURRENT_DESKTOP", "").split(":"):
        os.execv("/usr/bin/dolphin", ["dolphin", "--daemon"])
    DBusGMainLoop(set_as_default=True)
    bus = dbus.SessionBus()
    name = dbus.service.BusName(INTERFACE, bus=bus, do_not_queue=True)
    manager = FileManager(name, "/org/freedesktop/FileManager1")
    GLib.MainLoop().run()
