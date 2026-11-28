import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../"
import "../../reusables"

GuideModal {
    id: locationInfoRoot

    title: typeof I18n !== "undefined" ? I18n.t("guide.general.location.popup_title", "Location information") : "Location information"
    preferredWidth: s(560)
    height: s(640)
    padding: s(20)
    cornerRadius: ThemeBackend.borderRadius
    contentSpacing: s(12)

    readonly property var locationModel: (typeof Location !== "undefined" && Location.entries) ? Location.entries : []

    Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        color: gf2.active ? "transparent" : Qt.alpha(ThemeBackend.surface0, 0.55)
        radius: ThemeBackend.borderRadius

        GlassFill {
            id: gf2
            anchors.fill: parent
            radius: parent.radius
            tintColor: Qt.alpha(ThemeBackend.surface0, 0.55)
            tintAmount: 0.25
        }

        Flickable {
            anchors.fill: parent
            anchors.margins: locationInfoRoot.s(12)
            contentWidth: width
            contentHeight: locColumn.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ScrollBar.vertical: StyledScrollBar {
                rootObj: locationInfoRoot.rootObj
            }

            ColumnLayout {
                id: locColumn
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: 0

                Repeater {
                    id: locRepeater
                    model: locationInfoRoot.locationModel

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: locationInfoRoot.s(44)
                            Layout.leftMargin: locationInfoRoot.s(14)
                            Layout.rightMargin: locationInfoRoot.s(14)
                            spacing: locationInfoRoot.s(12)

                            Text {
                                text: modelData.label
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: locationInfoRoot.s(12)
                                color: ThemeBackend.text
                                Layout.preferredWidth: locationInfoRoot.s(140)
                                elide: Text.ElideRight
                            }

                            Text {
                                text: modelData.value
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: locationInfoRoot.s(12)
                                color: ThemeBackend.subtext0
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignRight
                                elide: Text.ElideRight
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.leftMargin: locationInfoRoot.s(14)
                            Layout.rightMargin: locationInfoRoot.s(14)
                            Layout.preferredHeight: 1
                            color: Qt.alpha(ThemeBackend.surface1, 0.4)
                            visible: index < locRepeater.count - 1
                        }
                    }
                }
            }
        }
    }
}
