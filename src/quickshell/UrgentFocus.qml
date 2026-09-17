import QtQuick
import Quickshell
import Quickshell.Hyprland

Item {
    id: urgentFocusRoot

    // A window that asks for attention - a link handed to an already running
    // browser, a file dialog, a chat client called by a notification - only gets
    // an urgent hint by default, so the workspace it lives on has to be found by
    // hand. With this on, the shell follows the hint and focuses the window,
    // which pulls the workspace and the monitor along with it.
    readonly property bool followUrgent: {
        let s = (typeof Config !== "undefined") ? Config.rawSettings : null;
        return !!(s && s.general && s.general.followUrgentWindows);
    }

    property bool isHyprland: false

    Component.onCompleted: {
        let de = SystemInfo.desktopEnv ? SystemInfo.desktopEnv.toLowerCase() : "";
        urgentFocusRoot.isHyprland = de.indexOf("hyprland") !== -1;
    }

    // socket2 spells the address as bare lowercase hex, while the dispatcher
    // wants the 0x form. Events carrying several fields separate them with a
    // comma, so the address is cut at the first one rather than trusted whole.
    function focusUrgentWindow(rawAddress) {
        if (!rawAddress) return;

        let address = String(rawAddress).trim();
        let comma = address.indexOf(",");
        if (comma !== -1) address = address.substring(0, comma);
        if (address === "") return;
        if (address.indexOf("0x") !== 0) address = "0x" + address;

        // Dispatched as lua, the same way the workspace widgets already switch
        // workspaces. Hyprland.usingLua is not used to pick a syntax here: it
        // starts out false and only flips once Quickshell has asked, so an
        // urgent window right after login would get the plain dispatcher, which
        // a lua config rejects outright.
        Hyprland.dispatch("hl.dsp.focus({ window = \"address:" + address + "\" })");
    }

    Connections {
        target: (typeof Hyprland !== "undefined") ? Hyprland : null
        enabled: urgentFocusRoot.followUrgent && urgentFocusRoot.isHyprland

        function onRawEvent(event) {
            if (!event || event.name !== "urgent") return;
            urgentFocusRoot.focusUrgentWindow(event.data);
        }
    }
}
