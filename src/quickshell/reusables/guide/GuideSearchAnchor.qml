import QtQuick

Item {
    id: anchor
    visible: false

    property Item targetItem: parent
    property var rootObj: null
    property string settingId: ""
    property string title: ""
    property string description: ""
    property string icon: ""
    property string searchTab: ""
    property string searchSubTab: ""
    property string searchKeywords: ""
    property string section: ""
    property bool searchable: true
    property bool unavailable: false
    property var indexableCheck: null
    property bool autoRegister: true
    property string registeredSearchKey: ""

    readonly property var effectiveRootObj: {
        if (rootObj) return rootObj;
        let p = targetItem ? targetItem.parent : anchor.parent;
        while (p) {
            if (p.rootObj) return p.rootObj;
            if (p.isGuidePopup) return p;
            p = p.parent;
        }
        return null;
    }

    readonly property string effectiveSection: {
        if (section !== "") return section;
        let p = targetItem ? targetItem.parent : anchor.parent;
        while (p) {
            if (p.searchSection !== undefined && p.searchSection !== "") return p.searchSection;
            p = p.parent;
        }
        return "";
    }

    readonly property string effectiveSettingId: {
        if (settingId && settingId !== "") return settingId;
        if (title && title !== "") {
            return title.toLowerCase().replace(/[\x00-\x2f\x3a-\x5e\x60\x7b-\x7f\s]/g, "_");
        }
        return "";
    }

    function resolveLocation() {
        let r = effectiveRootObj;
        let target = targetItem || anchor.parent;
        if (r && typeof r.resolveTargetLocation === "function") {
            return r.resolveTargetLocation(target);
        }
        let tabIdx = -1;
        let subIdx = -1;
        let p = target ? target.parent : null;
        while (p) {
            if (subIdx === -1 && p.subTabIndex !== undefined && p.subTabIndex !== null && p.subTabIndex >= 0) {
                subIdx = p.subTabIndex;
            }
            if (tabIdx === -1 && p.tabIndex !== undefined && p.tabIndex !== null && p.tabIndex >= 0) {
                tabIdx = p.tabIndex;
            }
            p = p.parent;
        }
        return { tabIndex: tabIdx, subIndex: subIdx };
    }

    function isOwnTabLive() {
        let r = effectiveRootObj;
        if (!r || r.visible !== true) return false;
        let loc = resolveLocation();
        if (loc.tabIndex < 0) return false;
        if (loc.tabIndex !== r.currentTab) return false;
        if (loc.subIndex >= 0 && loc.subIndex !== r.currentSubTab) return false;
        return true;
    }

    function resolveTabInfo() {
        let tab = searchTab;
        let subtab = searchSubTab;
        if (tab !== "" && subtab !== "") {
            return { tab: tab, subtab: subtab };
        }
        let loc = resolveLocation();
        let r = effectiveRootObj;
        if (r && r.tabsModel && loc.tabIndex >= 0 && loc.tabIndex < r.tabsModel.length) {
            let tModel = r.tabsModel[loc.tabIndex];
            if (tab === "") {
                tab = tModel.key || tModel.id || "";
            }
            if (subtab === "" && tModel.subtabs && loc.subIndex >= 0 && loc.subIndex < tModel.subtabs.length) {
                subtab = tModel.subtabs[loc.subIndex].key || tModel.subtabs[loc.subIndex].id || "";
            }
        }
        return { tab: tab, subtab: subtab };
    }

    function ensureVisibleInFlickable() {
        let target = targetItem || anchor.parent;
        if (!target) return;
        let p = target.parent;
        let flick = null;
        while (p) {
            if (p.contentY !== undefined && p.contentHeight !== undefined) {
                flick = p;
                break;
            }
            p = p.parent;
        }
        if (flick) {
            let targetPos = target.mapToItem(flick.contentItem, 0, 0);
            if (targetPos) {
                let viewTop = flick.contentY;
                let viewBottom = flick.contentY + flick.height;
                if (targetPos.y < viewTop || targetPos.y + target.height > viewBottom) {
                    flick.contentY = Math.max(0, Math.min(targetPos.y - flick.height / 2 + target.height / 2, flick.contentHeight - flick.height));
                }
            }
        }
    }

    function registerWithSearch() {
        let r = effectiveRootObj;
        if (!r || typeof r.registerSearchItem !== "function") return;
        let canIndex = typeof indexableCheck === "function"
            ? Boolean(indexableCheck())
            : (anchor.searchable && anchor.title !== "");
        if (!canIndex) {
            unregisterFromSearch();
            return;
        }

        let info = resolveTabInfo();
        let searchKey = info.tab + "|" + info.subtab + "|" + anchor.effectiveSettingId;

        if (anchor.registeredSearchKey !== "" && anchor.registeredSearchKey !== searchKey) {
            r.unregisterSearchItem(anchor.registeredSearchKey);
        }
        anchor.registeredSearchKey = searchKey;

        r.registerSearchItem({
            key: searchKey,
            id: anchor.effectiveSettingId,
            title: anchor.title,
            desc: anchor.description,
            tab: info.tab,
            subtab: info.subtab,
            icon: anchor.icon,
            keywords: anchor.searchKeywords,
            section: anchor.effectiveSection,
            target: anchor.targetItem || anchor.parent,
            unavailable: anchor.unavailable
        });
    }

    function unregisterFromSearch() {
        let r = effectiveRootObj;
        if (!r || typeof r.unregisterSearchItem !== "function") return;
        let keyToUnregister = anchor.registeredSearchKey;
        if (!keyToUnregister || keyToUnregister === "") {
            let info = resolveTabInfo();
            if (anchor.effectiveSettingId !== "") {
                keyToUnregister = info.tab + "|" + info.subtab + "|" + anchor.effectiveSettingId;
            }
        }
        if (keyToUnregister && keyToUnregister !== "") {
            r.unregisterSearchItem(keyToUnregister);
            anchor.registeredSearchKey = "";
        }
    }

    function scheduleRegister() {
        if (autoRegister) regTimer.restart();
    }

    Timer {
        id: regTimer
        interval: 10
        repeat: false
        onTriggered: anchor.registerWithSearch()
    }

    onTitleChanged: scheduleRegister()
    onDescriptionChanged: scheduleRegister()
    onIconChanged: scheduleRegister()
    onSearchableChanged: scheduleRegister()
    onSearchTabChanged: scheduleRegister()
    onSearchSubTabChanged: scheduleRegister()
    onSettingIdChanged: scheduleRegister()
    onUnavailableChanged: scheduleRegister()

    Component.onCompleted: scheduleRegister()
    Component.onDestruction: unregisterFromSearch()
}
