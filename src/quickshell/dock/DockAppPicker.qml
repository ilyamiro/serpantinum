import QtQuick
import QtQuick.Controls
import "../"
import "../reusables"

Item {
    id: appPicker
    required property var dockWindow
    required property var dockContainer
    readonly property alias pickerSearchInput: picker.searchInput

    visible: dockWindow.editMode || picker.visible
    z: 100

    readonly property int maxPickerItems: dockWindow.isVertical ? 9 : 6

    width: Math.min(dockWindow.effectiveWindowWidth - dockWindow.s(16), dockWindow.isVertical ? dockWindow.s(320) : dockWindow.s(480))
    height: picker.implicitHeight > 0 ? picker.implicitHeight : (dockWindow.s(70) + maxPickerItems * dockWindow.s(48))

    x: {
        if (!dockWindow.isVertical) return Math.round((dockWindow.effectiveWindowWidth - width) / 2);
        if (dockWindow.dockPosition === "left") {
            return Math.round(dockContainer.x + dockContainer.width + dockWindow.s(12));
        }
        if (dockWindow.dockPosition === "right") {
            return Math.round(dockContainer.x - width - dockWindow.s(12));
        }
        return Math.round((dockWindow.effectiveWindowWidth - width) / 2);
    }

    y: {
        if (dockWindow.isVertical) return Math.round((dockWindow.effectiveWindowHeight - height) / 2);
        if (dockWindow.dockPosition === "top") {
            return Math.round(dockContainer.y + dockContainer.height + dockWindow.s(12));
        }
        if (dockWindow.dockPosition === "bottom") {
            return Math.round(dockContainer.y - height - dockWindow.s(12));
        }
        return Math.round((dockWindow.effectiveWindowHeight - height) / 2);
    }

    readonly property var pickerItems: {
        let _rev = dockWindow.dockAppsRevision;
        let src = dockWindow.allDesktopApps || [];
        let out = [];
        for (let i = 0; i < src.length; i++) {
            let app = src[i];
            if (!app) continue;
            let ic = app.icon || "";
            let iconSrc = AppMatcher.iconSource(ic);
            out.push({
                id: app.id || "",
                name: app.name || "",
                title: app.name || app.id || "",
                comment: app.comment || "",
                subtitle: app.comment || app.id || "",
                icon: ic,
                iconSource: iconSrc,
                selected: app.id ? dockWindow.isAppInDock(app.id) : false
            });
        }
        return out;
    }

    Connections {
        target: appPicker.dockWindow
        function onEditModeChanged() {
            if (appPicker.dockWindow.editMode) {
                picker.openPicker();
            } else if (picker.opened) {
                picker.close();
            }
        }
    }

    SearchableListPicker {
        id: picker
        parent: appPicker
        rootObj: appPicker.dockWindow
        x: 0
        y: 0
        width: appPicker.width
        preferredWidth: appPicker.width
        modal: false
        dim: false
        closePolicy: Popup.NoAutoClose
        multiSelect: true
        maxRows: appPicker.maxPickerItems
        items: appPicker.pickerItems
        placeholderText: I18n.t("guide.dock.picker.search", "Search apps...")
        emptyText: I18n.t("guide.dock.picker.empty", "No matching applications")
        doneText: I18n.t("guide.dock.picker.done", "Done")

        onItemToggled: function(item) {
            if (!item || !item.id) return;
            if (appPicker.dockWindow.isAppInDock(item.id)) {
                appPicker.dockWindow.removeAppByDesktopId(item.id);
            } else {
                appPicker.dockWindow.addApp(item);
            }
        }

        onClosed: {
            if (appPicker.dockWindow && appPicker.dockWindow.editMode) {
                appPicker.dockWindow.setEditMode(false);
            }
        }
    }
}
