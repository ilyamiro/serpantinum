import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../"
import "../../reusables"
import "../../reusables/buttons"
import "../../reusables/inputs"

Item {
    id: picker
    required property var tab
    readonly property var rootObj: tab.rootObj
    readonly property bool active: tab.appPickerMode !== ""

    property var allApps: []
    property string query: ""
    property string selectedClass: ""

    readonly property var filteredApps: {
        let q = picker.query.trim().toLowerCase();
        let mode = tab.appPickerMode;
        return picker.allApps.filter(function(a) {
            if (tab.isAppTaken(a.class, mode)) return false;
            if (!q) return true;
            return a.name.toLowerCase().indexOf(q) !== -1 || a.comment.toLowerCase().indexOf(q) !== -1 || a.class.toLowerCase().indexOf(q) !== -1;
        });
    }

    anchors.fill: parent
    z: 50
    visible: opacity > 0.001
    opacity: active ? 1.0 : 0.0
    Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

    onActiveChanged: {
        if (active) {
            picker.allApps = picker.tab.installedAppList();
            picker.query = "";
            picker.selectedClass = "";
            searchInput.text = "";
            searchInput.forceActiveFocus();
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: picker.active
        onClicked: picker.tab.closeAppPicker()
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.alpha(ThemeBackend.crust, 0.55)
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.min(parent.width - rootObj.s(32), rootObj.s(480))
        height: Math.min(parent.height - rootObj.s(32), rootObj.s(70) + rootObj.s(48) * 6 + rootObj.s(56))
        radius: ThemeBackend.borderRadius <= 16 ? ThemeBackend.borderRadius * 1.5 : 24
        color: Qt.alpha(ThemeBackend.base, ThemeBackend.elementOpacity)
        clip: true
        scale: picker.active ? 1.0 : 0.94
        Behavior on scale { NumberAnimation { duration: 280; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }

        MouseArea { anchors.fill: parent }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: rootObj.s(12)
            spacing: rootObj.s(10)

            Input {
                id: searchInput
                Layout.fillWidth: true
                Layout.preferredHeight: rootObj.s(34)
                placeholderText: I18n.t("guide.wellbeing.settings.picker_search", "Search apps...")
                baseColor: ThemeBackend.surface0
                bgOpacity: ThemeBackend.glassActive ? 0.0 : 1.0
                accentColor: ThemeBackend.mauve
                textColor: ThemeBackend.text
                subTextColor: ThemeBackend.subtext0
                borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                cornerRadius: ThemeBackend.borderRadius
                fontPixelSize: rootObj.s(11)
                showClearButton: true
                onTextEdited: function(newText) { picker.query = newText; }
                onCleared: picker.query = ""
                Keys.onEscapePressed: function(event) {
                    picker.tab.closeAppPicker();
                    event.accepted = true;
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Qt.alpha(ThemeBackend.surface1, 0.3)
            }

            ListView {
                id: appList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: rootObj.s(4)
                boundsBehavior: Flickable.StopAtBounds
                model: picker.filteredApps

                ScrollBar.vertical: ScrollBar {
                    active: appList.moving
                    width: rootObj.s(4)
                    policy: ScrollBar.AsNeeded
                    contentItem: Rectangle { implicitWidth: rootObj.s(4); radius: rootObj.s(2); color: ThemeBackend.surface2 }
                }

                delegate: Rectangle {
                    id: row
                    required property var modelData
                    readonly property bool isSelected: picker.selectedClass === modelData.class
                    width: appList.width - rootObj.s(6)
                    height: rootObj.s(44)
                    radius: ThemeBackend.borderRadius
                    color: isSelected ? ThemeBackend.mauve : (rowMa.containsMouse ? Qt.alpha(ThemeBackend.surface1, 0.4) : Qt.alpha(ThemeBackend.surface0, 0.25))
                    Behavior on color { ColorAnimation { duration: 150 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: rootObj.s(8)
                        anchors.rightMargin: rootObj.s(8)
                        spacing: rootObj.s(8)

                        Rectangle {
                            Layout.preferredWidth: rootObj.s(28)
                            Layout.preferredHeight: rootObj.s(28)
                            Layout.alignment: Qt.AlignVCenter
                            radius: Math.round(rootObj.s(28) * 0.28)
                            color: row.isSelected ? Qt.tint(ThemeBackend.surface0, Qt.alpha(ThemeBackend.mauve, 0.2)) : ThemeBackend.surface0
                            clip: true

                            Image {
                                id: rowIcon
                                anchors.fill: parent
                                anchors.margins: rootObj.s(3)
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                mipmap: true
                                visible: status === Image.Ready
                                source: picker.tab.iconSource(row.modelData.icon)
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: rowIcon.status !== Image.Ready
                                text: row.modelData.name ? row.modelData.name.charAt(0).toUpperCase() : "?"
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: rootObj.s(12)
                                font.bold: true
                                color: row.isSelected ? ThemeBackend.mauve : ThemeBackend.text
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: rootObj.s(1)

                            Text {
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                                text: row.modelData.name
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: rootObj.s(11)
                                font.weight: row.isSelected ? Font.Bold : Font.Medium
                                color: row.isSelected ? ThemeBackend.crust : ThemeBackend.text
                            }

                            Text {
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                                text: row.modelData.comment || row.modelData.class
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: rootObj.s(9)
                                opacity: 0.85
                                color: row.isSelected ? ThemeBackend.crust : ThemeBackend.subtext0
                            }
                        }
                    }

                    MouseArea {
                        id: rowMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: picker.selectedClass = row.isSelected ? "" : row.modelData.class
                        onDoubleClicked: picker.tab.applyPickedApp(row.modelData.class)
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: picker.filteredApps.length === 0
                    text: I18n.t("guide.wellbeing.settings.picker_empty", "No matching applications")
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: rootObj.s(11)
                    color: ThemeBackend.subtext0
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: rootObj.s(8)

                ClickButton {
                    Layout.fillWidth: true
                    implicitHeight: rootObj.s(34)
                    cornerRadius: ThemeBackend.borderRadius
                    buttonText: I18n.t("guide.wellbeing.settings.picker_cancel", "Cancel")
                    accentColor: ThemeBackend.surface1
                    textColor: ThemeBackend.text
                    textFontSize: rootObj.s(11)
                    onClicked: picker.tab.closeAppPicker()
                }

                ClickButton {
                    Layout.fillWidth: true
                    implicitHeight: rootObj.s(34)
                    enabled: picker.selectedClass !== ""
                    opacity: enabled ? 1.0 : 0.5
                    cornerRadius: ThemeBackend.borderRadius
                    buttonText: I18n.t("guide.wellbeing.settings.picker_apply", "Apply")
                    accentColor: ThemeBackend.mauve
                    textColor: ThemeBackend.liquidGlass ? ThemeBackend.text : ThemeBackend.crust
                    textFontSize: rootObj.s(11)
                    onClicked: picker.tab.applyPickedApp(picker.selectedClass)
                }
            }
        }
    }
}
