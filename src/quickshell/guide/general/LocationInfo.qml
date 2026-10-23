import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import "../../"
import "../../reusables"

Popup {
    id: locationInfoRoot
    parent: rootObj ? rootObj : undefined
    x: parent && parent.width > 0 ? Math.max(0, Math.round((parent.width - width) / 2)) : 0
    y: parent && parent.height > 0 ? Math.max(0, Math.round((parent.height - height) / 2)) : 0
    modal: true
    dim: true
    width: locationInfoRoot.s(560)
    height: locationInfoRoot.s(640)
    padding: locationInfoRoot.s(20)
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

    property var rootObj
    property var locationData: typeof Location !== "undefined" && Location.locationData ? Location.locationData : null
    property real toolbarHeight: locationInfoRoot.s(30)
    property real cr: ThemeBackend.borderRadius

    Connections {
        target: locationInfoRoot.rootObj ? locationInfoRoot.rootObj : null
        function onVisibleChanged() {
            if (locationInfoRoot.rootObj && !locationInfoRoot.rootObj.visible) {
                locationInfoRoot.close();
            }
        }
    }

    Connections {
        target: locationInfoRoot.parent && locationInfoRoot.parent !== locationInfoRoot.rootObj ? locationInfoRoot.parent : null
        function onVisibleChanged() {
            if (locationInfoRoot.parent && !locationInfoRoot.parent.visible) {
                locationInfoRoot.close();
            }
        }
    }

    function s(val) {
        if (rootObj && typeof rootObj.s === "function") {
            return rootObj.s(val);
        }
        if (typeof Scaler !== "undefined" && typeof Scaler.s === "function") {
            return Scaler.s(val);
        }
        return val;
    }

    property var locationModel: {
        let arr = [];
        if (locationData) {
            for (let key in locationData) {
                let val = locationData[key];
                if (key === "updated_at" && typeof val === "number") {
                    val = new Date(val * 1000).toLocaleString();
                }
                arr.push({ label: key, value: String(val) });
            }
        }
        return arr;
    }

    Shortcut {
        sequence: "Escape"
        enabled: locationInfoRoot.opened
        onActivated: locationInfoRoot.close()
    }

    background: Rectangle {
        radius: locationInfoRoot.cr
        color: gf1.active ? "transparent" : ThemeBackend.base

        GlassFill {
            id: gf1
            anchors.fill: parent
            radius: parent.radius
            tintColor: ThemeBackend.base
            tintAmount: 0.25
        }
        border.color: Qt.alpha(ThemeBackend.surface2, 0.6)
        border.width: 1
    }

    contentItem: ColumnLayout {
        spacing: locationInfoRoot.s(12)

        RowLayout {
            Layout.fillWidth: true
            Text {
                text: typeof I18n !== "undefined" ? I18n.t("guide.general.location.popup_title") : "Location Information"
                color: ThemeBackend.text
                font.pixelSize: locationInfoRoot.s(16)
                font.weight: Font.Bold
                Layout.fillWidth: true
            }
            CloseButton {
                Layout.preferredWidth: locationInfoRoot.toolbarHeight
                Layout.preferredHeight: locationInfoRoot.toolbarHeight
                cornerRadius: locationInfoRoot.cr
                iconFontSize: locationInfoRoot.s(14)
                onClicked: locationInfoRoot.close()
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: gf2.active ? "transparent" : Qt.alpha(ThemeBackend.surface0, 0.55)

            GlassFill {
                id: gf2
                anchors.fill: parent
                radius: parent.radius
                tintColor: Qt.alpha(ThemeBackend.surface0, 0.55)
                tintAmount: 0.25
            }
            radius: locationInfoRoot.cr
            border.width: 0

            Flickable {
                anchors.fill: parent
                anchors.margins: locationInfoRoot.s(12)
                contentWidth: width
                contentHeight: locColumn.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

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
}
