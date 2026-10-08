#!/usr/bin/env python3
"""Serves org.freedesktop.ScreenSaver on the session bus for idle/Idle.qml.

Games (through SDL), Steam, Wine and many X11 apps ask this service not to
lock the screen. Without hypridle or a full desktop nobody owns the name, so
those requests are lost. Prints "1" while something holds an inhibit or has
reported activity recently, and "0" otherwise. When another program already
provides the service, waits in the bus queue and takes over if it goes away.
"""

import ctypes
import signal
import sys
import time

try:
    from jeepney import HeaderFields, MatchRule, MessageType, message_bus, new_error, new_method_return
    from jeepney.io.blocking import open_dbus_connection
except ImportError:
    print("screensaver_inhibit: python-jeepney is not installed", file=sys.stderr)
    sys.exit(0)

NAME = "org.freedesktop.ScreenSaver"
INTERFACE = "org.freedesktop.ScreenSaver"
PATHS = ("/org/freedesktop/ScreenSaver", "/ScreenSaver")

# SDL repeats SimulateUserActivity every 30 seconds while a game window is open
ACTIVITY_HOLD = 60

ALLOW_REPLACEMENT = 1
REPLACE_EXISTING = 2
PRIMARY_OWNER = 1
IN_QUEUE = 2
NO_REPLY_EXPECTED = 1

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


class Service:
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
            print("1" if state else "0", flush=True)

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
            return True
        member = fields.get(HeaderFields.member)
        if member == "NameOwnerChanged":
            # A client that quit or crashed can't uninhibit anymore
            name, _old, new = msg.body
            if name.startswith(":") and not new:
                for cookie in [c for c, owner in self.cookies.items() if owner == name]:
                    del self.cookies[cookie]
        elif member == "NameAcquired" and msg.body[0] == NAME:
            self.owner = True
        elif member == "NameLost" and msg.body[0] == NAME:
            # Calls go to the new owner now, ours are stale
            self.owner = False
            self.cookies.clear()
            self.activity_until = 0.0

    def run(self):
        self.publish()
        while True:
            timeout = None
            if self.activity_until:
                left = self.activity_until - time.monotonic()
                if left > 0:
                    timeout = left
                else:
                    self.activity_until = 0.0
            try:
                msg = self.conn.receive(timeout=timeout)
            except TimeoutError:
                self.publish()
                continue

            if msg.header.message_type == MessageType.method_call:
                self.handle_call(msg)
            elif msg.header.message_type == MessageType.signal:
                self.handle_signal(msg)
            self.publish()


def main():
    # Don't outlive quickshell if it crashes, a leftover copy would hold the name
    try:
        ctypes.CDLL(None, use_errno=True).prctl(1, signal.SIGTERM)  # PR_SET_PDEATHSIG
    except (AttributeError, OSError):
        pass

    conn = open_dbus_connection(bus="SESSION")

    # Subscribe before taking the name, so no early call can arrive while we still
    # wait for a reply from the bus.
    rule = MatchRule(
        type="signal",
        sender="org.freedesktop.DBus",
        interface="org.freedesktop.DBus",
        member="NameOwnerChanged",
        path="/org/freedesktop/DBus",
    )
    conn.send_and_get_reply(message_bus.AddMatch(rule))

    # Replace an older copy of this script (left over from a reload). A program that
    # didn't allow it, like hypridle or a desktop session, keeps the name and we
    # wait in the queue until it quits.
    service = Service(conn)
    reply = conn.send_and_get_reply(message_bus.RequestName(NAME, ALLOW_REPLACEMENT | REPLACE_EXISTING))
    if reply.body[0] not in (PRIMARY_OWNER, IN_QUEUE):
        print(f"screensaver_inhibit: RequestName failed with {reply.body[0]}", file=sys.stderr)
        sys.exit(1)
    service.owner = reply.body[0] == PRIMARY_OWNER
    service.run()


if __name__ == "__main__":
    main()
