#!/usr/bin/env python3
"""Integration checks on a private session bus; never touches desktop notifications.

Run: dbus-run-session -- python3 tests/test_focus_notifications.py
"""
import importlib.util
from pathlib import Path
import subprocess
import threading
import time
import unittest

from gi.repository import Gio, GLib

SCRIPT = Path(__file__).resolve().parents[1] / '.scripts/hypr-focus-notifications.py'
spec = importlib.util.spec_from_file_location('focus_notifications', SCRIPT)
focus = importlib.util.module_from_spec(spec)
spec.loader.exec_module(focus)


class FakeSwayNC:
    def __init__(self):
        self.bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
        self.dnd = False
        self.visible = False
        self.calls = []
        self.next_id = 0
        self.closed = []
        self.xml = Gio.DBusNodeInfo.new_for_xml(f'''<node>
          <interface name="{focus.NOTIFICATIONS}">
            <method name="Notify">
              <arg type="s" direction="in"/><arg type="u" direction="in"/>
              <arg type="s" direction="in"/><arg type="s" direction="in"/>
              <arg type="s" direction="in"/><arg type="as" direction="in"/>
              <arg type="a{{sv}}" direction="in"/><arg type="i" direction="in"/>
              <arg type="u" direction="out"/>
            </method>
            <method name="CloseNotification"><arg type="u" direction="in"/></method>
            <signal name="NotificationClosed"><arg type="u"/><arg type="u"/></signal>
          </interface>
          <interface name="{focus.CC}">
            <method name="GetDnd"><arg type="b" direction="out"/></method>
            <method name="SetDnd"><arg type="b" direction="in"/></method>
            <method name="SetVisibility"><arg type="b" direction="in"/></method>
            <signal name="SubscribeV2"><arg type="u"/><arg type="b"/><arg type="b"/><arg type="b"/></signal>
          </interface>
        </node>''')
        self.bus.register_object(focus.NOTIFICATION_PATH, self.xml.interfaces[0], self.method, None, None)
        self.bus.register_object(focus.CC_PATH, self.xml.interfaces[1], self.method, None, None)
        for name in (focus.NOTIFICATIONS, focus.SWAYNC):
            result = focus.call(self.bus, focus.DBUS, focus.DBUS_PATH, focus.DBUS,
                                'RequestName', GLib.Variant('(su)', (name, 4))).unpack()[0]
            if result != 1:
                raise RuntimeError('Run these tests with dbus-run-session on a private bus')
        self.loop = GLib.MainLoop()
        self.thread = threading.Thread(target=self.loop.run, daemon=True)
        self.thread.start()

    def emit_state(self):
        self.bus.emit_signal(None, focus.CC_PATH, focus.CC, 'SubscribeV2',
                             GLib.Variant('(ubbb)', (0, self.dnd, self.visible, False)))

    def method(self, bus, sender, path, interface, method, args, invocation):
        if method == 'Notify':
            notification_id = args.get_child_value(1).unpack()
            if not notification_id:
                self.next_id += 1
                notification_id = self.next_id
            self.calls.append((notification_id, args))
            self.emit_state()
            invocation.return_value(GLib.Variant('(u)', (notification_id,)))
        elif method == 'CloseNotification':
            notification_id = args.unpack()[0]
            self.closed.append(notification_id)
            bus.emit_signal(None, focus.NOTIFICATION_PATH, focus.NOTIFICATIONS, 'NotificationClosed',
                            GLib.Variant('(uu)', (notification_id, 3)))
            invocation.return_value(None)
        elif method == 'GetDnd':
            invocation.return_value(GLib.Variant('(b)', (self.dnd,)))
        else:
            if method == 'SetDnd':
                self.dnd = args.unpack()[0]
            else:
                self.visible = args.unpack()[0]
            self.emit_state()
            invocation.return_value(None)


class ReplayTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.server = FakeSwayNC()

    @classmethod
    def tearDownClass(cls):
        cls.server.loop.quit()
        cls.server.thread.join(timeout=2)

    def setUp(self):
        self.set_dnd(False)
        self.server.visible = False
        self.server.calls.clear()
        self.recorder = subprocess.Popen(['python3', str(SCRIPT)], stdout=subprocess.PIPE,
                                         stderr=subprocess.PIPE, text=True)
        deadline = time.monotonic() + 5
        while True:
            try:
                focus.call(self.server.bus, focus.DBUS, focus.DBUS_PATH, focus.DBUS,
                           'GetNameOwner', GLib.Variant('(s)', (focus.NAME,)))
                break
            except GLib.Error:
                if time.monotonic() > deadline or self.recorder.poll() is not None:
                    self.recorder.terminate()
                    self.fail(str(self.recorder.communicate(timeout=2)))
                time.sleep(0.01)

    def tearDown(self):
        self.recorder.terminate()
        self.recorder.communicate(timeout=3)

    def set_dnd(self, enabled):
        focus.call(self.server.bus, focus.SWAYNC, focus.CC_PATH, focus.CC,
                   'SetDnd', GLib.Variant('(b)', (enabled,)))

    def notify(self, summary, replaces=0, hints=None):
        body = GLib.Variant('(susssasa{sv}i)', ('Focus test', replaces, 'dialog-information',
                            summary, 'Body with <b>markup</b> and žluťoučký', ['default', 'Open'],
                            hints or {}, 7000))
        return focus.call(self.server.bus, focus.NOTIFICATIONS, focus.NOTIFICATION_PATH,
                          focus.NOTIFICATIONS, 'Notify', body).unpack()[0]

    def replay(self):
        start = len(self.server.calls)
        count = focus.call(self.server.bus, focus.NAME, focus.PATH, focus.NAME, 'Replay').unpack()[0]
        return count, self.server.calls[start:]

    def test_only_focus_notifications_replay_with_original_ids_and_actions(self):
        self.notify('Before focus')
        self.set_dnd(True)
        first = self.notify('During focus')
        second = self.notify('Another notification')
        self.set_dnd(False)
        self.notify('After focus')
        count, calls = self.replay()
        self.assertEqual(count, 2)
        self.assertEqual([item[0] for item in calls], [first, second])
        self.assertEqual(calls[0][1].unpack()[3], 'During focus')
        self.assertEqual(calls[0][1].unpack()[5], ['default', 'Open'])
        self.assertFalse(self.server.visible)

    def test_replacements_and_closed_notifications(self):
        self.set_dnd(True)
        first = self.notify('Old version')
        self.notify('Latest version', replaces=first)
        closed = self.notify('Withdrawn')
        focus.call(self.server.bus, focus.NOTIFICATIONS, focus.NOTIFICATION_PATH,
                   focus.NOTIFICATIONS, 'CloseNotification', GLib.Variant('(u)', (closed,)))
        self.set_dnd(False)
        count, calls = self.replay()
        self.assertEqual(count, 1)
        self.assertEqual(calls[0][0], first)
        self.assertEqual(calls[0][1].unpack()[3], 'Latest version')

    def test_transient_and_binary_hints_survive_and_critical_is_not_repeated(self):
        self.set_dnd(True)
        hints = {'transient': GLib.Variant('b', True),
                 'image-data': GLib.Variant('(iiibiiay)', (1, 1, 4, True, 8, 4, [255, 0, 128, 255]))}
        first = self.notify('Transient with image', hints=hints)
        self.notify('Already shown critical', hints={'urgency': GLib.Variant('y', 2)})
        self.notify('Already shown bypass', hints={'SWAYNC_BYPASS_DND': GLib.Variant('b', True)})
        self.set_dnd(False)
        count, calls = self.replay()
        self.assertEqual(count, 1)
        self.assertEqual(calls[0][0], first)
        actual = focus.hints_of(calls[0][1])
        for key, value in hints.items():
            self.assertTrue(actual[key].equal(value))

    def test_synchronous_updates_collapse_and_existing_dnd_is_preserved(self):
        self.set_dnd(True)
        hints = {'x-canonical-private-synchronous': GLib.Variant('s', 'progress')}
        self.notify('Progress 10%', hints=hints)
        last = self.notify('Progress 100%', hints=hints)
        self.server.visible = True
        count, calls = self.replay()
        self.assertEqual(count, 1)
        self.assertEqual(calls[0][0], last)
        self.assertTrue(focus.hints_of(calls[0][1])['SWAYNC_BYPASS_DND'].unpack())
        self.assertTrue(self.server.dnd)
        self.assertFalse(self.server.visible)

    def test_empty_focus_does_not_show_or_close_anything(self):
        self.set_dnd(True)
        self.set_dnd(False)
        self.server.visible = True
        self.assertEqual(self.replay(), (0, []))
        self.assertTrue(self.server.visible)

    def test_large_backlog_is_replayed_once_in_one_batch(self):
        self.set_dnd(True)
        ids = [self.notify(f'Message {i}') for i in range(100)]
        self.set_dnd(False)
        count, calls = self.replay()
        self.assertEqual(count, 100)
        self.assertEqual([item[0] for item in calls], ids)

    def test_burst_immediately_before_replay_is_not_lost(self):
        self.set_dnd(True)
        for i in range(100):
            body = GLib.Variant('(susssasa{sv}i)', ('Focus test', 0, '', f'Burst {i}', '', [], {}, -1))
            self.server.bus.call(focus.NOTIFICATIONS, focus.NOTIFICATION_PATH, focus.NOTIFICATIONS,
                                 'Notify', body, None, Gio.DBusCallFlags.NONE, 5000, None,
                                 lambda bus, result, data: bus.call_finish(result), None)
        count, calls = self.replay()
        self.assertEqual(count, 100)
        replays = [body for _, body in calls if 'SWAYNC_BYPASS_DND' in focus.hints_of(body)]
        self.assertEqual(len(replays), 100)


if __name__ == '__main__':
    unittest.main(verbosity=2)
