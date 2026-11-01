import QtQuick
import QtQuick.Layouts
import "../../../"
import "../../../reusables"

Rectangle {
    id: box
    required property var tab
    readonly property var rootObj: tab.rootObj

    property url source
    property Component widgetComponent: null
    property Component fallback: null
    property string variantId: ""
    property real sideHeight: 120
    property var widget: null

    readonly property bool faceMissing: faceLoader.status === Loader.Error || !faceLoader.item

    function rebuildWidget() {
        if (widget) widget.destroy();
        widget = widgetComponent ? widgetComponent.createObject(box, { tab: box.tab, variantId: box.variantId }) : null;
    }

    onWidgetComponentChanged: rebuildWidget()
    onWidgetChanged: if (faceLoader.item) faceLoader.item.widget = widget
    Component.onCompleted: rebuildWidget()

    Layout.fillWidth: true
    implicitHeight: rootObj.s(tab.isSideBar ? sideHeight : 72)
    radius: ThemeBackend.borderRadius
    color: ThemeBackend.glassActive ? ThemeBackend.faded(ThemeBackend.base) : Qt.darker(ThemeBackend.mantle, 1.1)
    clip: true

    WallpaperBlur {
        z: -1
        anchors.fill: parent
        radius: parent.radius
        standalone: true
        surfaceEnabled: !ThemeBackend.liquidGlass && tab.inView(parent)
    }

    GlassFill {
        z: -1
        anchors.fill: parent
        radius: parent.radius
        allowed: tab.inView(parent)
        tintColor: ThemeBackend.base
    }

    Item {
        anchors.fill: parent
        enabled: false

        Loader {
            id: faceLoader
            anchors.centerIn: parent
            width: item ? item.implicitWidth : 0
            height: item ? item.implicitHeight : 0
            scale: Math.min(1.0, Math.min((box.width - rootObj.s(16)) / Math.max(1, width), (box.height - rootObj.s(16)) / Math.max(1, height)))
            asynchronous: false
            property bool seen: false
            readonly property bool wanted: box.tab.inView(parent)
            active: seen || wanted
            onWantedChanged: if (wanted) seen = true
            Component.onCompleted: if (wanted) seen = true
            source: box.source

            onLoaded: {
                if (item) {
                    item.width = Qt.binding(function() { return item.implicitWidth; });
                    item.height = Qt.binding(function() { return item.implicitHeight; });
                    item.widget = box.widget;
                }
            }
        }

        Loader {
            anchors.fill: parent
            active: box.fallback !== null
            visible: box.faceMissing
            sourceComponent: box.fallback
            onLoaded: item.variantId = box.variantId
        }
    }
}
