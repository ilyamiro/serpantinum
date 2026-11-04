pragma Singleton
import QtQuick
import Quickshell
import "../../"

QtObject {
    readonly property string name: {
        const desktop = (typeof SystemInfo !== "undefined" && SystemInfo.desktopEnv) ? SystemInfo.desktopEnv.toLowerCase() : "";
        if (Quickshell.env("NIRI_SOCKET") || desktop.indexOf("niri") !== -1) return "niri";
        if (Quickshell.env("MANGO_INSTANCE_SIGNATURE") || desktop.indexOf("mango") !== -1) return "mango";
        if (Quickshell.env("SWAYSOCK") || desktop.indexOf("sway") !== -1) return "sway";
        if (Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") || desktop.indexOf("hyprland") !== -1) return "hyprland";
        return "unknown";
    }
}
