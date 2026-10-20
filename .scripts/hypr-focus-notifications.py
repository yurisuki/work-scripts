#!/usr/bin/env python3
"""Keep focus-mode notifications in memory and replay their original D-Bus payloads.

SwayNC 0.12 keeps DND notifications in history but cannot replay them. Replacing
their original IDs makes them pop up without duplicating history or breaking
the application's ActionInvoked/NotificationClosed signal handling.
"""
import sys

from gi.repository import Gio, GLib

NAME = 'org.violet.FocusNotifications'
PATH = '/org/violet/FocusNotifications'
NOTIFICATIONS = 'org.freedesktop.Notifications'
NOTIFICATION_PATH = '/org/freedesktop/Notifications'
CC = 'org.erikreider.swaync.cc'
CC_PATH = '/org/erikreider/swaync/cc'
SWAYNC = 'org.erikreider.swaync'
DBUS = 'org.freedesktop.DBus'
DBUS_PATH = '/org/freedesktop/DBus'
SYNC_HINTS = ('synchronous', 'private-synchronous', 'x-canonical-private-synchronous')


def call(bus, destination, path, interface, method, parameters=None):
    return bus.call_sync(destination, path, interface, method, parameters,
                         None, Gio.DBusCallFlags.NONE, 5000, None)


def hints_of(body):
    hints = body.get_child_value(6)
    return {entry.get_child_value(0).get_string(): entry.get_child_value(1).get_variant()
            for entry in (hints.get_child_value(i) for i in range(hints.n_children()))}


class Queue:
    def __init__(self):
        self.notifications = {}
        self.synchronous = {}

    def discard(self, notification_id):
        self.notifications.pop(notification_id, None)
        for key, value in list(self.synchronous.items()):
            if value == notification_id:
                del self.synchronous[key]

    def received(self, notification_id, body, suppressed):
        self.discard(notification_id)
        hints = hints_of(body)
        # SwayNC coalesces synchronous notifications even when replaces_id is 0.
        tag = next((hints[key].unpack() for key in reversed(SYNC_HINTS) if key in hints), None)
        if tag:
            self.discard(self.synchronous.get(tag))
            self.synchronous[tag] = notification_id
        if suppressed:
            self.notifications[notification_id] = body

    @staticmethod
    def replay_body(notification_id, body):
        values = [body.get_child_value(i) for i in range(body.n_children())]
        values[1] = GLib.Variant('u', notification_id)
        hints = hints_of(body)
        # Replay is explicitly requested, even if DND was enabled before focus.
        hints['SWAYNC_BYPASS_DND'] = GLib.Variant('b', True)
        hints['SWAYNC_NO_SCRIPT'] = GLib.Variant('b', True)
        values[6] = GLib.Variant('a{sv}', hints)
        return GLib.Variant.new_tuple(*values)


class Recorder:
    def __init__(self):
        self.bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
        self.owner = call(self.bus, DBUS, DBUS_PATH, DBUS, 'GetNameOwner',
                          GLib.Variant('(s)', (NOTIFICATIONS,))).unpack()[0]
        self.dnd = call(self.bus, SWAYNC, CC_PATH, CC, 'GetDnd').unpack()[0]
        self.queue = Queue()
        self.pending = {}
        self.collecting = True
        self.replay_invocation = None
        self.replayed = 0
        self.outstanding = 0
        self.errors = []
        self.loop = GLib.MainLoop()

        # A monitoring connection must never send messages after BecomeMonitor.
        self.monitor = Gio.DBusConnection.new_for_address_sync(
            Gio.dbus_address_get_for_bus_sync(Gio.BusType.SESSION, None),
            Gio.DBusConnectionFlags.AUTHENTICATION_CLIENT | Gio.DBusConnectionFlags.MESSAGE_BUS_CONNECTION,
            None, None)
        self.monitor.add_filter(self.filter_message, None)
        rules = [
            f"type='method_call',interface='{NOTIFICATIONS}',member='Notify'",
            f"type='method_call',interface='{NAME}',member='Replay'",
            f"type='method_return',sender='{NOTIFICATIONS}'",
            f"type='error',sender='{NOTIFICATIONS}'",
            f"type='signal',sender='{NOTIFICATIONS}',interface='{NOTIFICATIONS}',member='NotificationClosed'",
            f"type='signal',sender='{SWAYNC}',interface='{CC}',member='SubscribeV2'",
            f"type='signal',interface='{DBUS}',member='NameOwnerChanged',arg0='{NOTIFICATIONS}'",
        ]
        call(self.monitor, DBUS, DBUS_PATH, 'org.freedesktop.DBus.Monitoring',
             'BecomeMonitor', GLib.Variant('(asu)', (rules, 0)))

        info = Gio.DBusNodeInfo.new_for_xml(f'''<node><interface name="{NAME}">
            <method name="Replay"><arg name="count" type="u" direction="out"/></method>
        </interface></node>''')
        self.bus.register_object(PATH, info.interfaces[0], self.method_call, None, None)
        # Type=dbus only reports ready once monitoring and the Replay method work.
        self.name_id = Gio.bus_own_name_on_connection(self.bus, NAME, Gio.BusNameOwnerFlags.NONE,
                                                     None, None)

    def filter_message(self, connection, message, incoming, data):
        if incoming:
            # GDBus filters run on a worker thread; serialize queue changes here.
            GLib.idle_add(self.receive, message)
            # These calls target SwayNC, not us. GDBus would otherwise answer
            # UnknownMethod, which is forbidden on a monitoring connection.
            if message.get_message_type() == Gio.DBusMessageType.METHOD_CALL:
                return None
        return message

    def receive(self, message):
        kind = message.get_message_type()
        body = message.get_body()
        member = message.get_member()
        if kind == Gio.DBusMessageType.SIGNAL:
            if member == 'NameOwnerChanged':
                _, _, self.owner = body.unpack()
                # Notification IDs belong to one daemon instance only.
                self.queue = Queue()
                self.pending.clear()
            elif member == 'SubscribeV2':
                self.dnd = body.unpack()[1]
            elif member == 'NotificationClosed':
                self.queue.discard(body.unpack()[0])
        elif kind == Gio.DBusMessageType.METHOD_CALL and member == 'Replay':
            # Use the ordered monitor stream as the cutoff, not the separate
            # control connection (which can run before buffered notifications).
            self.collecting = False
        elif kind == Gio.DBusMessageType.METHOD_CALL and member == 'Notify':
            if (message.get_sender() == self.bus.get_unique_name()
                    or message.get_destination() not in (NOTIFICATIONS, SWAYNC, self.owner)):
                return GLib.SOURCE_REMOVE
            hints = hints_of(body)
            urgency = hints.get('urgency', GLib.Variant('y', 1)).unpack()
            bypass = hints.get('SWAYNC_BYPASS_DND', GLib.Variant('b', False)).unpack()
            suppressed = self.collecting and self.dnd and urgency != 2 and not bypass
            key = (message.get_sender(), message.get_serial())
            self.pending[key] = (body, suppressed)
        elif kind in (Gio.DBusMessageType.METHOD_RETURN, Gio.DBusMessageType.ERROR):
            key = (message.get_destination(), message.get_reply_serial())
            original = self.pending.pop(key, None)
            if original and kind == Gio.DBusMessageType.METHOD_RETURN:
                self.queue.received(body.unpack()[0], *original)
        return GLib.SOURCE_REMOVE

    def method_call(self, connection, sender, path, interface, method, parameters, invocation):
        if self.replay_invocation is not None:
            invocation.return_dbus_error(NAME + '.Busy', 'Replay is already running')
            return
        self.replay_invocation = invocation
        self.deadline = GLib.get_monotonic_time() + 5_000_000
        # Let already delivered Notify replies and close signals settle first.
        GLib.timeout_add(20, self.replay)

    def replay(self):
        if self.pending or self.collecting:
            if GLib.get_monotonic_time() < self.deadline:
                return GLib.SOURCE_CONTINUE
            self.errors.append('Timed out waiting for notification IDs')
        if self.queue.notifications:
            # An already-open centre suppresses popups as well. Never open it.
            try:
                call(self.bus, SWAYNC, CC_PATH, CC, 'SetVisibility', GLib.Variant('(b)', (False,)))
            except GLib.Error as error:
                self.errors.append(str(error))
            entries = list(self.queue.notifications.items())
            self.queue = Queue()
            self.outstanding = len(entries)
            for notification_id, body in entries:
                # Dispatch the entire backlog together, with no per-popup delay.
                self.bus.call(self.owner, NOTIFICATION_PATH, NOTIFICATIONS, 'Notify',
                              Queue.replay_body(notification_id, body), GLib.VariantType('(u)'),
                              Gio.DBusCallFlags.NONE, 5000, None, self.replay_finished, None)
        else:
            self.finish()
        return GLib.SOURCE_REMOVE

    def replay_finished(self, connection, result, data):
        try:
            connection.call_finish(result)
            self.replayed += 1
        except GLib.Error as error:
            self.errors.append(str(error))
        self.outstanding -= 1
        if self.outstanding == 0:
            self.finish()

    def finish(self):
        if self.errors:
            self.replay_invocation.return_dbus_error(NAME + '.Failed', '; '.join(self.errors))
        else:
            self.replay_invocation.return_value(GLib.Variant('(u)', (self.replayed,)))
        print(f'Replayed {self.replayed} focus notifications', flush=True)


if __name__ == '__main__':
    try:
        if len(sys.argv) == 2 and sys.argv[1] == 'replay':
            bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
            result = bus.call_sync(NAME, PATH, NAME, 'Replay', None, GLib.VariantType('(u)'),
                                   Gio.DBusCallFlags.NONE, 15000, None)
            print(result.unpack()[0])
        else:
            Recorder().loop.run()
    except GLib.Error as error:
        print(error, file=sys.stderr)
        sys.exit(1)
