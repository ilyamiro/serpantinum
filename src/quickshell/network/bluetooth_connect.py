#!/usr/bin/env python3
"""Pair and connect through BlueZ, with an agent scoped to this operation."""
import json
import re
import sys

import dbus
import dbus.service
from dbus.mainloop.glib import DBusGMainLoop
import gi

gi.require_version("Gtk", "3.0")
from gi.repository import GLib, Gtk

BLUEZ = "org.bluez"
DEVICE = "org.bluez.Device1"
PROPERTIES = "org.freedesktop.DBus.Properties"


class Rejected(dbus.DBusException):
    _dbus_error_name = "org.bluez.Error.Rejected"


class Agent(dbus.service.Object):
    def __init__(self, bus, device_path, name):
        super().__init__(bus, "/serpantinum/bluetooth_agent")
        self.device_path = device_path
        self.name = name
        self.dialog = None

    def prompt(self, device, message, entry=False, numeric=False):
        if str(device) != self.device_path:
            raise Rejected("Unexpected device")
        self.Cancel()
        dialog = Gtk.MessageDialog(
            text="Bluetooth pairing: " + self.name,
            secondary_text=message,
            message_type=Gtk.MessageType.QUESTION,
            buttons=Gtk.ButtonsType.OK_CANCEL,
        )
        self.dialog = dialog
        field = None
        if entry:
            field = Gtk.Entry()
            field.set_activates_default(True)
            dialog.get_content_area().pack_start(field, False, False, 8)
            field.show()
        dialog.set_default_response(Gtk.ResponseType.OK)
        response = dialog.run()
        value = field.get_text() if field else None
        dialog.destroy()
        self.dialog = None
        if response != Gtk.ResponseType.OK:
            raise Rejected("Pairing cancelled")
        if numeric and (not value.isdigit() or len(value) > 6):
            raise Rejected("Passkey must contain at most six digits")
        return value

    def display(self, device, message):
        if str(device) != self.device_path:
            raise Rejected("Unexpected device")
        if self.dialog:
            self.dialog.format_secondary_text(message)
            return
        dialog = Gtk.MessageDialog(
            text="Bluetooth pairing: " + self.name,
            secondary_text=message,
            message_type=Gtk.MessageType.INFO,
            buttons=Gtk.ButtonsType.CLOSE,
        )
        self.dialog = dialog

        def close(dialog, response):
            dialog.destroy()
            if self.dialog is dialog:
                self.dialog = None

        dialog.connect("response", close)
        dialog.show_all()

    @dbus.service.method("org.bluez.Agent1", in_signature="", out_signature="")
    def Release(self):
        self.Cancel()

    @dbus.service.method("org.bluez.Agent1", in_signature="", out_signature="")
    def Cancel(self):
        if self.dialog:
            self.dialog.response(Gtk.ResponseType.CANCEL)

    @dbus.service.method("org.bluez.Agent1", in_signature="o", out_signature="s")
    def RequestPinCode(self, device):
        return self.prompt(device, "Enter the device PIN.", entry=True)

    @dbus.service.method("org.bluez.Agent1", in_signature="o", out_signature="u")
    def RequestPasskey(self, device):
        return dbus.UInt32(int(self.prompt(device, "Enter the device passkey.", entry=True, numeric=True)))

    @dbus.service.method("org.bluez.Agent1", in_signature="ou", out_signature="")
    def RequestConfirmation(self, device, passkey):
        self.prompt(device, "Confirm that the device shows %06d." % passkey)

    @dbus.service.method("org.bluez.Agent1", in_signature="o", out_signature="")
    def RequestAuthorization(self, device):
        self.prompt(device, "Allow this device to pair?")

    @dbus.service.method("org.bluez.Agent1", in_signature="os", out_signature="")
    def AuthorizeService(self, device, uuid):
        self.prompt(device, "Allow this device to connect?")

    @dbus.service.method("org.bluez.Agent1", in_signature="os", out_signature="")
    def DisplayPinCode(self, device, pin):
        self.display(device, "Enter PIN %s on the device." % pin)

    @dbus.service.method("org.bluez.Agent1", in_signature="ouq", out_signature="")
    def DisplayPasskey(self, device, passkey, entered):
        self.display(device, "Enter %06d on the device, then press Enter. (%d digits entered)" % (passkey, entered))


def main(mac):
    if not re.fullmatch(r"(?:[0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}", mac):
        raise ValueError("Invalid Bluetooth address")
    DBusGMainLoop(set_as_default=True)
    bus = dbus.SystemBus()
    objects = dbus.Interface(bus.get_object(BLUEZ, "/"), "org.freedesktop.DBus.ObjectManager").GetManagedObjects()
    path = next(str(p) for p, interfaces in objects.items()
                if DEVICE in interfaces and str(interfaces[DEVICE]["Address"]).lower() == mac.lower())
    obj = bus.get_object(BLUEZ, path)
    props = dbus.Interface(obj, PROPERTIES)
    device = dbus.Interface(obj, DEVICE)
    agent = Agent(bus, path, str(props.Get(DEVICE, "Alias")))
    manager = dbus.Interface(bus.get_object(BLUEZ, "/org/bluez"), "org.bluez.AgentManager1")
    manager.RegisterAgent(agent._object_path, "KeyboardDisplay")
    loop = GLib.MainLoop()
    result = {"ok": False, "error": "Connection timed out"}
    finished = False
    connecting = False
    ready_since = None

    def finish(ok, error=""):
        nonlocal finished
        if finished:
            return
        finished = True
        result.update(ok=ok, error=str(error))
        agent.Cancel()
        loop.quit()

    def fail(error):
        finish(False, error)

    def connect():
        # Pair() establishes a transport for service discovery, but does not
        # guarantee that an input/audio profile is connected. Always ask BlueZ
        # to connect profiles after Pair() completes, even if Connected is true.
        try:
            props.Set(DEVICE, "Trusted", dbus.Boolean(True))
            device.Connect(reply_handler=connected, error_handler=connect_failed, timeout=30)
        except Exception as error:
            fail(error)

    def connect_failed(error):
        if isinstance(error, dbus.DBusException) and error.get_dbus_name() == "org.bluez.Error.AlreadyConnected":
            connected()
        else:
            fail(error)

    def connected():
        nonlocal connecting
        connecting = True

    def poll():
        nonlocal ready_since
        if finished:
            return False
        if connecting:
            try:
                ready = bool(props.Get(DEVICE, "Connected") and props.Get(DEVICE, "ServicesResolved"))
                now = GLib.get_monotonic_time()
                if ready:
                    if ready_since is None:
                        ready_since = now
                    elif now - ready_since >= 1_000_000:
                        finish(True)
                else:
                    ready_since = None
                    if not props.Get(DEVICE, "Connected"):
                        finish(False, "Device disconnected before its services became ready")
            except dbus.DBusException as error:
                fail(error)
        return not finished

    def start():
        try:
            if props.Get(DEVICE, "Paired") or props.Get(DEVICE, "Bonded"):
                connect()
            else:
                adapter = str(props.Get(DEVICE, "Adapter"))
                dbus.Interface(bus.get_object(BLUEZ, adapter), PROPERTIES).Set(
                    "org.bluez.Adapter1", "Pairable", dbus.Boolean(True))
                device.Pair(reply_handler=connect, error_handler=fail, timeout=90)
        except Exception as error:
            fail(error)
        return False

    def timeout():
        try:
            device.CancelPairing(timeout=2)
        except dbus.DBusException:
            pass
        finish(False, "Pairing or connection timed out")
        return False

    GLib.idle_add(start)
    GLib.timeout_add(250, poll)
    GLib.timeout_add_seconds(110, timeout)
    loop.run()
    manager.UnregisterAgent(agent._object_path)
    print(json.dumps(result), flush=True)
    return 0 if result["ok"] else 1


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1]))
    except Exception as error:
        print(json.dumps({"ok": False, "error": str(error)}), flush=True)
        sys.exit(1)
