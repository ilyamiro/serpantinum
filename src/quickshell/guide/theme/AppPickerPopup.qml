import QtQuick
import "../../"
import "../../reusables"

SearchableListPicker {
    id: pickerPopup

    multiSelect: true
    maxRows: 7
    placeholderText: I18n.t("guide.dock.picker.search", "Search apps...")
    doneText: I18n.t("guide.dock.picker.done", "Done")
    emptyText: AppTheming.loaded ? I18n.t("guide.dock.picker.empty", "No matching applications") : I18n.t("guide.theme.apps.loading", "Loading...")
    fallbackIcon: "󰏘"

    items: {
        let list = [];
        let apps = AppTheming.apps || [];
        for (let i = 0; i < apps.length; i++) {
            let a = apps[i];
            if (!a || !a.installed) continue;
            list.push({
                id: a.id,
                title: a.name,
                subtitle: (a.outputs && a.outputs.length > 0) ? a.outputs[0] : a.id,
                icon: a.icon || "",
                selected: Boolean(a.enabled)
            });
        }
        list.sort(function(a, b) { return String(a.title || "").localeCompare(String(b.title || "")); });
        return list;
    }

    onItemToggled: function(item) {
        if (!item) return;
        AppTheming.setEnabled(item.id, !item.selected);
    }

    function openPicker() {
        AppTheming.refresh();
        pickerPopup.query = "";
        pickerPopup.selectedId = "";
        pickerPopup.searchInput.text = "";
        pickerPopup.open();
        pickerPopup.searchInput.forceInputFocus();
    }
}
