import QtQuick
import QtQuick.Layouts
import "../../"
import "../../reusables"
import "../../reusables/buttons"
import "../../reusables/inputs"

RowLayout {
    id: header
    required property var tab
    readonly property var rootObj: tab.rootObj
    readonly property bool inApp: header.tab.selectedAppClass !== "" && !header.tab.isSettingsView
    readonly property bool showNav: !header.tab.isSettingsView
    readonly property bool compact: width < rootObj.s(640)
    readonly property color iconText: ThemeBackend.liquidGlass ? "#ffffff" : (ThemeBackend.overlay0)

    Layout.fillWidth: true
    Layout.preferredHeight: rootObj.s(36)
    spacing: rootObj.s(8)

    opacity: header.tab.introHeader
    transform: Translate { y: rootObj.s(-20) * (1 - header.tab.introHeader) }

    IconButton {
        visible: header.tab.isSettingsView || header.inApp
        Layout.preferredWidth: rootObj.s(32)
        Layout.preferredHeight: rootObj.s(32)
        size: rootObj.s(32)
        cornerRadius: ThemeBackend.borderRadius
        buttonIcon: "󰁍"
        iconFontSize: rootObj.s(16)
        accentColor: ThemeBackend.surface0
        textColor: ThemeBackend.liquidGlass ? "#ffffff" : (isHoveredOrHighlighted ? ThemeBackend.text : ThemeBackend.subtext0)
        onClicked: {
            if (header.tab.isSettingsView) header.tab.isSettingsView = false;
            else header.tab.clearSelectedApp();
        }
    }

    Switch {
        id: modeSwitch
        visible: !header.tab.isSettingsView && !header.inApp
        Layout.preferredWidth: rootObj.s(150)
        Layout.preferredHeight: rootObj.s(32)
        options: [I18n.t("guide.wellbeing.day"), I18n.t("guide.wellbeing.week")]
        accentColor: ThemeBackend.accent
        textColor: ThemeBackend.subtext0
        cornerRadius: ThemeBackend.borderRadius
        baseColor: Qt.alpha(ThemeBackend.surface0, 0.6)
        fontPixelSize: rootObj.s(12)
        onToggled: function(i) { header.tab.isWeekView = i === 1; }

        Binding {
            target: modeSwitch
            property: "currentIndex"
            value: header.tab.isWeekView ? 1 : 0
        }
    }

    Image {
        visible: header.inApp && header.tab.selectedAppIcon !== ""
        source: (header.tab.selectedAppIcon && header.tab.selectedAppIcon !== "") ? (header.tab.selectedAppIcon.startsWith("/") ? "file://" + header.tab.selectedAppIcon : "image://icon/" + header.tab.selectedAppIcon) : ""
        sourceSize: Qt.size(rootObj.s(22), rootObj.s(22))
        Layout.preferredWidth: rootObj.s(22)
        Layout.preferredHeight: rootObj.s(22)
        Layout.alignment: Qt.AlignVCenter
        fillMode: Image.PreserveAspectFit
    }

    Text {
        visible: header.inApp || header.tab.isSettingsView
        Layout.alignment: Qt.AlignVCenter
        Layout.maximumWidth: header.width * 0.4
        elide: Text.ElideRight
        font.family: ThemeBackend.fontFamily
        font.weight: Font.DemiBold
        font.pixelSize: rootObj.s(16)
        color: header.tab.textMain
        text: header.tab.isSettingsView ? I18n.t("guide.wellbeing.settings.title") : header.tab.selectedAppName
    }

    Item { Layout.fillWidth: true; visible: !header.showNav }

    IconButton {
        visible: header.showNav
        Layout.preferredWidth: rootObj.s(30)
        Layout.preferredHeight: rootObj.s(30)
        size: rootObj.s(30)
        cornerRadius: ThemeBackend.borderRadius
        buttonIcon: "󰅁"
        iconFontSize: rootObj.s(15)
        accentColor: ThemeBackend.surface0
        textColor: ThemeBackend.liquidGlass ? "#ffffff" : (isHoveredOrHighlighted ? ThemeBackend.text : header.iconText)
        onClicked: header.tab.changeDay(header.tab.isWeekView && !header.inApp ? -7 : -1)
    }

    Item {
        visible: header.showNav
        Layout.fillWidth: true
        Layout.preferredHeight: rootObj.s(30)
        Layout.maximumHeight: rootObj.s(30)

        Text {
            anchors.centerIn: parent
            width: Math.max(0, parent.width - 2 * (todayButton.width + rootObj.s(8)))
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            font.family: ThemeBackend.fontFamily
            font.weight: Font.DemiBold
            font.pixelSize: rootObj.s(15)
            color: header.tab.textMain
            text: (header.tab.isWeekView && !header.inApp)
                ? (header.tab.weekRangeStr !== "" ? header.tab.weekRangeStr : I18n.t("guide.wellbeing.week_overview"))
                : header.tab.getFancyDate(header.tab.activeDate)
        }

        ClickButton {
            id: todayButton
            readonly property bool shown: !header.compact && !header.tab.isTodaySelected
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            opacity: shown ? 1.0 : 0.0
            visible: opacity > 0
            enabled: shown
            Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
            height: rootObj.s(30)
            horizontalPadding: rootObj.s(12)
            cornerRadius: ThemeBackend.borderRadius
            textFontSize: rootObj.s(12)
            accentColor: ThemeBackend.surface0
            textColor: ThemeBackend.text
            buttonText: I18n.t("guide.wellbeing.today")
            onClicked: header.tab.goToToday()
        }
    }

    IconButton {
        visible: header.showNav
        Layout.preferredWidth: rootObj.s(30)
        Layout.preferredHeight: rootObj.s(30)
        size: rootObj.s(30)
        cornerRadius: ThemeBackend.borderRadius
        buttonIcon: "󰅂"
        iconFontSize: rootObj.s(15)
        accentColor: ThemeBackend.surface0
        textColor: ThemeBackend.liquidGlass ? "#ffffff" : (isHoveredOrHighlighted ? ThemeBackend.text : header.iconText)
        onClicked: header.tab.changeDay(header.tab.isWeekView && !header.inApp ? 7 : 1)
    }

    IconButton {
        Layout.preferredWidth: rootObj.s(32)
        Layout.preferredHeight: rootObj.s(32)
        size: rootObj.s(32)
        cornerRadius: ThemeBackend.borderRadius
        buttonIcon: "󰒓"
        iconFontSize: rootObj.s(16)
        accentColor: header.tab.isSettingsView ? ThemeBackend.accent : ThemeBackend.surface0
        textColor: header.tab.isSettingsView ? ThemeBackend.crust : (ThemeBackend.liquidGlass ? "#ffffff" : (isHoveredOrHighlighted ? ThemeBackend.text : header.iconText))
        onClicked: header.tab.isSettingsView = !header.tab.isSettingsView
    }
}
