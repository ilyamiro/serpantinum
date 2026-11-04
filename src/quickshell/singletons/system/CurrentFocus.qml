pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../../"

Item {
    id: root

    property string appClass: "Desktop"
    property string windowTitle: ""
    readonly property bool isDesktop: appClass === "Desktop"
    readonly property string appTitle: isDesktop ? I18n.t("guide.wellbeing.desktop") : windowTitle
    readonly property string displayText: appTitle !== "" ? appTitle : appClass
    readonly property bool isFocused: displayText !== ""


    function setWindow(cls, title) {
        cls = String(cls || "").trim();
        title = String(title || "").trim();
        let clsLower = cls.toLowerCase();
        if (clsLower.indexOf("quickshell") !== -1 || clsLower.indexOf("qs-master") !== -1 || title.toLowerCase().indexOf("qs-master") !== -1) {
            cls = "Quickshell";
            title = "Quickshell";
        }
        if (cls === "") cls = "Unknown";
        root.windowTitle = title !== "" ? title : cls;
        root.appClass = cls;
    }

    function setDesktop() {
        root.windowTitle = "";
        root.appClass = "Desktop";
    }

    property bool hyprlandEmpty: false

    function updateHyprland() {
        let t = Hyprland.activeToplevel;
        if (root.hyprlandEmpty || !t || !t.address) {
            setDesktop();
            return;
        }
        let ipc = t.lastIpcObject || {};
        let cls = ipc.initialClass || ipc["class"] || (t.wayland ? t.wayland.appId : "");
        let title = ipc.initialTitle || ipc.title || t.title;
        setWindow(cls, title);
    }

    function updateNiri() {
        let map = NiriState.windowsMap || {};
        for (let id in map) {
            let w = map[id];
            if (w && w.is_focused) {
                setWindow(w.app_id, w.title);
                return;
            }
        }
        setDesktop();
    }

    function updateSway() {
        let list = SwayState.windows || [];
        for (let i = 0; i < list.length; i++) {
            if (list[i].focused) {
                setWindow(list[i].appId, list[i].title);
                return;
            }
        }
        setDesktop();
    }

    function updateMango() {
        let list = MangoState.clients || [];
        for (let i = 0; i < list.length; i++) {
            if (list[i] && list[i].is_focused) {
                setWindow(list[i].appid, list[i].title);
                return;
            }
        }
        setDesktop();
    }

    function update() {
        if (Compositor.name === "niri") updateNiri();
        else if (Compositor.name === "mango") updateMango();
        else if (Compositor.name === "sway") updateSway();
        else if (Compositor.name === "hyprland") updateHyprland();
        else setDesktop();
    }

    Connections {
        target: Compositor.name === "hyprland" ? Hyprland : null
        function onActiveToplevelChanged() {
            Hyprland.refreshToplevels();
            root.updateHyprland();
        }
        function onRawEvent(event) {
            if (!event || event.name !== "activewindowv2") return;
            root.hyprlandEmpty = event.data.trim() === "";
            root.updateHyprland();
        }
    }

    Connections {
        target: Compositor.name === "hyprland" ? Hyprland.activeToplevel : null
        function onLastIpcObjectChanged() { root.updateHyprland(); }
        function onTitleChanged() { root.updateHyprland(); }
    }

    Connections {
        target: Compositor.name === "niri" ? NiriState : null
        function onWindowsUpdated() { root.updateNiri(); }
    }

    Connections {
        target: Compositor.name === "sway" ? SwayState : null
        function onWindowsUpdated() { root.updateSway(); }
    }

    Connections {
        target: Compositor.name === "mango" ? MangoState : null
        function onClientsUpdated() { root.updateMango(); }
    }

    Component.onCompleted: {
        if (Compositor.name === "niri") NiriState.subscribe();
        else if (Compositor.name === "mango") MangoState.subscribeClients();
        else if (Compositor.name === "sway") SwayState.subscribeWindows();
        update();
    }
}
