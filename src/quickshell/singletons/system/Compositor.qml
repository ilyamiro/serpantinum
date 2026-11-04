pragma Singleton
import QtQuick
import Quickshell
import "../../"

QtObject {
    id: root

    readonly property string desktop: (typeof SystemInfo !== "undefined" && SystemInfo.desktopEnv) ? SystemInfo.desktopEnv.toLowerCase() : ""

    readonly property bool isNiri: Boolean(Quickshell.env("NIRI_SOCKET")) || desktop.indexOf("niri") !== -1
    readonly property bool isMango: Boolean(Quickshell.env("MANGO_INSTANCE_SIGNATURE")) || desktop.indexOf("mango") !== -1
    readonly property bool isSway: Boolean(Quickshell.env("SWAYSOCK")) || desktop.indexOf("sway") !== -1
    readonly property bool isHyprland: Boolean(Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")) || desktop.indexOf("hyprland") !== -1

    readonly property string name: {
        if (isNiri) return "niri";
        if (isMango) return "mango";
        if (isSway) return "sway";
        return "hyprland";
    }
}
