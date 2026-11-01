import QtQuick
import QtQuick.Layouts
import "../"
import "../reusables"

Rectangle {
    id: pickerDelegate
    required property var dockWindow
    required property var pickerList
    required property var pickerLens
    required property var model
    required property var modelData
    required property int index

    width: pickerList.width - dockWindow.s(6)
    height: dockWindow.s(44)
    radius: ThemeBackend.borderRadius
    readonly property var resolvedItem: (modelData !== undefined && modelData) ? modelData : model
    readonly property bool isAdded: (resolvedItem && resolvedItem.id) ? dockWindow.isAppInDock(resolvedItem.id) : false

    readonly property bool pressed: pickerMa.pressed
    readonly property bool lensWanted: pickerMa.containsMouse

    onLensWantedChanged: {
        if (lensWanted) pickerList.hoverItem = pickerDelegate;
        else if (pickerList.hoverItem === pickerDelegate) pickerList.hoverItem = null;
    }
    Component.onDestruction: {
        if (pickerList.hoverItem === pickerDelegate) pickerList.hoverItem = null;
    }

    readonly property color contentOnAdded: pickerRowGlass.active ? ThemeBackend.text : ThemeBackend.crust

    color: pickerRowGlass.active ? "transparent" : (isAdded ? ThemeBackend.accent : ((pickerMa.containsMouse && !pickerLens.glassActive) ? Qt.alpha(ThemeBackend.surface1, 0.4) : Qt.alpha(ThemeBackend.surface0, 0.25)))

    Behavior on color { ColorAnimation { duration: 150 } }

    GlassFill {
        id: pickerRowGlass
        anchors.fill: parent
        radius: parent.radius
        allowed: pickerDelegate.isAdded || (pickerMa.containsMouse && !pickerLens.glassActive)
        forceClear: pickerDelegate.isAdded
        tintColor: pickerDelegate.isAdded ? ThemeBackend.text : ThemeBackend.surface0
        tintAmount: pickerDelegate.isAdded ? 0.1 : 0.3
        tintStrength: pickerDelegate.isAdded ? 1.0 : 0.5
        press: pickerMa.pressed ? 0.8 : (pickerDelegate.isAdded ? 0.6 : 0.2)
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: dockWindow.s(8)
        anchors.rightMargin: dockWindow.s(8)
        spacing: dockWindow.s(8)

        Rectangle {
            implicitWidth: dockWindow.s(28)
            implicitHeight: dockWindow.s(28)
            Layout.alignment: Qt.AlignVCenter
            radius: Math.round(dockWindow.s(28) * 0.28)
            color: pickerIconGlass.active ? "transparent" : (pickerDelegate.isAdded ? Qt.tint(ThemeBackend.surface0, Qt.rgba(ThemeBackend.accent.r, ThemeBackend.accent.g, ThemeBackend.accent.b, 0.2)) : ThemeBackend.surface0)
            clip: true

            GlassFill {
                id: pickerIconGlass
                anchors.fill: parent
                radius: parent.radius
                forceClear: pickerDelegate.isAdded
                tintColor: pickerDelegate.isAdded ? ThemeBackend.text : ThemeBackend.surface2
                tintAmount: pickerDelegate.isAdded ? 0.1 : 0.3
            }

            Image {
                id: pIcon
                anchors.fill: parent
                anchors.margins: dockWindow.s(3)
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                smooth: true
                mipmap: true
                property bool failedLoad: false

                visible: source !== "" && status === Image.Ready && !failedLoad

                source: {
                    let ic = pickerDelegate.resolvedItem.icon || "";
                    if (!ic) return "";
                    if (ic.startsWith("file://") || ic.startsWith("image://") || ic.startsWith("http://") || ic.startsWith("https://")) return ic;
                    return ic.startsWith("/") ? "file://" + ic : "image://icon/" + ic;
                }

                onStatusChanged: {
                    if (status === Image.Error) failedLoad = true;
                }
            }

            Text {
                anchors.centerIn: parent
                visible: pIcon.source === "" || pIcon.failedLoad || pIcon.status === Image.Error
                text: pickerDelegate.resolvedItem.name ? pickerDelegate.resolvedItem.name.charAt(0).toUpperCase() : "?"
                font.family: ThemeBackend.fontFamily
                font.pixelSize: dockWindow.s(12)
                font.bold: true
                color: pickerDelegate.isAdded ? (pickerRowGlass.active ? ThemeBackend.text : ThemeBackend.accent) : ThemeBackend.text
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: dockWindow.s(1)

            Text {
                text: pickerDelegate.resolvedItem.name || pickerDelegate.resolvedItem.id || ""
                font.family: ThemeBackend.fontFamily
                font.pixelSize: dockWindow.s(11)
                font.weight: pickerDelegate.isAdded ? Font.Bold : Font.Medium
                color: pickerDelegate.isAdded ? pickerDelegate.contentOnAdded : ThemeBackend.text
                elide: Text.ElideRight
                Layout.fillWidth: true
                Behavior on color { ColorAnimation { duration: 150 } }
            }

            Text {
                text: pickerDelegate.resolvedItem.comment || pickerDelegate.resolvedItem.id || ""
                font.family: ThemeBackend.fontFamily
                font.pixelSize: dockWindow.s(9)
                color: pickerDelegate.isAdded ? pickerDelegate.contentOnAdded : ThemeBackend.subtext0
                opacity: pickerDelegate.isAdded ? 0.9 : 0.85
                elide: Text.ElideRight
                Layout.fillWidth: true
                Behavior on color { ColorAnimation { duration: 150 } }
            }
        }
    }

    MouseArea {
        id: pickerMa
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (typeof Sounds !== "undefined") {
                Sounds.playSfx("reusables/iconbutton/click.wav");
            }
            if (pickerDelegate.isAdded) {
                dockWindow.removeAppByDesktopId(pickerDelegate.resolvedItem.id);
            } else {
                dockWindow.addApp(pickerDelegate.resolvedItem);
            }
        }
    }
}
