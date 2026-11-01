import QtQuick
import QtQuick.Layouts
import "../../"
import "../../reusables"
import "../../reusables/guide"

SettingsRow {
    id: row
    required property var tab
    property alias screenSelector: screenSelector
    property alias posDropdown: posDropdown

    rootObj: row.tab.rootObj
    icon: "󰍹"
    title: I18n.t("guide.notifications.position.title", "Screen position")
    titleBold: true
    description: I18n.t("guide.notifications.position.desc", "Select a preset position or drag on screen")
    innerSpacing: (row.tab.selectorOpen || selectorWrapper.implicitHeight > 0) ? rootObj.s(12) : 0
    bottomSpacing: 0

    ClickButton {
        implicitHeight: rootObj.s(32)
        horizontalPadding: rootObj.s(12)
        buttonText: row.tab.selectorOpen ? I18n.t("guide.notifications.position.close_selector", "Close the selector") : I18n.t("guide.notifications.position.select_on_screen", "Select on screen...")
        buttonIcon: row.tab.selectorOpen ? "󰅖" : "󰍹"
        iconFontSize: rootObj.s(13)
        textFontSize: rootObj.s(11)
        accentColor: row.tab.selectorOpen ? ThemeBackend.accent : ThemeBackend.surface0
        textColor: row.tab.selectorOpen ? ThemeBackend.crust : ThemeBackend.text
        cornerRadius: ThemeBackend.borderRadius
        onClicked: {
            row.tab.selectorOpen = !row.tab.selectorOpen;
        }
    }

    Rectangle {
        id: notifCustomPosBox
        Layout.alignment: Qt.AlignVCenter
        implicitHeight: rootObj.s(32)
        implicitWidth: row.tab.isCustomPos ? (notifCustomPosText.implicitWidth + rootObj.s(20)) : 0
        radius: ThemeBackend.borderRadius
        color: gf1.active ? "transparent" : ThemeBackend.surface0

        GlassFill {
            id: gf1
            anchors.fill: parent
            radius: parent.radius
            tintColor: ThemeBackend.surface0
            tintAmount: 0.25
        }
        clip: true
        opacity: row.tab.isCustomPos ? 1.0 : 0.0
        visible: opacity > 0.001

        Behavior on implicitWidth { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

        Text {
            id: notifCustomPosText
            anchors.centerIn: parent
            text: I18n.t("guide.position.custom", "Custom") + " (" + row.tab.horizontalPosition + "%, " + row.tab.verticalPosition + "%)"
            font.family: ThemeBackend.fontFamily
            font.pixelSize: rootObj.s(11)
            font.bold: true
            color: "#ffffff"
        }
    }

    Dropdown {
        id: posDropdown
        Layout.alignment: Qt.AlignVCenter
        Layout.preferredWidth: rootObj.s(180)
        Layout.preferredHeight: rootObj.s(32)
        options: [
            I18n.t("guide.notifications.position.top_right", "Top Right"),
            I18n.t("guide.notifications.position.top_center", "Top Center"),
            I18n.t("guide.notifications.position.top_left", "Top Left"),
            I18n.t("guide.notifications.position.bottom_right", "Bottom Right"),
            I18n.t("guide.notifications.position.bottom_center", "Bottom Center"),
            I18n.t("guide.notifications.position.bottom_left", "Bottom Left")
        ]
        currentIndex: {
            if (row.tab.isCustomPos) return -1;
            if (row.tab.position === "top right") return 0;
            if (row.tab.position === "top center") return 1;
            if (row.tab.position === "top left") return 2;
            if (row.tab.position === "bottom right") return 3;
            if (row.tab.position === "bottom center") return 4;
            if (row.tab.position === "bottom left") return 5;
            return row.tab.getPresetIndex(row.tab.horizontalPosition, row.tab.verticalPosition);
        }
        accentColor: ThemeBackend.accent
        baseColor: ThemeBackend.surface0
        hoverColor: ThemeBackend.surface1
        dropdownColor: ThemeBackend.surface0
        borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
        textColor: ThemeBackend.text
        activeTextColor: ThemeBackend.crust
        cornerRadius: ThemeBackend.borderRadius
        fontPixelSize: rootObj.s(11)
        onValueChanged: function(index, value) {
            row.tab.setPosFromIndex(index);
        }
        onSelected: function(index, value) {
            row.tab.setPosFromIndex(index);
        }
    }

    Binding {
        target: posDropdown
        property: "currentIndex"
        value: {
            if (row.tab.isCustomPos) return -1;
            if (row.tab.position === "top right") return 0;
            if (row.tab.position === "top center") return 1;
            if (row.tab.position === "top left") return 2;
            if (row.tab.position === "bottom right") return 3;
            if (row.tab.position === "bottom center") return 4;
            if (row.tab.position === "bottom left") return 5;
            return row.tab.getPresetIndex(row.tab.horizontalPosition, row.tab.verticalPosition);
        }
    }

    bottomContent: [
        Item {
            id: selectorWrapper
            Layout.fillWidth: true
            property bool isOpen: row.tab.selectorOpen
            clip: true
            visible: implicitHeight > 0
            opacity: isOpen ? 1.0 : 0.0
            property real openProgress: isOpen ? 1 : 0
            implicitHeight: selectorBox.implicitHeight * openProgress

            Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
            Behavior on openProgress { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

            Rectangle {
                id: selectorBox
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: implicitHeight
                implicitHeight: selectorInnerCol.implicitHeight + rootObj.s(24)
                radius: ThemeBackend.borderRadius
                color: gf2.active ? "transparent" : Qt.alpha(ThemeBackend.surface1, 0.35)

                GlassFill {
                    id: gf2
                    anchors.fill: parent
                    radius: parent.radius
                    tintColor: Qt.alpha(ThemeBackend.surface1, 0.35)
                    tintAmount: 0.25
                }

                ColumnLayout {
                    id: selectorInnerCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: rootObj.s(12)
                    spacing: rootObj.s(10)

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: rootObj.s(6)

                        ClickButton {
                            enabled: false
                            Layout.preferredWidth: rootObj.s(140)
                            implicitHeight: rootObj.s(26)
                            cornerRadius: rootObj.s(6)
                            horizontalPadding: rootObj.s(6)
                            textFontSize: rootObj.s(11)
                            accentColor: ThemeBackend.surface1
                            textColor: "#ffffff"
                            buttonText: "X: " + row.tab.horizontalPosition + "%  Y: " + row.tab.verticalPosition + "%"
                        }

                        IconButton {
                            size: rootObj.s(26)
                            cornerRadius: rootObj.s(6)
                            buttonIcon: "󰕰"
                            iconFontSize: rootObj.s(13)
                            accentColor: row.tab.gridEnabled ? ThemeBackend.accent : ThemeBackend.surface1
                            textColor: row.tab.gridEnabled ? ThemeBackend.crust : ThemeBackend.text
                            onClicked: {
                                row.tab.gridEnabled = !row.tab.gridEnabled;
                            }
                        }

                        IconButton {
                            size: rootObj.s(26)
                            cornerRadius: rootObj.s(6)
                            buttonIcon: "󰑐"
                            iconFontSize: rootObj.s(13)
                            accentColor: ThemeBackend.surface1
                            textColor: ThemeBackend.text
                            onClicked: {
                                row.tab.applyPosition(row.tab.presetRightH, row.tab.presetTopV, "top right");
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        RowLayout {
                            spacing: rootObj.s(8)
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter

                            Text {
                                text: I18n.t("guide.common.show_bar", "Show bar")
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: rootObj.s(11)
                                color: ThemeBackend.subtext0
                            }

                            Toggle {
                                checked: row.tab.showBarBox
                                accentColor: ThemeBackend.accent
                                baseColor: ThemeBackend.surface1
                                handleColor: ThemeBackend.crust
                                handleOffColor: ThemeBackend.text
                                onToggled: function(c) {
                                    row.tab.showBarBox = c;
                                }
                            }
                        }
                    }

                    ScreenPositionSelector {
                        id: screenSelector
                        Layout.fillWidth: true
                        horizontalPosition: row.tab.horizontalPosition
                        verticalPosition: row.tab.verticalPosition
                        gridEnabled: row.tab.gridEnabled
                        showBar: row.tab.showBarBox
                        marginV: rootObj.s(12)
                        marginH: rootObj.s(16)
                        dragWidth: rootObj.s(170)
                        dragHeight: rootObj.s(48)

                        onPositionChanged: (hPos, vPos) => {
                            let h = Math.round(hPos);
                            let v = Math.round(vPos);
                            row.tab.horizontalPosition = h;
                            row.tab.verticalPosition = v;
                            let idx = row.tab.getPresetIndex(h, v);
                            row.tab.position = idx !== -1 ? row.tab.getPosStringFromIndex(idx) : "custom";
                            row.tab.debounceTimer.restart();
                        }

                        onDragFinished: {
                            row.tab.debounceTimer.stop();
                            let idx = row.tab.getPresetIndex(row.tab.horizontalPosition, row.tab.verticalPosition);
                            let posStr = idx !== -1 ? row.tab.getPosStringFromIndex(idx) : "custom";
                            row.tab.position = posStr;
                            let current = JSON.parse(JSON.stringify(Config.getSetting("notifications", row.tab.defaultNotificationSettings) || row.tab.defaultNotificationSettings));
                            current.horizontalPosition = row.tab.horizontalPosition;
                            current.verticalPosition = row.tab.verticalPosition;
                            current.position = posStr;
                            Config.setSetting("notifications", current);
                            row.tab.notifSettings = current;
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: rootObj.s(8)
                            color: notifPreviewGlass.active ? "transparent" : ThemeBackend.base
                            clip: true

                            GlassFill {
                                id: notifPreviewGlass
                                anchors.fill: parent
                                radius: parent.radius
                                tintColor: ThemeBackend.base
                                tintAmount: 0.35
                                shadow: 1
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: rootObj.s(6)
                                spacing: rootObj.s(8)

                                Rectangle {
                                    Layout.preferredWidth: parent.height
                                    Layout.preferredHeight: parent.height
                                    Layout.alignment: Qt.AlignVCenter
                                    radius: rootObj.s(6)
                                    color: notifIconGlass.active ? "transparent" : ThemeBackend.surface1

                                    GlassFill {
                                        id: notifIconGlass
                                        anchors.fill: parent
                                        radius: parent.radius
                                        tintColor: ThemeBackend.surface1
                                        tintAmount: 0.3
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰂚"
                                        font.family: ThemeBackend.iconFont
                                        font.pixelSize: rootObj.s(16)
                                        color: ThemeBackend.accent
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: rootObj.s(4)

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.maximumWidth: rootObj.s(80)
                                        height: rootObj.s(6)
                                        radius: rootObj.s(3)
                                        color: ThemeBackend.text
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.maximumWidth: rootObj.s(110)
                                        height: rootObj.s(5)
                                        radius: rootObj.s(2.5)
                                        color: ThemeBackend.subtext0
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    ]
}
