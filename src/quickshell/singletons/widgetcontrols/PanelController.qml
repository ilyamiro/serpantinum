pragma Singleton
import QtQuick
import Quickshell
import "../../"

Item {
    id: controller

    property string activeWidget: "hidden"
    property string targetScreen: ""
    property var activeScreen: null

    property bool isSysOpen: activeWidget === "system"
    property bool isNotifOpen: activeWidget === "notifications"

    function setActive(widget, screenName, screenObj) {
        let w = widget || "hidden";
        controller.activeWidget = w;
        if (w === "hidden") {
            controller.targetScreen = "";
            controller.activeScreen = null;
        } else {
            controller.targetScreen = screenName || "";
            controller.activeScreen = screenObj || null;
        }
    }

    function reset() {
        setActive("hidden", "", null);
    }
}
