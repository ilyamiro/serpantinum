import QtQuick
import QtQuick.Layouts
import "../../"
import "../../reusables"

RowLayout {
    id: header
    required property var tab
    readonly property var rootObj: tab.rootObj
    Layout.fillWidth: true
    Layout.preferredHeight: rootObj.s(36)

    opacity: header.tab.introHeader
    transform: Translate { y: rootObj.s(-20) * (1 - header.tab.introHeader) }

    RowLayout {
        Layout.alignment: Qt.AlignVCenter
        spacing: rootObj.s(4)

        IconButton {
            Layout.preferredWidth: rootObj.s(32)
            Layout.preferredHeight: rootObj.s(32)
            size: rootObj.s(32)
            cornerRadius: ThemeBackend.borderRadius
            buttonIcon: "󰒓"
            iconFontSize: rootObj.s(16)
            accentColor: ThemeBackend.surface0
            textColor: ThemeBackend.liquidGlass ? "#ffffff" : (isHoveredOrHighlighted ? ThemeBackend.text : ThemeBackend.overlay0)
            onClicked: header.tab.isSettingsView = !header.tab.isSettingsView
        }

        Item {
            Layout.preferredWidth: rootObj.s(32)
            Layout.preferredHeight: rootObj.s(32)

            IconButton {
                anchors.fill: parent
                size: rootObj.s(32)
                cornerRadius: ThemeBackend.borderRadius
                buttonIcon: "󰁍"
                iconFontSize: rootObj.s(16)
                accentColor: ThemeBackend.surface0
                textColor: ThemeBackend.liquidGlass ? "#ffffff" : (isHoveredOrHighlighted ? ThemeBackend.text : ThemeBackend.overlay0)
                opacity: (header.tab.selectedAppClass !== "" || header.tab.isWeekView || header.tab.isSettingsView) ? 1.0 : 0.0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 350; easing.type: Easing.OutQuint } }
                onClicked: {
                    if (header.tab.isSettingsView) {
                        header.tab.isSettingsView = false;
                    } else if (header.tab.selectedAppClass !== "") {
                        header.tab.selectedAppClass = "";
                        header.tab.selectedAppName = "";
                        header.tab.selectedAppIcon = "";
                        header.tab.requestDataUpdate();
                    } else if (header.tab.isWeekView) {
                        header.tab.isWeekView = false;
                    }
                }
            }

            IconButton {
                anchors.fill: parent
                size: rootObj.s(32)
                cornerRadius: ThemeBackend.borderRadius
                buttonIcon: "󰃭"
                iconFontSize: rootObj.s(16)
                accentColor: ThemeBackend.surface0
                textColor: ThemeBackend.liquidGlass ? "#ffffff" : (isHoveredOrHighlighted ? ThemeBackend.text : ThemeBackend.overlay0)
                opacity: (header.tab.selectedAppClass === "" && !header.tab.isWeekView && !header.tab.isSettingsView) ? 1.0 : 0.0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 350; easing.type: Easing.OutQuint } }
                onClicked: header.tab.isWeekView = true
            }
        }

        IconButton {
            Layout.preferredWidth: rootObj.s(32)
            Layout.preferredHeight: rootObj.s(32)
            size: rootObj.s(32)
            cornerRadius: ThemeBackend.borderRadius
            buttonIcon: "󰅁"
            iconFontSize: rootObj.s(16)
            accentColor: ThemeBackend.surface0
            textColor: ThemeBackend.liquidGlass ? "#ffffff" : (isHoveredOrHighlighted ? ThemeBackend.text : ThemeBackend.overlay0)
            onClicked: header.tab.changeDay(header.tab.isWeekView ? -7 : -1)
            opacity: header.tab.isSettingsView ? 0.0 : 1.0
            visible: opacity > 0
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignHCenter
        spacing: rootObj.s(8)

        Item { Layout.fillWidth: true }

        Image {
            property bool active: header.tab.selectedAppClass !== "" && header.tab.selectedAppIcon !== "" && !header.tab.isWeekView && !header.tab.isSettingsView
            property real animWidth: active ? rootObj.s(20) : 0
            Behavior on animWidth { NumberAnimation { duration: 350; easing.type: Easing.OutQuint } }

            source: (header.tab.selectedAppIcon && header.tab.selectedAppIcon !== "") ? (header.tab.selectedAppIcon.startsWith("/") ? "file://" + header.tab.selectedAppIcon : "image://icon/" + header.tab.selectedAppIcon) : ""
            sourceSize: Qt.size(rootObj.s(20), rootObj.s(20))
            Layout.preferredWidth: animWidth
            Layout.preferredHeight: rootObj.s(20)
            Layout.alignment: Qt.AlignVCenter
            Layout.rightMargin: active ? rootObj.s(6) : 0
            opacity: animWidth / rootObj.s(20.0)
            visible: animWidth > 0
            fillMode: Image.PreserveAspectFit
            clip: true
        }

        Text {
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            font.family: ThemeBackend.fontFamily
            font.weight: Font.DemiBold
            font.pixelSize: rootObj.s(17)
            color: header.tab.textMain
            text: header.tab.isSettingsView ? I18n.t("guide.wellbeing.settings.title") : (header.tab.isWeekView ? (header.tab.weekRangeStr !== "" ? header.tab.weekRangeStr : I18n.t("guide.wellbeing.week_overview")) : (header.tab.selectedAppClass !== "" ? `${header.tab.selectedAppName} - ${header.tab.getFancyDate(header.tab.activeDate)}` : header.tab.getFancyDate(header.tab.activeDate)))
        }

        Item { Layout.fillWidth: true }
    }

    RowLayout {
        Layout.alignment: Qt.AlignVCenter
        spacing: rootObj.s(4)

        IconButton {
            Layout.preferredWidth: rootObj.s(32)
            Layout.preferredHeight: rootObj.s(32)
            size: rootObj.s(32)
            cornerRadius: ThemeBackend.borderRadius
            buttonIcon: "󰅂"
            iconFontSize: rootObj.s(16)
            accentColor: ThemeBackend.surface0
            textColor: ThemeBackend.liquidGlass ? "#ffffff" : (isHoveredOrHighlighted ? ThemeBackend.text : ThemeBackend.overlay0)
            onClicked: header.tab.changeDay(header.tab.isWeekView ? 7 : 1)
            opacity: header.tab.isSettingsView ? 0.0 : 1.0
            visible: opacity > 0
        }
    }
}
