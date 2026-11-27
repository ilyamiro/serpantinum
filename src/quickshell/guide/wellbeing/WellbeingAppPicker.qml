import QtQuick
import "../../"
import "../../reusables"

SearchableListPicker {
    id: picker
    required property var tab

    rootObj: tab.rootObj
    multiSelect: false
    maxRows: 6
    placeholderText: I18n.t("guide.wellbeing.settings.picker_search", "Search apps...")
    emptyText: I18n.t("guide.wellbeing.settings.picker_empty", "No matching applications")
    cancelText: I18n.t("guide.wellbeing.settings.picker_cancel", "Cancel")
    applyText: I18n.t("guide.wellbeing.settings.picker_apply", "Apply")
    fallbackIcon: "?"

    readonly property bool active: tab.appPickerMode !== ""
    property var allApps: []

    items: {
        let mode = tab.appPickerMode;
        let out = [];
        for (let i = 0; i < picker.allApps.length; i++) {
            let a = picker.allApps[i];
            if (!a || tab.isAppTaken(a.class, mode)) continue;
            out.push({
                id: a.class,
                title: a.name,
                subtitle: a.comment || a.class,
                iconSource: tab.iconSource(a.icon)
            });
        }
        return out;
    }

    onActiveChanged: {
        if (active) {
            picker.allApps = picker.tab.installedAppList();
            picker.openPicker();
        } else if (picker.opened) {
            picker.close();
        }
    }

    onClosed: {
        if (picker.tab.appPickerMode !== "") {
            picker.tab.closeAppPicker();
        }
    }

    onItemApplied: function(id, item) {
        if (id) {
            picker.tab.applyPickedApp(id);
        }
    }
}
