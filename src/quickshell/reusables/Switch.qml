import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../"

Item {
    id: root
    implicitWidth: 120
    implicitHeight: 32

    property var options: ["x", "y"]
    property int currentIndex: 0

    property color accentColor: "#89b4fa"
    property color baseColor: "#1affffff"
    property color textColor: "#cdd6f4"
    property color activeTextColor: "#11111b"

    property int cornerRadius: 8
    property int smallRadius: 2
    property int fontPixelSize: 11
    property int minFontPixelSize: 7
    property bool enabled: true
    property string switchSound: "reusables/switch/sfx.wav"

    signal valueChanged(int index, string value)
    signal toggled(int index)
    signal clicked()

    property real flashOpacity: 0.0
    property real popScale: 1.0

    Rectangle {
        id: bgShape
        anchors.fill: parent
        radius: root.cornerRadius
        color: root.baseColor
        border.color: "#1affffff"
        border.width: 1
        clip: true
        opacity: root.enabled ? 1.0 : 0.5

        Behavior on color { ColorAnimation { duration: 180 } }
        Behavior on opacity { NumberAnimation { duration: 180 } }

        scale: root.popScale
        Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }

        Rectangle {
            id: activeTabHighlight
            property int prevIdx: 0
            property int curIdx: root.currentIndex

            onCurIdxChanged: {
                if (curIdx > prevIdx) { rightAnim.duration = 200; leftAnim.duration = 350; }
                else if (curIdx < prevIdx) { leftAnim.duration = 200; rightAnim.duration = 350; }
                prevIdx = curIdx;
            }

            property real itemWidth: bgShape.width / Math.max(1, root.options.length)
            property real targetLeft: root.currentIndex * itemWidth
            property real targetRight: (root.currentIndex + 1) * itemWidth

            property real actualLeft: targetLeft
            property real actualRight: targetRight

            Behavior on actualLeft { NumberAnimation { id: leftAnim; duration: 250; easing.type: Easing.OutExpo } }
            Behavior on actualRight { NumberAnimation { id: rightAnim; duration: 250; easing.type: Easing.OutExpo } }

            y: 0
            height: bgShape.height
            x: actualLeft
            width: Math.max(0, actualRight - actualLeft)
            z: 0

            topLeftRadius: root.currentIndex === 0 ? root.cornerRadius : root.smallRadius
            bottomLeftRadius: root.currentIndex === 0 ? root.cornerRadius : root.smallRadius
            topRightRadius: root.currentIndex === root.options.length - 1 ? root.cornerRadius : root.smallRadius
            bottomRightRadius: root.currentIndex === root.options.length - 1 ? root.cornerRadius : root.smallRadius

            Behavior on topLeftRadius { NumberAnimation { duration: 180 } }
            Behavior on bottomLeftRadius { NumberAnimation { duration: 180 } }
            Behavior on topRightRadius { NumberAnimation { duration: 180 } }
            Behavior on bottomRightRadius { NumberAnimation { duration: 180 } }

            color: root.accentColor

            Behavior on color { ColorAnimation { duration: 180 } }
        }

        RowLayout {
            id: tabsLayout
            anchors.fill: parent
            spacing: 0
            z: 1

            Repeater {
                model: root.options

                Item {
                    id: optionItem
                    required property string modelData
                    required property int index

                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Rectangle {
                        anchors.fill: parent
                        topLeftRadius: optionItem.index === 0 ? root.cornerRadius : root.smallRadius
                        bottomLeftRadius: optionItem.index === 0 ? root.cornerRadius : root.smallRadius
                        topRightRadius: optionItem.index === root.options.length - 1 ? root.cornerRadius : root.smallRadius
                        bottomRightRadius: optionItem.index === root.options.length - 1 ? root.cornerRadius : root.smallRadius
                        color: root.currentIndex === optionItem.index ? "transparent" : (optionMa.containsMouse ? "#1affffff" : "transparent")
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }

                    Text {
                        anchors.fill: parent
                        anchors.leftMargin: 4
                        anchors.rightMargin: 4
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: optionItem.modelData
                        font.family: ThemeBackend.fontFamily
                        font.weight: Font.Normal
                        font.pixelSize: root.fontPixelSize
                        fontSizeMode: Text.Fit
                        minimumPixelSize: root.minFontPixelSize
                        color: root.currentIndex === optionItem.index ? root.activeTextColor : root.textColor
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }

                    MouseArea {
                        id: optionMa
                        anchors.fill: parent
                        enabled: root.enabled
                        hoverEnabled: true
                        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

                        onClicked: {
                            if (!root.enabled) return;
                            if (root.currentIndex !== optionItem.index) {
                                root.currentIndex = optionItem.index;
                                root.valueChanged(optionItem.index, optionItem.modelData);
                                root.toggled(optionItem.index);
                            }
                            btnPopAnim.start();
                            root.flashOpacity = 0.2;
                            btnFlashAnim.start();
                            if (typeof Sounds !== "undefined") {
                                Sounds.playSfx(root.switchSound);
                            }
                            root.clicked();
                        }
                    }
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: root.cornerRadius
            color: "#ffffff"
            opacity: root.flashOpacity
            z: 2
            PropertyAnimation on opacity { id: btnFlashAnim; to: 0; duration: 350; easing.type: Easing.OutExpo }
        }
    }

    SequentialAnimation {
        id: btnPopAnim
        NumberAnimation { target: root; property: "popScale"; to: 1.04; duration: 100; easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "popScale"; to: 1.0; duration: 350; easing.type: Easing.OutQuint }
    }
}
