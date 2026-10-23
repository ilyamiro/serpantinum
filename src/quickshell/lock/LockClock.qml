import QtQuick
import QtQuick.Layouts
import "../"
import "redactor"

Item {
    id: clockModule
    required property var screenRoot

    property var currentTime: new Date()
    readonly property bool concealed: screenRoot.inputActive || screenRoot.centerReveal > 0.02
    readonly property real fit: Math.min(width / LockLayoutStore.refW, height / LockLayoutStore.refH)

    anchors.fill: parent
    opacity: clockModule.concealed ? 0.0 : 1.0
    scale: clockModule.concealed ? 0.92 : 1.0
    visible: opacity > 0.01

    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

    Item {
        width: LockLayoutStore.refW
        height: LockLayoutStore.refH
        anchors.centerIn: parent
        scale: clockModule.fit

        LockLayoutView {
            anchors.fill: parent
            scope: "screen"
            ctx: clockModule.screenRoot
        }

        Rectangle {
            id: clockQuotePill
            anchors.horizontalCenter: parent.horizontalCenter
            y: {
                let clockItem = null;
                for (let i = 0; i < LockLayoutStore.screenItems.count; i++) {
                    let item = LockLayoutStore.screenItems.get(i);
                    if (item.itype === "clock") {
                        clockItem = item;
                        break;
                    }
                }
                if (clockItem) {
                    return clockItem.iy + clockItem.ih + 15;
                }
                return LockLayoutStore.refH * 0.36 + 115;
            }
            visible: screenRoot.quoteEnabled && screenRoot.quoteText !== "" && (screenRoot.quoteLockPosition === "both" || screenRoot.quoteLockPosition === "clock")
            implicitWidth: Math.min(LockLayoutStore.refW - 40, clockQuoteRow.implicitWidth + 36)
            implicitHeight: clockQuoteRow.implicitHeight + 16
            width: implicitWidth
            height: implicitHeight
            radius: (implicitHeight > 0) ? implicitHeight / 2 : 16
            color: (typeof ThemeBackend !== "undefined" && ThemeBackend.surface0) ? Qt.alpha(ThemeBackend.surface0, 0.75) : Qt.rgba(0.19, 0.20, 0.27, 0.75)
            border.width: 1
            border.color: (typeof ThemeBackend !== "undefined" && ThemeBackend.surface1) ? Qt.alpha(ThemeBackend.surface1, 0.8) : Qt.rgba(0.27, 0.28, 0.35, 0.8)

            RowLayout {
                id: clockQuoteRow
                anchors.centerIn: parent
                spacing: 10
                width: Math.min(clockQuotePill.width - 32, implicitWidth)

                Text {
                    text: "󰝗"
                    font.family: "Iosevka Nerd Font"
                    font.pixelSize: 22
                    color: ThemeBackend.mauve
                    Layout.alignment: Qt.AlignVCenter
                }

                Text {
                    Layout.fillWidth: true
                    text: screenRoot.quoteText
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: 17
                    font.weight: Font.Normal
                    font.italic: true
                    color: "#ffffff"
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }
    }
}
