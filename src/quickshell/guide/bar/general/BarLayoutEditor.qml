import QtQuick
import QtQuick.Layouts
import "../../../"
import "../../../reusables"

Rectangle {
    id: editor
    required property var tab
    readonly property var rootObj: tab.rootObj

    Layout.fillWidth: true
    implicitHeight: barConfigCol.implicitHeight + rootObj.s(24)
    radius: ThemeBackend.borderRadius
    color: gf1.active ? "transparent" : Qt.alpha(ThemeBackend.surface0, 0.4)

    GlassFill {
        id: gf1
        anchors.fill: parent
        radius: parent.radius
        tintColor: Qt.alpha(ThemeBackend.surface0, 0.4)
        tintAmount: 0.25
    }

    ColumnLayout {
        id: barConfigCol
        anchors.fill: parent
        anchors.margins: rootObj.s(12)
        spacing: rootObj.s(14)

        RowLayout {
            Layout.fillWidth: true
            spacing: rootObj.s(12)

            IconButton {
                enabled: false
                size: rootObj.s(32)
                Layout.preferredWidth: rootObj.s(32)
                Layout.preferredHeight: rootObj.s(32)
                Layout.alignment: Qt.AlignVCenter
                cornerRadius: ThemeBackend.borderRadius
                buttonIcon: "󰒓"
                iconFontSize: rootObj.s(16)
                accentColor: ThemeBackend.surface0
                textColor: "#ffffff"
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: rootObj.s(2)
                Text {
                    Layout.fillWidth: true
                    text: I18n.t("guide.bar.config.title")
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: rootObj.s(13)
                    color: ThemeBackend.text
                }
                Text {
                    text: I18n.t("guide.bar.config.desc")
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: rootObj.s(11)
                    color: ThemeBackend.subtext0
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                }
            }

            ClickButton {
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                implicitHeight: rootObj.s(32)
                buttonText: I18n.t("guide.bar.config.reset")
                buttonIcon: "↺"
                accentColor: ThemeBackend.surface0
                textColor: ThemeBackend.text
                cornerRadius: ThemeBackend.borderRadius
                horizontalPadding: rootObj.s(12)
                textFontSize: rootObj.s(11)
                onClicked: function() {
                    editor.tab.resetBarSettings();
                }
            }
        }

        BarDragBox {
            tab: editor.tab
            listModel: editor.tab.availableModel
            lName: "available"
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.minimumHeight: rootObj.s(130)
            spacing: rootObj.s(16)

            BarDragBox {
                tab: editor.tab
                listModel: editor.tab.leftModel
                lName: "left"
            }

            BarDragBox {
                tab: editor.tab
                listModel: editor.tab.centerModel
                lName: "center"
            }

            BarDragBox {
                tab: editor.tab
                listModel: editor.tab.rightModel
                lName: "right"
            }
        }
    }
}
