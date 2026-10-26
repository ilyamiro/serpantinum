import QtQuick
import QtQuick.Layouts
import ".."
import "../../"
import "../../reusables"
import "../../launcher/Categories.js" as Categories

GuideTab {
    id: tabRoot
    subTabIndex: 1

    property var order: Categories.defaultOrder()
    property var hidden: []
    property bool showCategories: false

    function syncSettings() {
        let raw = (typeof Config !== "undefined" && Config.dataReady)
            ? (Config.getSetting("launcher", {}) || {})
            : {};
        tabRoot.order = Categories.normalizeOrder(raw.categoryOrder);
        tabRoot.hidden = Categories.normalizeHidden(raw.hiddenCategories);
        tabRoot.showCategories = raw.showCategories !== undefined ? raw.showCategories : false;
        editor.load(tabRoot.order, tabRoot.hidden);
    }

    function saveLauncher(values) {
        if (typeof Config === "undefined" || !Config.dataReady) return;
        let current = JSON.parse(JSON.stringify(Config.getSetting("launcher", {}) || {}));
        for (let key in values) {
            current[key] = values[key];
        }
        Config.setSetting("launcher", current);
    }

    function applyOrder(newOrder) {
        tabRoot.order = newOrder;
        tabRoot.saveLauncher({ "categoryOrder": newOrder });
    }

    function applyHidden(catId, isHidden) {
        let next = tabRoot.hidden.slice();
        let index = next.indexOf(catId);
        if (isHidden && index === -1) next.push(catId);
        else if (!isHidden && index !== -1) next.splice(index, 1);
        tabRoot.hidden = next;
        tabRoot.saveLauncher({ "hiddenCategories": next });
    }

    function applyShowCategories(value) {
        tabRoot.showCategories = value;
        tabRoot.saveLauncher({ "showCategories": value });
    }

    function resetOrder() {
        let nextOrder = Categories.defaultOrder();
        let nextHidden = [];
        tabRoot.order = nextOrder;
        tabRoot.hidden = nextHidden;
        editor.load(nextOrder, nextHidden);
        tabRoot.saveLauncher({
            "categoryOrder": nextOrder,
            "hiddenCategories": nextHidden
        });
    }

    Component.onCompleted: syncSettings()

    onVisibleChanged: {
        if (visible) syncSettings();
    }

    Connections {
        target: typeof Config !== "undefined" ? Config : null
        function onSettingsLoaded() {
            if (tabRoot.visible) tabRoot.syncSettings();
        }
    }

    Flickable {
        anchors.fill: parent
        anchors.topMargin: rootObj.s(8)
        anchors.leftMargin: rootObj.s(8)
        anchors.rightMargin: rootObj.s(8)
        anchors.bottomMargin: rootObj.s(8)
        contentHeight: settingsCol.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: settingsCol
            width: parent.width
            spacing: rootObj.s(6)

            SettingsBlob {
                SettingsRow {
                    rootObj: tabRoot.rootObj
                    icon: "󰈈"
                    title: I18n.t("guide.launcher.categories.show_title", "Show categories")
                    description: I18n.t("guide.launcher.categories.show_desc", "Show the category bar in the launcher. When disabled, the launcher keeps the plain app list.")

                    Toggle {
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        checked: tabRoot.showCategories
                        accentColor: ThemeBackend.mauve
                        baseColor: ThemeBackend.surface1
                        handleColor: ThemeBackend.crust
                        handleOffColor: ThemeBackend.text
                        onToggled: function(val) {
                            tabRoot.applyShowCategories(val);
                        }
                    }
                }

                SettingsRow {
                    rootObj: tabRoot.rootObj
                    icon: "󰀻"
                    title: I18n.t("guide.launcher.categories.title", "Application categories")
                    description: I18n.t("guide.launcher.categories.desc", "Drag chips to reorder them. Click the eye to hide a category from the launcher. Empty categories are hidden automatically.")
                }

                CategoryOrderEditor {
                    id: editor
                    rootObj: tabRoot.rootObj
                    Layout.leftMargin: rootObj.s(12)
                    Layout.rightMargin: rootObj.s(12)
                    Layout.bottomMargin: rootObj.s(12)

                    onOrderChanged: function(newOrder) {
                        tabRoot.applyOrder(newOrder);
                    }
                    onHiddenToggled: function(catId, isHidden) {
                        tabRoot.applyHidden(catId, isHidden);
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: rootObj.s(4)
                Layout.leftMargin: rootObj.s(4)
                Layout.rightMargin: rootObj.s(4)

                Item { Layout.fillWidth: true }

                ClickButton {
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    implicitHeight: rootObj.s(36)
                    horizontalPadding: rootObj.s(16)
                    buttonText: I18n.t("guide.launcher.categories.reset", "Reset order")
                    buttonIcon: "󰜉"
                    iconFontSize: rootObj.s(15)
                    textFontSize: rootObj.s(12)
                    accentColor: ThemeBackend.surface1
                    textColor: ThemeBackend.text
                    cornerRadius: ThemeBackend.borderRadius
                    onClicked: tabRoot.resetOrder()
                }
            }
        }
    }
}
