import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../"
import "../../reusables"

Item {
    id: root

    property var requestedLayoutTemplate: []
    property bool isActiveTab: typeof isCurrentTarget !== "undefined" ? isCurrentTarget : true
    property string safeActiveEdge: typeof activeEdge !== "undefined" ? activeEdge : "left"

    function s(val) {
        return typeof scaleFunc === "function" ? scaleFunc(val) : val;
    }

    property int maxApps: 10
    property real iconSize: s(42)
    property real itemSpacing: s(6)
    property real dockPadding: s(8)

    property real dockThickness: iconSize + (dockPadding * 2)
    property real dockSpan: appModel.count > 0 ? (appModel.count * iconSize) + ((appModel.count - 1) * itemSpacing) + (dockPadding * 2) : s(90)

    property real preferredWidth: dockThickness + s(6)
    property real preferredExtraLength: typeof floatingWidget !== "undefined" ? Math.max(0, dockSpan - floatingWidget.baseSidebarH + s(12)) : dockSpan

    property real counterRotation: {
        if (root.safeActiveEdge === "right") return 180;
        if (root.safeActiveEdge === "bottom") return 90;
        if (root.safeActiveEdge === "top") return -90;
        return 0;
    }

    property bool isHorizontal: root.safeActiveEdge === "bottom" || root.safeActiveEdge === "top"

    property color cBase: ThemeBackend.base
    property color cSurface0: ThemeBackend.surface0
    property color cSurface1: ThemeBackend.surface1
    property color cText: ThemeBackend.text

    function alpha(color, a) { return Qt.rgba(color.r, color.g, color.b, a); }

    Process {
        id: appFetcher
        running: true
        command: ["bash", "-c", "python3 " + Caching.qsDir + "/applauncher/app_fetcher.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    if (this.text && this.text.trim().length > 0) {
                        let parsed = JSON.parse(this.text);
                        appModel.clear();
                        for (let i = 0; i < Math.min(root.maxApps, parsed.length); i++) {
                            appModel.append(parsed[i]);
                        }
                    }
                } catch(e) {}
            }
        }
    }

    ListModel {
        id: appModel
    }

    function launchApp(appName, execStr) {
        let safeName = appName.replace(/[^a-zA-Z0-9_\-\.]/g, "_").toLowerCase();
        let logDir = Caching.getLogDir("applauncher");
        let logFile = logDir + "/" + safeName + ".log";
        let loggedCmd = execStr + " > \"" + logFile + "\" 2>&1";

        Quickshell.execDetached(["python3", Caching.qsDir + "/applauncher/app_fetcher.py", "--log", appName]);
        Quickshell.execDetached(["bash", "-c", loggedCmd]);
        Quickshell.execDetached(["bash", Caching.serpantinumDir + "/scripts/qs_manager.sh", "close"]);
    }

    Item {
        id: orientedRoot
        anchors.centerIn: parent
        width: root.isHorizontal ? root.dockSpan : root.dockThickness
        height: root.isHorizontal ? root.dockThickness : root.dockSpan
        rotation: root.counterRotation
        clip: false

        Rectangle {
            anchors.fill: parent
            radius: ThemeBackend.borderRadius
            color: dockGlass.active ? "transparent" : root.alpha(root.cSurface0, 0.85)
            border.color: root.alpha(root.cText, 0.1)
            border.width: 1

            GlassFill {
                id: dockGlass
                anchors.fill: parent
                radius: parent.radius
                tintColor: root.cSurface0
                tintAmount: 0.3
                shadow: 1
            }

            ListView {
                id: dockList
                anchors.fill: parent
                anchors.margins: root.dockPadding
                orientation: root.isHorizontal ? ListView.Horizontal : ListView.Vertical
                spacing: root.itemSpacing
                model: appModel
                interactive: false
                boundsBehavior: Flickable.StopAtBounds

                delegate: Item {
                    width: root.iconSize
                    height: root.iconSize

                    Rectangle {
                        anchors.fill: parent
                        radius: ThemeBackend.borderRadius
                        color: (itemGlass.active || !itemMouseArea.containsMouse) ? "transparent" : root.alpha(root.cSurface1, 0.4)
                        Behavior on color { ColorAnimation { duration: 300 } }

                        GlassFill {
                            id: itemGlass
                            anchors.fill: parent
                            radius: parent.radius
                            tintColor: root.cSurface1
                            tintAmount: 0.2
                            allowed: itemMouseArea.containsMouse
                            press: itemMouseArea.pressed ? 1 : 0.3
                        }
                    }

                    Item {
                        anchors.centerIn: parent
                        width: parent.width * 0.8
                        height: parent.height * 0.8

                        property real hoverScale: itemMouseArea.pressed ? 0.92 : (itemMouseArea.containsMouse ? 1.08 : 1.0)
                        scale: hoverScale
                        Behavior on scale { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

                        Image {
                            anchors.fill: parent
                            source: model.icon ? (model.icon.startsWith("/") ? "file://" + model.icon : "image://icon/" + model.icon) : "image://icon/application-x-executable"
                            sourceSize: Qt.size(64, 64)
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            mipmap: true
                        }
                    }

                    MouseArea {
                        id: itemMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.launchApp(model.name, model.exec)
                    }
                }
            }
        }
    }
}
