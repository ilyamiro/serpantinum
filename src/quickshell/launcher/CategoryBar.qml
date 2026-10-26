import QtQuick
import "../"
import "../reusables"

Item {
    id: root

    required property var categories
    property string activeId: "All"
    property bool interactive: true

    property int fontPixelSize: 11
    property int iconPixelSize: 13
    property color accentColor: ThemeBackend.mauve
    property color textColor: ThemeBackend.text
    property color activeTextColor: ThemeBackend.crust
    property string switchSound: "reusables/switch/sfx.wav"

    signal activated(string id)

    implicitHeight: s(26)
    clip: true

    function s(val) {
        return (typeof Scaler !== "undefined" && Scaler.s) ? Scaler.s(val) : val;
    }

    readonly property int activeIndex: {
        for (let i = 0; i < root.categories.length; i++) {
            if (root.categories[i].id === root.activeId) return i;
        }
        return 0;
    }

    property int previousIndex: 0
    property int itemsRevision: 0

    readonly property Item activeItem: (root.itemsRevision >= 0 && repeater && root.categories
                                        && root.activeIndex >= 0 && root.activeIndex < repeater.count)
        ? repeater.itemAt(root.activeIndex)
        : null

    onActiveIndexChanged: {
        if (root.activeIndex > root.previousIndex) {
            leftAnim.duration = 170;
            rightAnim.duration = 120;
        } else if (root.activeIndex < root.previousIndex) {
            leftAnim.duration = 120;
            rightAnim.duration = 170;
        }
        root.previousIndex = root.activeIndex;
        Qt.callLater(root.ensureActiveVisible);
    }

    function ensureActiveVisible() {
        if (!root.activeItem) return;
        let maxX = Math.max(0, flick.contentWidth - flick.width);
        let target = root.activeItem.x + row.x + root.activeItem.width / 2 - flick.width / 2;
        target = Math.max(0, Math.min(maxX, target));
        if (Math.abs(target - flick.contentX) < 0.5) return;
        scrollAnim.stop();
        scrollAnim.from = flick.contentX;
        scrollAnim.to = target;
        scrollAnim.start();
    }

    onWidthChanged: Qt.callLater(root.ensureActiveVisible)
    onVisibleChanged: {
        if (visible) Qt.callLater(root.ensureActiveVisible);
    }

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: Math.max(width, row.width)
        contentHeight: height
        interactive: false
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        NumberAnimation {
            id: scrollAnim
            target: flick
            property: "contentX"
            duration: 240
            easing.type: Easing.OutCubic
        }

        Rectangle {
            id: pill

            readonly property real targetLeft: root.activeItem ? row.x + root.activeItem.x : 0
            readonly property real targetRight: root.activeItem ? targetLeft + root.activeItem.width : 0

            property real actualLeft: targetLeft
            property real actualRight: targetRight

            Behavior on actualLeft { NumberAnimation { id: leftAnim; duration: 250; easing.type: Easing.OutExpo } }
            Behavior on actualRight { NumberAnimation { id: rightAnim; duration: 250; easing.type: Easing.OutExpo } }

            x: actualLeft
            y: root.s(1)
            width: Math.max(0, actualRight - actualLeft)
            height: root.height - root.s(2)
            radius: root.s(6)
            color: ThemeBackend.liquidGlass ? "transparent" : root.accentColor

            Behavior on color { ColorAnimation { duration: 180 } }

            GlassFill {
                anchors.fill: parent
                radius: parent.radius
                tintColor: root.accentColor
                tintAmount: 0.4
                shadow: 1
                press: 0.35
            }
        }

        Row {
            id: row
            x: Math.max(0, (flick.contentWidth - width) / 2)
            height: parent.height
            spacing: root.s(2)
            z: 1

            Repeater {
                id: repeater
                model: root.categories
                onCountChanged: root.itemsRevision++
                onItemAdded: root.itemsRevision++
                onItemRemoved: root.itemsRevision++

                Item {
                    id: tab
                    required property var modelData
                    required property int index

                    readonly property bool isActive: modelData.id === root.activeId
                    readonly property bool hovered: tabMa.containsMouse

                    width: Math.max(root.s(30), contentRow.implicitWidth + root.s(16))
                    height: root.height

                    Rectangle {
                        anchors.fill: parent
                        anchors.topMargin: root.s(1)
                        anchors.bottomMargin: root.s(1)
                        radius: root.s(6)
                        color: tab.hovered && !tab.isActive ? Qt.alpha(ThemeBackend.text, 0.06) : "transparent"
                        Behavior on color { ColorAnimation { duration: 140 } }
                    }

                    Row {
                        id: contentRow
                        anchors.centerIn: parent
                        spacing: root.s(5)

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: tab.modelData.icon
                            font.family: ThemeBackend.iconFont
                            font.pixelSize: root.iconPixelSize
                            color: tab.isActive
                                ? (ThemeBackend.liquidGlass ? root.textColor : root.activeTextColor)
                                : root.textColor
                            Behavior on color { ColorAnimation { duration: 180 } }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: tab.modelData.label
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: root.fontPixelSize
                            color: tab.isActive
                                ? (ThemeBackend.liquidGlass ? root.textColor : root.activeTextColor)
                                : root.textColor
                            Behavior on color { ColorAnimation { duration: 180 } }
                        }
                    }

                    MouseArea {
                        id: tabMa
                        anchors.fill: parent
                        enabled: root.interactive
                        hoverEnabled: true
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

                        onClicked: {
                            if (tab.isActive) return;
                            root.activated(tab.modelData.id);
                            if (typeof Sounds !== "undefined") {
                                Sounds.playSfx(root.switchSound);
                            }
                        }
                    }
                }
            }
        }

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: function(event) {
                let dx = event.pixelDelta.x !== 0
                    ? event.pixelDelta.x
                    : (event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x);
                let maxX = Math.max(0, flick.contentWidth - flick.width);
                scrollAnim.stop();
                flick.contentX = Math.max(0, Math.min(maxX, flick.contentX - dx));
                event.accepted = true;
            }
        }
    }
}
