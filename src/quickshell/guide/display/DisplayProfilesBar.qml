import QtQuick
import QtQuick.Layouts
import "../../"
import "../../reusables"

// Save the current layout as a named profile, or load / delete a stored one.
// Loading goes through the same confirm-or-revert transaction as any other change.
RowLayout {
    id: bar
    required property var tab
    readonly property var rootObj: tab.rootObj
    property bool naming: false
    property int pick: 0
    readonly property string picked: tab.profileNames.length > 0 ? tab.profileNames[Math.min(bar.pick, tab.profileNames.length - 1)] : ""

    Layout.fillWidth: true
    spacing: rootObj.s(8)

    function commit() {
        if (tab.profileSave(nameInput.text)) { nameInput.text = ""; naming = false; }
    }

    Input {
        id: nameInput
        visible: bar.naming
        Layout.fillWidth: true
        implicitHeight: rootObj.s(32)
        placeholderText: I18n.t("guide.display.profiles.name_placeholder")
        maximumLength: 40
        cornerRadius: ThemeBackend.borderRadius
        accentColor: ThemeBackend.mauve
        onAccepted: bar.commit()
    }

    Item { visible: !bar.naming; Layout.fillWidth: true }

    Dropdown {
        visible: !bar.naming && tab.profileNames.length > 0
        implicitWidth: rootObj.s(170)
        implicitHeight: rootObj.s(32)
        fuzzySearch: false
        options: tab.profileNames
        currentIndex: Math.min(bar.pick, Math.max(0, tab.profileNames.length - 1))
        accentColor: ThemeBackend.mauve
        baseColor: ThemeBackend.surface0
        hoverColor: ThemeBackend.surface1
        dropdownColor: ThemeBackend.surface0
        onSelected: function(index, value) { bar.pick = index }
    }

    ClickButton {
        visible: !bar.naming && tab.profileNames.length > 0
        enabled: !tab.txnBusy && !tab.txnPending
        implicitHeight: rootObj.s(32)
        cornerRadius: ThemeBackend.borderRadius
        horizontalPadding: rootObj.s(14)
        buttonText: I18n.t("guide.display.profiles.load")
        buttonIcon: "󰇚"
        iconFontSize: rootObj.s(14)
        textFontSize: rootObj.s(12)
        accentColor: ThemeBackend.surface1
        onClicked: tab.profileLoad(bar.picked)
    }

    ClickButton {
        visible: !bar.naming && tab.profileNames.length > 0
        implicitHeight: rootObj.s(32)
        cornerRadius: ThemeBackend.borderRadius
        horizontalPadding: rootObj.s(14)
        buttonText: I18n.t("guide.display.profiles.delete")
        buttonIcon: "󰆴"
        iconFontSize: rootObj.s(14)
        textFontSize: rootObj.s(12)
        accentColor: ThemeBackend.surface1
        onClicked: tab.profileDelete(bar.picked)
    }

    ClickButton {
        visible: bar.naming
        implicitHeight: rootObj.s(32)
        cornerRadius: ThemeBackend.borderRadius
        horizontalPadding: rootObj.s(14)
        buttonText: I18n.t("guide.display.map.discard")
        buttonIcon: "󰜺"
        iconFontSize: rootObj.s(14)
        textFontSize: rootObj.s(12)
        accentColor: ThemeBackend.surface1
        onClicked: { nameInput.text = ""; bar.naming = false }
    }

    ClickButton {
        implicitHeight: rootObj.s(32)
        cornerRadius: ThemeBackend.borderRadius
        horizontalPadding: rootObj.s(14)
        buttonText: I18n.t("guide.display.profiles.save")
        buttonIcon: "󰆓"
        iconFontSize: rootObj.s(14)
        textFontSize: rootObj.s(12)
        accentColor: ThemeBackend.mauve
        textColor: ThemeBackend.base
        onClicked: bar.naming ? bar.commit() : (bar.naming = true)
    }
}
