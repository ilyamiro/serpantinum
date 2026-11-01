#!/usr/bin/env python3
"""Idle helper for idle/Idle.qml.

Serves org.freedesktop.ScreenSaver on the session bus and, on request, holds a
logind sleep delay inhibitor on the system bus.

Output, one line per event:
    inhibit 1 | inhibit 0   an app asked not to lock, or stopped asking
    sleep                   logind announced PrepareForSleep
    wake                    logind announced the end of sleep

Input, one line per command on stdin:
    sleep-lock on | sleep-lock off

The sleep inhibitor is released once the lock marker file given as the first
argument exists, or after LOCK_WAIT seconds. It is taken again after resume.
"""

import ctypes
import os
import selectors
import signal
import sys
import time

try:
    from jeepney import (
        DBusAddress,
        HeaderFields,
        MatchRule,
        MessageType,
        message_bus,
        new_error,
        new_method_call,
        new_method_return,
    )
    from jeepney.io.blocking import open_dbus_connection
except ImportError:
    print("idle_helper: python-jeepney is not installed", file=sys.stderr)
    sys.exit(0)

NAME = "org.freedesktop.ScreenSaver"
INTERFACE = "org.freedesktop.ScreenSaver"
PATHS = ("/org/freedesktop/ScreenSaver", "/ScreenSaver")

ACTIVITY_HOLD = 60

ALLOW_REPLACEMENT = 1
REPLACE_EXISTING = 2
PRIMARY_OWNER = 1
IN_QUEUE = 2
NO_REPLY_EXPECTED = 1

LOGIN1 = DBusAddress(
    "/org/freedesktop/login1",
    bus_name="org.freedesktop.login1",
    interface="org.freedesktop.login1.Manager",
)
LOCK_WAIT = 4.0
POLL_INTERVAL = 0.05
RETRY_DELAY = 10.0

INTROSPECTION = """<!DOCTYPE node PUBLIC "-//freedesktop//DTD D-BUS Object Introspection 1.0//EN"
 "http://www.freedesktop.org/standards/dbus/1.0/introspect.dtd">
<node>
  <interface name="org.freedesktop.ScreenSaver">
    <method name="Inhibit">
      <arg name="application_name" type="s" direction="in"/>
      <arg name="reason_for_inhibit" type="s" direction="in"/>
      <arg name="cookie" type="u" direction="out"/>
    </method>
    <method name="UnInhibit">
      <arg name="cookie" type="u" direction="in"/>
    </method>
    <method name="SimulateUserActivity"/>
    <method name="GetActive">
      <arg type="b" direction="out"/>
    </method>
  </interface>
  <interface name="org.freedesktop.DBus.Introspectable">
    <method name="Introspect">
      <arg type="s" direction="out"/>
    </method>
  </interface>
  <interface name="org.freedesktop.DBus.Peer">
    <method name="Ping"/>
  </interface>
</node>
"""


def drain(conn, handler):
    while True:
        try:
            msg = conn.receive(timeout=0)
        except TimeoutError:
            return
        handler(msg)


class ScreenSaver:
    def __init__(self, conn):
        self.conn = conn
        self.cookies = {}
        self.next_cookie = 1
        self.activity_until = 0.0
        self.state = None
        self.owner = False

    def inhibited(self):
        return self.owner and (bool(self.cookies) or time.monotonic() < self.activity_until)

    def publish(self):
        state = self.inhibited()
        if state != self.state:
            self.state = state
            print("inhibit 1" if state else "inhibit 0", flush=True)

    def timeout(self):
        if not self.activity_until:
            return None
        left = self.activity_until - time.monotonic()
        if left > 0:
            return left
        self.activity_until = 0.0
        return 0.0

    def new_cookie(self):
        while self.next_cookie in self.cookies or self.next_cookie == 0:
            self.next_cookie = (self.next_cookie + 1) & 0xFFFFFFFF
        cookie = self.next_cookie
        self.next_cookie = (self.next_cookie + 1) & 0xFFFFFFFF
        return cookie

    def reply(self, msg, signature=None, body=()):
        if msg.header.flags & NO_REPLY_EXPECTED:
            return
        self.conn.send(new_method_return(msg, signature, body))

    def error(self, msg, name, text):
        if msg.header.flags & NO_REPLY_EXPECTED:
            return
        self.conn.send(new_error(msg, name, "s", (text,)))

    def handle_call(self, msg):
        fields = msg.header.fields
        path = fields.get(HeaderFields.path)
        interface = fields.get(HeaderFields.interface)
        member = fields.get(HeaderFields.member)

        if interface == "org.freedesktop.DBus.Peer" and member == "Ping":
            self.reply(msg)
            return
        if path not in PATHS:
            self.error(msg, "org.freedesktop.DBus.Error.UnknownObject", f"No object at {path}")
            return
        if interface == "org.freedesktop.DBus.Introspectable" and member == "Introspect":
            self.reply(msg, "s", (INTROSPECTION,))
            return
        if interface not in (INTERFACE, None):
            self.error(msg, "org.freedesktop.DBus.Error.UnknownInterface", f"Unknown interface {interface}")
            return

        signature = fields.get(HeaderFields.signature, "")
        if member in ("Inhibit", "UnInhibit") and signature != ("ss" if member == "Inhibit" else "u"):
            self.error(msg, "org.freedesktop.DBus.Error.InvalidArgs", f"Wrong arguments for {member}")
        elif member == "Inhibit":
            cookie = self.new_cookie()
            self.cookies[cookie] = fields.get(HeaderFields.sender)
            self.reply(msg, "u", (cookie,))
        elif member == "UnInhibit":
            self.cookies.pop(msg.body[0], None)
            self.reply(msg)
        elif member == "SimulateUserActivity":
            self.activity_until = time.monotonic() + ACTIVITY_HOLD
            self.reply(msg)
        elif member == "GetActive":
            self.reply(msg, "b", (False,))
        else:
            self.error(msg, "org.freedesktop.DBus.Error.UnknownMethod", f"Unknown method {member}")

    def handle_signal(self, msg):
        fields = msg.header.fields
        if fields.get(HeaderFields.sender) != "org.freedesktop.DBus":
            return
        member = fields.get(HeaderFields.member)
        if member == "NameOwnerChanged":
            name, _old, new = msg.body
            if name.startswith(":") and not new:
                for cookie in [c for c, owner in self.cookies.items() if owner == name]:
                    del self.cookies[cookie]
        elif member == "NameAcquired" and msg.body[0] == NAME:
            self.owner = True
        elif member == "NameLost" and msg.body[0] == NAME:
            self.owner = False
            self.cookies.clear()
            self.activity_until = 0.0

    def handle(self, msg):
        if msg.header.message_type == MessageType.method_call:
            self.handle_call(msg)
        elif msg.header.message_type == MessageType.signal:
            self.handle_signal(msg)
        self.publish()

    def pump(self):
        drain(self.conn, self.handle)
        self.publish()


class SleepLock:
    def __init__(self, marker, selector):
        self.marker = marker
        self.selector = selector
        self.enabled = False
        self.conn = None
        self.inhibitor = None
        self.release_at = None
        self.retry_at = None

    def set_enabled(self, enabled):
        if enabled == self.enabled:
            return
        self.enabled = enabled
        if enabled:
            self.connect()
        else:
            self.disconnect()

    def take_inhibitor(self):
        msg = new_method_call(
            LOGIN1, "Inhibit", "ssss", ("sleep", "Serpantinum", "Lock the screen before sleep", "delay")
        )
        return self.conn.send_and_get_reply(msg).body[0]

    def release_inhibitor(self):
        if self.inhibitor is not None:
            self.inhibitor.close()
            self.inhibitor = None

    def connect(self):
        self.retry_at = None
        conn = None
        try:
            conn = open_dbus_connection(bus="SYSTEM", enable_fds=True)
            rule = MatchRule(
                type="signal",
                interface=LOGIN1.interface,
                member="PrepareForSleep",
                path=LOGIN1.object_path,
            )
            conn.send_and_get_reply(message_bus.AddMatch(rule))
            self.conn = conn
            self.inhibitor = self.take_inhibitor()
        except Exception as exc:
            print(f"idle_helper: sleep lock unavailable: {exc}", file=sys.stderr)
            self.conn = None
            if conn is not None:
                try:
                    conn.close()
                except Exception:
                    pass
            self.retry_at = time.monotonic() + RETRY_DELAY
            return
        self.selector.register(conn.sock, selectors.EVENT_READ, "system")

    def disconnect(self):
        self.release_at = None
        self.retry_at = None
        try:
            self.release_inhibitor()
        except Exception:
            self.inhibitor = None
        if self.conn is not None:
            try:
                self.selector.unregister(self.conn.sock)
            except Exception:
                pass
            try:
                self.conn.close()
            except Exception:
                pass
            self.conn = None

    def fail(self):
        self.disconnect()
        if self.enabled:
            self.retry_at = time.monotonic() + RETRY_DELAY

    def handle(self, msg):
        if msg.header.message_type != MessageType.signal:
            return
        if msg.header.fields.get(HeaderFields.member) != "PrepareForSleep":
            return
        if msg.body[0]:
            print("sleep", flush=True)
            self.release_at = time.monotonic() + LOCK_WAIT
        else:
            print("wake", flush=True)
            if self.inhibitor is None:
                self.release_at = None
                self.inhibitor = self.take_inhibitor()

    def pump(self):
        if self.conn is None:
            return
        try:
            drain(self.conn, self.handle)
        except Exception:
            self.fail()

    def timeout(self):
        if self.release_at is not None:
            return POLL_INTERVAL
        if self.retry_at is not None:
            return max(0.0, self.retry_at - time.monotonic())
        return None

    def tick(self):
        now = time.monotonic()
        if self.release_at is not None and (now >= self.release_at or os.path.exists(self.marker)):
            self.release_at = None
            try:
                self.release_inhibitor()
            except Exception:
                self.fail()
        if self.retry_at is not None and now >= self.retry_at and self.enabled:
            self.connect()


def read_commands(buffer, sleeper):
    data = os.read(0, 4096)
    if not data:
        sys.exit(0)
    buffer += data
    while b"\n" in buffer:
        line, buffer = buffer.split(b"\n", 1)
        command = line.decode("utf-8", "replace").strip()
        if command == "sleep-lock on":
            sleeper.set_enabled(True)
        elif command == "sleep-lock off":
            sleeper.set_enabled(False)
    return buffer


def main():
    if len(sys.argv) != 2:
        print("usage: idle_helper.py <lock-marker-file>", file=sys.stderr)
        sys.exit(2)
    marker = sys.argv[1]

    try:
        ctypes.CDLL(None, use_errno=True).prctl(1, signal.SIGTERM)
    except (AttributeError, OSError):
        pass

    session = open_dbus_connection(bus="SESSION")
    rule = MatchRule(
        type="signal",
        sender="org.freedesktop.DBus",
        interface="org.freedesktop.DBus",
        member="NameOwnerChanged",
        path="/org/freedesktop/DBus",
    )
    session.send_and_get_reply(message_bus.AddMatch(rule))

    service = ScreenSaver(session)
    reply = session.send_and_get_reply(message_bus.RequestName(NAME, ALLOW_REPLACEMENT | REPLACE_EXISTING))
    if reply.body[0] not in (PRIMARY_OWNER, IN_QUEUE):
        print(f"idle_helper: RequestName failed with {reply.body[0]}", file=sys.stderr)
        sys.exit(1)
    service.owner = reply.body[0] == PRIMARY_OWNER

    selector = selectors.DefaultSelector()
    selector.register(session.sock, selectors.EVENT_READ, "session")
    selector.register(0, selectors.EVENT_READ, "stdin")
    sleeper = SleepLock(marker, selector)
    buffer = b""

    service.publish()
    service.pump()
    while True:
        timeouts = [t for t in (service.timeout(), sleeper.timeout()) if t is not None]
        for key, _events in selector.select(min(timeouts) if timeouts else None):
            if key.data == "stdin":
                buffer = read_commands(buffer, sleeper)
            elif key.data == "session":
                service.pump()
            elif key.data == "system":
                sleeper.pump()
        service.publish()
        sleeper.tick()


if __name__ == "__main__":
    main()
