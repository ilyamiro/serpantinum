"""Synthetic MPRIS servers on the runner's private D-Bus, not real applications."""
import subprocess
import sys
import dbus
import dbus.service
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib

DBusGMainLoop(set_as_default=True)
ROOT = "org.mpris.MediaPlayer2"
PLAYER = ROOT + ".Player"
PROPERTIES = "org.freedesktop.DBus.Properties"


class Player(dbus.service.Object):
    def __init__(self, name, identity, desktop=None):
        self.bus = dbus.SessionBus(private=True)
        self.name = dbus.service.BusName(ROOT + "." + name, self.bus)
        self.root = {"Identity": identity, "DesktopEntry": identity.lower() if desktop is None else desktop, "CanQuit": False,
                     "CanRaise": False, "HasTrackList": False, "SupportedUriSchemes": dbus.Array([], signature="s"),
                     "SupportedMimeTypes": dbus.Array([], signature="s")}
        self.props = {"PlaybackStatus": "Playing", "LoopStatus": "None", "Rate": 1.0,
                      "Shuffle": False, "Volume": 1.0, "Position": dbus.Int64(0),
                      "MinimumRate": 1.0, "MaximumRate": 1.0,
                      "CanGoNext": True, "CanGoPrevious": True, "CanPlay": True,
                      "CanPause": True, "CanSeek": True, "CanControl": True,
                      "Metadata": dbus.Dictionary({"xesam:title": "Track", "xesam:artist": ["Artist"],
                                                  "mpris:trackid": dbus.ObjectPath("/track/one"),
                                                  "mpris:length": dbus.Int64(200000000)}, signature="sv")}
        super().__init__(self.bus, "/org/mpris/MediaPlayer2")

    @dbus.service.method(PROPERTIES, in_signature="s", out_signature="a{sv}")
    def GetAll(self, interface):
        return self.props if interface == PLAYER else self.root if interface == ROOT else {}

    @dbus.service.method(PROPERTIES, in_signature="ss", out_signature="v")
    def Get(self, interface, name):
        return self.GetAll(interface)[name]

    @dbus.service.signal(PROPERTIES, signature="sa{sv}as")
    def PropertiesChanged(self, interface, changed, invalidated):
        pass

    def update(self, key, value):
        self.props[key] = value
        self.PropertiesChanged(PLAYER, {key: value}, [])

    @dbus.service.method(PLAYER, in_signature="", out_signature="")
    def PlayPause(self):
        self.update("PlaybackStatus", "Paused" if self.props["PlaybackStatus"] == "Playing" else "Playing")

    @dbus.service.method(PLAYER, in_signature="", out_signature="")
    def Play(self):
        self.update("PlaybackStatus", "Playing")

    @dbus.service.method(PLAYER, in_signature="", out_signature="")
    def Pause(self):
        self.update("PlaybackStatus", "Paused")


class Control(dbus.service.Object):
    def __init__(self):
        self.bus = dbus.SessionBus(private=True)
        self.name = dbus.service.BusName("org.serpantinum.MediaTest", self.bus)
        self.players = {"spotify": Player("spotify", "Spotify"),
                        "browser": Player("chromium.instance42", "Brave")}
        self.retired = []
        super().__init__(self.bus, "/test")

    @dbus.service.method("org.serpantinum.MediaTest", in_signature="ss", out_signature="")
    def Change(self, name, action):
        if action == "close":
            player = self.players.pop(name)
            player.bus.release_name(player.name.get_name())
            player.remove_from_connection()
            self.retired.append(player)
        elif action == "open":
            self.players[name] = Player("firefox.instance7", "Firefox")
        elif action == "reconnect":
            self.players[name] = Player("custom.instance999", "Custom Player", "org.example.Custom")
        elif action == "second-instance":
            self.players[name] = Player("custom.instance1", "Custom Player", "org.example.Custom")
        elif action == "custom":
            self.players[name] = Player("custom.instance42", "Custom Player", "org.example.Custom")
        elif action == "metadata":
            metadata = dict(self.players[name].props["Metadata"])
            metadata["xesam:title"] = "Changed title"
            self.players[name].update("Metadata", dbus.Dictionary(metadata, signature="sv"))
        else:
            self.players[name].update("PlaybackStatus", action)


def main():
    control = Control()
    process = subprocess.Popen(["quickshell", "--no-color", "-p", sys.argv[1]])
    loop = GLib.MainLoop()

    def finished():
        if process.poll() is not None:
            loop.quit()
            return False
        return True

    GLib.timeout_add(50, finished)
    loop.run()
    return process.returncode


if __name__ == "__main__":
    sys.exit(main())
