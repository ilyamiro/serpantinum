import QtQuick
import QtQuick.Layouts
import "../../"
import "../../reusables"

// Action row under the arrangement map, spread over its full width:
//   normal:        [profile ▾] [Load] [Delete] [Save profile] [Refresh]
//   naming:        [name field ............] [Cancel] [Save profile]
//   layout draft:  [Discard] [Apply changes] [Refresh]
// Loading a profile goes through the same confirm-or-revert transaction as any other change.
RowLayout {
    id: bar
    required property var tab
    readonly property var rootObj: tab.rootObj
    property bool naming: false
    property int pick: 0
    readonly property bool hasProfiles: tab.profileNames.length > 0
    readonly property bool dirty: tab.layoutDirty
    readonly property bool showProfiles: !naming && !dirty
    readonly property string picked: hasProfiles ? tab.profileNames[Math.min(bar.pick, tab.profileNames.length - 1)] : ""

    Layout.fillWidth: true
    spacing: rootObj.s(10)

    function commit() {
        if (tab.profileSave(nameInput.text)) { nameInput.text = ""; naming = false; }
    }

    Input {
        id: nameInput
        visible: bar.naming && !bar.dirty
        Layout.fillWidth: true
        Layout.preferredWidth: 3
        implicitHeight: rootObj.s(32)
        placeholderText: I18n.t("guide.display.profiles.name_placeholder")
        maximumLength: 40
        cornerRadius: ThemeBackend.borderRadius
        accentColor: ThemeBackend.mauve
        onAccepted: bar.commit()
    }

    Dropdown {
        visible: bar.showProfiles && bar.hasProfiles
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        Layout.minimumWidth: rootObj.s(140)
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
        visible: bar.showProfiles && bar.hasProfiles
        enabled: !tab.txnBusy && !tab.txnPending
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        Layout.minimumWidth: implicitWidth
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
        visible: bar.showProfiles && bar.hasProfiles
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        Layout.minimumWidth: implicitWidth
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

    // Cancel naming, or discard the layout draft.
    ClickButton {
        visible: bar.naming || bar.dirty
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        Layout.minimumWidth: implicitWidth
        implicitHeight: rootObj.s(32)
        cornerRadius: ThemeBackend.borderRadius
        horizontalPadding: rootObj.s(14)
        buttonText: I18n.t("guide.display.map.discard")
        buttonIcon: "󰜺"
        iconFontSize: rootObj.s(14)
        textFontSize: rootObj.s(12)
        accentColor: ThemeBackend.surface1
        onClicked: {
            if (bar.dirty) { tab.layoutDiscard(); return; }
            nameInput.text = "";
            bar.naming = false;
        }
    }

    ClickButton {
        visible: !bar.dirty
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        Layout.minimumWidth: implicitWidth
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

    ClickButton {
        visible: bar.dirty
        enabled: !tab.txnBusy && !tab.txnPending
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        Layout.minimumWidth: implicitWidth
        implicitHeight: rootObj.s(32)
        cornerRadius: ThemeBackend.borderRadius
        horizontalPadding: rootObj.s(14)
        buttonText: I18n.t("guide.display.map.apply")
        buttonIcon: "󰄬"
        iconFontSize: rootObj.s(14)
        textFontSize: rootObj.s(12)
        accentColor: ThemeBackend.mauve
        textColor: ThemeBackend.base
        onClicked: tab.layoutApply()
    }

    ClickButton {
        visible: !bar.naming
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        Layout.minimumWidth: implicitWidth
        implicitHeight: rootObj.s(32)
        cornerRadius: ThemeBackend.borderRadius
        horizontalPadding: rootObj.s(14)
        buttonText: I18n.t("guide.display.map.refresh")
        buttonIcon: "󰑐"
        iconFontSize: rootObj.s(14)
        textFontSize: rootObj.s(12)
        accentColor: ThemeBackend.surface1
        onClicked: {
            tab.layoutDiscard();
            tab.reloadMonitors();
        }
    }
}
