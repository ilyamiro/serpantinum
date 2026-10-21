import QtQuick
import QtQuick.Window
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../"
import "../reusables"
import "../mc"
import "../reusables/buttons"

Item {
    id: root
    visible: false
    focus: true

    readonly property bool isGuidePopup: true

    signal requestLoadAll()

    property int activationCounter: 0
    property var appPaths: Caching
    property int currentTab: 0
    property int currentSubTab: 0
    property int expandedTab: -1

    property real colorBlend: 0.0
    property color ambientPurple: Qt.tint(ThemeBackend.mauve, Qt.rgba(ThemeBackend.pink.r, ThemeBackend.pink.g, ThemeBackend.pink.b, colorBlend))
    property color ambientBlue: Qt.tint(ThemeBackend.blue, Qt.rgba(ThemeBackend.sapphire.r, ThemeBackend.sapphire.g, ThemeBackend.sapphire.b, colorBlend))
    property int chargingSoundHandle: -1

    property real introBase: 0.0
    property real introSidebar: 0.0
    property real introContent: 0.0
    property real introTabs: 0.0
    property var tutorialSections: []

    property bool searchActive: false
    property string searchQuery: ""
    property int searchSelectedIndex: -1
    property string highlightedSettingId: ""
    property int highlightToken: 0
    property var pendingHighlightItem: null

    property var searchIndexMap: ({})
    property var searchIndex: []

    function resolveI18nText(text) {
        if (!text) return "";
        let s = String(text).trim();
        if (s === "") return "";
        if (typeof I18n !== "undefined" && typeof I18n.t === "function") {
            try {
                let res = I18n.t(s);
                if (res && res !== s) return res;
            } catch(e) {}
        }
        return s;
    }

    function resolveTabTitle(tabKey) {
        if (!tabKey) return "";
        let s = String(tabKey).trim();
        let cleanKey = s.replace(/^guide\.tabs\./, "").toLowerCase();
        for (let i = 0; i < tabsModel.length; i++) {
            let t = tabsModel[i];
            if ((t.key && t.key.toLowerCase() === cleanKey) ||
                (t.id && t.id.toLowerCase() === cleanKey) ||
                (t.name && t.name.toLowerCase() === cleanKey)) {
                return I18n.t("guide.tabs." + (t.key || t.id).toLowerCase(), t.name || t.id);
            }
        }
        return resolveI18nText(s);
    }

    function resolveSubtabTitle(tabKey, subtabKey) {
        if (!subtabKey) return "";
        let s = String(subtabKey).trim();
        let cleanSub = s.replace(/^guide\.tabs\./, "").toLowerCase();
        let cleanTab = String(tabKey || "").replace(/^guide\.tabs\./, "").toLowerCase();

        for (let i = 0; i < tabsModel.length; i++) {
            let t = tabsModel[i];
            if (cleanTab === "" || (t.key && t.key.toLowerCase() === cleanTab) ||
                (t.id && t.id.toLowerCase() === cleanTab) ||
                (t.name && t.name.toLowerCase() === cleanTab)) {
                if (t.subtabs && Array.isArray(t.subtabs)) {
                    let st = t.subtabs.find(x =>
                        (x.key && x.key.toLowerCase() === cleanSub) ||
                        (x.id && x.id.toLowerCase() === cleanSub) ||
                        (x.name && x.name.toLowerCase() === cleanSub)
                    );
                    if (st) {
                        return I18n.t("guide.tabs." + (st.key || st.id).toLowerCase(), st.name || st.id);
                    }
                }
            }
        }
        return resolveI18nText(s);
    }

    function getTabIcon(tabKey, subtabKey) {
        let cleanSub = String(subtabKey || "").replace(/^guide\.tabs\./, "").toLowerCase();
        let cleanTab = String(tabKey || "").replace(/^guide\.tabs\./, "").toLowerCase();

        for (let i = 0; i < tabsModel.length; i++) {
            let t = tabsModel[i];
            if ((t.key && t.key.toLowerCase() === cleanTab) ||
                (t.id && t.id.toLowerCase() === cleanTab) ||
                (t.name && t.name.toLowerCase() === cleanTab)) {
                if (cleanSub && t.subtabs && Array.isArray(t.subtabs)) {
                    let st = t.subtabs.find(x =>
                        (x.key && x.key.toLowerCase() === cleanSub) ||
                        (x.id && x.id.toLowerCase() === cleanSub) ||
                        (x.name && x.name.toLowerCase() === cleanSub)
                    );
                    if (st && st.icon) return st.icon;
                }
                return t.icon || "󰒓";
            }
        }
        return "󰒓";
    }

    function resolveIndices(tabKey, subKey) {
        if (!tabKey) return { tabIndex: -1, subIndex: -1 };
        let lower = String(tabKey).toLowerCase().replace(/^guide\.tabs\./, "");
        for (let i = 0; i < tabsModel.length; i++) {
            let t = tabsModel[i];
            if ((t.id && t.id.toLowerCase() === lower) ||
                (t.name && t.name.toLowerCase() === lower) ||
                (t.key && t.key.toLowerCase() === lower)) {
                let sIdx = -1;
                if (subKey !== undefined && subKey !== null && subKey !== "") {
                    let sLower = String(subKey).toLowerCase().replace(/^guide\.tabs\./, "");
                    let sNum = parseInt(subKey);
                    if (!isNaN(sNum) && t.subtabs && sNum >= 0 && sNum < t.subtabs.length) {
                        sIdx = sNum;
                    } else if (t.subtabs) {
                        sIdx = t.subtabs.findIndex(st =>
                            (st.id && st.id.toLowerCase() === sLower) ||
                            (st.name && st.name.toLowerCase() === sLower) ||
                            (st.key && st.key.toLowerCase() === sLower)
                        );
                    }
                }
                return { tabIndex: i, subIndex: sIdx };
            }

            if (t.subtabs && Array.isArray(t.subtabs)) {
                let sIdx = t.subtabs.findIndex(st =>
                    (st.id && st.id.toLowerCase() === lower) ||
                    (st.name && st.name.toLowerCase() === lower) ||
                    (st.key && st.key.toLowerCase() === lower)
                );
                if (sIdx !== -1) {
                    return { tabIndex: i, subIndex: sIdx };
                }
            }
        }
        return { tabIndex: -1, subIndex: -1 };
    }

    function resolveTargetLocation(target) {
        let tabIdx = -1;
        let subIdx = -1;
        if (!target) return { tabIndex: tabIdx, subIndex: subIdx };
        try {
            let p = target.parent;
            while (p) {
                if (subIdx === -1 && p.subTabIndex !== undefined && p.subTabIndex !== null && p.subTabIndex >= 0) {
                    subIdx = p.subTabIndex;
                }
                if (tabIdx === -1 && p.tabIndex !== undefined && p.tabIndex !== null && p.tabIndex >= 0) {
                    tabIdx = p.tabIndex;
                }
                p = p.parent;
            }
        } catch(e) {
            return { tabIndex: -1, subIndex: -1 };
        }
        if (tabIdx >= tabsModel.length) tabIdx = -1;
        return { tabIndex: tabIdx, subIndex: subIdx };
    }

    function normalizeSearchEntry(entry) {
        if (!entry) return null;
        let id = String(entry.id || entry.settingId || entry.title || "").trim();
        if (!id) return null;
        let tab = String(entry.tab || entry.searchTab || "").trim();
        let subtab = String(entry.subtab || entry.searchSubTab || "").trim();

        let norm = s => String(s || "").trim().toLowerCase().replace(/^guide\.tabs\./, "");
        let cleanTab = norm(tab);
        let cleanSubtab = norm(subtab);

        let indices = resolveIndices(tab, subtab);
        if (indices.tabIndex >= 0 && indices.tabIndex < tabsModel.length) {
            let tModel = tabsModel[indices.tabIndex];
            cleanTab = norm(tModel.key || tModel.id);
            if (indices.subIndex >= 0 && tModel.subtabs && indices.subIndex < tModel.subtabs.length) {
                let stModel = tModel.subtabs[indices.subIndex];
                cleanSubtab = norm(stModel.key || stModel.id);
            }
        }

        let key = cleanTab + "|" + cleanSubtab + "|" + id.toLowerCase();
        return {
            key: key,
            id: id,
            title: String(entry.title || "").trim(),
            desc: String(entry.desc || entry.description || "").trim(),
            description: String(entry.description || entry.desc || "").trim(),
            tab: cleanTab,
            subtab: cleanSubtab,
            icon: String(entry.icon || "󰒓").trim(),
            keywords: entry.keywords || entry.searchKeywords || "",
            target: entry.target || null,
            onSelected: entry.onSelected || null
        };
    }

    function registerSearchItem(entry) {
        let item = normalizeSearchEntry(entry);
        if (!item) return;
        searchIndexMap[item.key] = item;
        searchRebuildTimer.restart();
    }

    function registerSearchItems(items) {
        if (!Array.isArray(items)) return;
        let changed = false;
        for (let i = 0; i < items.length; i++) {
            let item = normalizeSearchEntry(items[i]);
            if (item) {
                searchIndexMap[item.key] = item;
                changed = true;
            }
        }
        if (changed) {
            searchRebuildTimer.restart();
        }
    }

    function unregisterSearchItem(idOrKey) {
        if (!idOrKey) return;
        let key = String(idOrKey).trim();
        if (searchIndexMap[key]) {
            delete searchIndexMap[key];
            searchRebuildTimer.restart();
            return;
        }

        let norm = s => String(s || "").trim().toLowerCase().replace(/^guide\.tabs\./, "");
        let parts = key.split("|");
        if (parts.length === 3) {
            let cleanTab = norm(parts[0]);
            let cleanSubtab = norm(parts[1]);
            let indices = resolveIndices(parts[0], parts[1]);
            if (indices.tabIndex >= 0 && indices.tabIndex < tabsModel.length) {
                let tModel = tabsModel[indices.tabIndex];
                cleanTab = norm(tModel.key || tModel.id);
                if (indices.subIndex >= 0 && tModel.subtabs && indices.subIndex < tModel.subtabs.length) {
                    let stModel = tModel.subtabs[indices.subIndex];
                    cleanSubtab = norm(stModel.key || stModel.id);
                }
            }
            let canonicalKey = cleanTab + "|" + cleanSubtab + "|" + parts[2].trim().toLowerCase();
            if (searchIndexMap[canonicalKey]) {
                delete searchIndexMap[canonicalKey];
                searchRebuildTimer.restart();
                return;
            }
        }

        for (let k in searchIndexMap) {
            if (searchIndexMap[k] && (searchIndexMap[k].id === key || searchIndexMap[k].id.toLowerCase() === key.toLowerCase())) {
                delete searchIndexMap[k];
                searchRebuildTimer.restart();
                break;
            }
        }
    }

    function rebuildSearchIndex() {
        let list = [];
        for (let k in searchIndexMap) {
            list.push(searchIndexMap[k]);
        }
        searchIndex = list;
    }

    function registerTabSearchItems(tabItem) {
        if (!tabItem) return;
        if (tabItem.searchItems && Array.isArray(tabItem.searchItems)) {
            registerSearchItems(tabItem.searchItems);
        }
        if (tabItem.searchEntries && Array.isArray(tabItem.searchEntries)) {
            registerSearchItems(tabItem.searchEntries);
        }
    }

    readonly property var filteredSearchResults: {
        let q = searchQuery.trim().toLowerCase();
        if (q === "") return [];
        return searchIndex.filter(item => {
            let rawT = (item.title || "").toLowerCase();
            let trT = resolveI18nText(item.title).toLowerCase();
            let rawD = (item.desc || item.description || "").toLowerCase();
            let trD = resolveI18nText(item.desc || item.description).toLowerCase();
            let tabT = resolveTabTitle(item.tab).toLowerCase();
            let subT = resolveSubtabTitle(item.tab, item.subtab).toLowerCase();
            let rawTb = (item.tab || "").toLowerCase();
            let rawStb = (item.subtab || "").toLowerCase();
            let kw = String(item.keywords || "").toLowerCase();

            return trT.indexOf(q) !== -1 || rawT.indexOf(q) !== -1 ||
                   trD.indexOf(q) !== -1 || rawD.indexOf(q) !== -1 ||
                   tabT.indexOf(q) !== -1 || subT.indexOf(q) !== -1 ||
                   rawTb.indexOf(q) !== -1 || rawStb.indexOf(q) !== -1 ||
                   kw.indexOf(q) !== -1;
        });
    }

    readonly property var groupedSearchResults: {
        let results = filteredSearchResults;
        if (results.length === 0) return [];

        let tabGroupsMap = {};

        for (let i = 0; i < results.length; i++) {
            let item = results[i];
            let tKey = String(item.tab || "").trim();
            let sKey = String(item.subtab || "").trim();
            let indices = resolveIndices(tKey, sKey);
            let tIdx = indices.tabIndex !== -1 ? indices.tabIndex : 9999;
            let sIdx = indices.subIndex;

            if (!tabGroupsMap[tIdx]) {
                let isKnown = tIdx >= 0 && tIdx < tabsModel.length;
                let tModel = isKnown ? tabsModel[tIdx] : null;
                tabGroupsMap[tIdx] = {
                    tabKey: isKnown ? (tModel.key || tModel.id) : tKey,
                    tabIndex: tIdx,
                    title: isKnown ? resolveTabTitle(tModel.key || tModel.id) : I18n.t("guide.tabs.general", "General"),
                    icon: isKnown ? (tModel.icon || "󰒓") : "󰒓",
                    iconOffsetX: isKnown ? (tModel.iconOffsetX ?? 0) : 0,
                    directItems: [],
                    subgroupsMap: {}
                };
            }

            let tg = tabGroupsMap[tIdx];
            let isKnown = tIdx >= 0 && tIdx < tabsModel.length;
            let tModel = isKnown ? tabsModel[tIdx] : null;

            if (sIdx >= 0 && isKnown && tModel && tModel.subtabs && sIdx < tModel.subtabs.length) {
                let stModel = tModel.subtabs[sIdx];
                if (!tg.subgroupsMap[sIdx]) {
                    tg.subgroupsMap[sIdx] = {
                        subKey: stModel.key || stModel.id,
                        subIndex: sIdx,
                        title: resolveSubtabTitle(tModel.key || tModel.id, stModel.key || stModel.id),
                        icon: stModel.icon || "󰒓",
                        iconOffsetX: stModel.iconOffsetX ?? 0,
                        items: []
                    };
                }
                tg.subgroupsMap[sIdx].items.push(item);
            } else {
                tg.directItems.push(item);
            }
        }

        let sortedGroups = Object.values(tabGroupsMap).map(tg => {
            let subList = Object.values(tg.subgroupsMap);
            subList.sort((a, b) => a.subIndex - b.subIndex);
            return {
                tabKey: tg.tabKey,
                tabIndex: tg.tabIndex,
                title: tg.title,
                icon: tg.icon,
                iconOffsetX: tg.iconOffsetX,
                directItems: tg.directItems,
                subgroups: subList
            };
        });

        sortedGroups.sort((a, b) => a.tabIndex - b.tabIndex);
        return sortedGroups;
    }

    readonly property var flatSearchResults: {
        let groups = groupedSearchResults;
        if (!groups || groups.length === 0) return [];
        let list = [];
        for (let i = 0; i < groups.length; i++) {
            let tg = groups[i];
            if (tg.directItems && tg.directItems.length > 0) {
                for (let d = 0; d < tg.directItems.length; d++) {
                    list.push(tg.directItems[d]);
                }
            }
            if (tg.subgroups && tg.subgroups.length > 0) {
                for (let s = 0; s < tg.subgroups.length; s++) {
                    let sg = tg.subgroups[s];
                    if (sg.items && sg.items.length > 0) {
                        for (let k = 0; k < sg.items.length; k++) {
                            list.push(sg.items[k]);
                        }
                    }
                }
            }
        }
        return list;
    }

    function navigateSearch(dir) {
        let count = flatSearchResults.length;
        if (count === 0) return;
        if (searchSelectedIndex === -1) {
            searchSelectedIndex = dir > 0 ? 0 : count - 1;
        } else {
            searchSelectedIndex = (searchSelectedIndex + dir + count) % count;
        }
    }

    function activateSelectedSearch() {
        let count = flatSearchResults.length;
        if (count === 0) return;
        let item = (searchSelectedIndex >= 0 && searchSelectedIndex < count)
            ? flatSearchResults[searchSelectedIndex]
            : flatSearchResults[0];
        if (item) {
            selectSearchResult(item);
        }
    }

    function ensureSearchItemVisible(itemObj) {
        if (!itemObj || !sidebar.searchResults) return;
        try {
            let mapped = itemObj.mapToItem(sidebar.searchResults.column, 0, 0);
            let itemY = mapped.y;
            let itemH = itemObj.height;
            let viewTop = sidebar.searchResults.contentY;
            let viewHeight = sidebar.searchResults.height;
            let viewBottom = viewTop + viewHeight;

            if (itemY < viewTop) {
                sidebar.searchResults.contentY = Math.max(0, itemY - root.s(8));
            } else if (itemY + itemH > viewBottom) {
                let maxScroll = Math.max(0, sidebar.searchResults.contentHeight - viewHeight);
                sidebar.searchResults.contentY = Math.min(maxScroll, itemY + itemH - viewHeight + root.s(8));
            }
        } catch(e) {}
    }

    function ensureTabVisible(idx) {
        if (!sidebar.tabsView || idx < 0 || !sidebar.tabsItems || idx >= sidebar.tabsItems.count) return;
        try {
            let item = sidebar.tabsItems.itemAt(idx);
            if (!item) return;
            let itemY = item.y;
            let itemH = item.height;
            let viewTop = sidebar.tabsView.contentY;
            let viewHeight = sidebar.tabsView.height;
            let viewBottom = viewTop + viewHeight;

            if (itemY < viewTop) {
                sidebar.tabsView.contentY = Math.max(0, itemY - root.s(8));
            } else if (itemY + itemH > viewBottom) {
                let maxScroll = Math.max(0, sidebar.tabsView.contentHeight - viewHeight);
                sidebar.tabsView.contentY = Math.min(maxScroll, itemY + itemH - viewHeight + root.s(8));
            }
        } catch(e) {}
    }

    function triggerHighlight(settingId) {
        highlightedSettingId = settingId;
        highlightToken++;
    }

    function openSearch() {
        root.requestLoadAll();
        searchRebuildTimer.stop();
        rebuildSearchIndex();
        searchClearTimer.stop();
        searchActive = true;
        searchSelectedIndex = -1;
        searchFocusTimer.restart();
    }

    function closeSearch() {
        if (!searchActive) return;
        searchActive = false;
        searchSelectedIndex = -1;
        root.forceActiveFocus();
        searchClearTimer.restart();
    }

    function selectSearchResult(item) {
        if (!item) return;

        let loc = resolveTargetLocation(item.target);
        if (loc.tabIndex >= 0) {
            gotoTab(String(loc.tabIndex), loc.subIndex >= 0 ? String(loc.subIndex) : "");
        } else {
            gotoTab(item.tab, item.subtab);
        }

        pendingHighlightItem = item;
        highlightTimer.restart();

        if (typeof item.onSelected === "function") {
            try { item.onSelected(); } catch(e) {}
        }
        closeSearch();
    }

    function runPendingHighlight() {
        let item = pendingHighlightItem;
        pendingHighlightItem = null;
        if (!item) return;

        let handled = false;
        if (item.target) {
            try {
                if (typeof item.target.triggerHighlightAnimation === "function") {
                    item.target.triggerHighlightAnimation();
                    handled = true;
                }
            } catch(e) {
                handled = false;
            }
        }
        if (!handled) {
            triggerHighlight(item.id);
        }
    }

    property var tabsModel: [
        { id: "Welcome", key: "welcome", name: "Welcome", icon: "󰋜", file: "WelcomeTab.qml", iconOffsetX: -1 },
        { id: "General", key: "general", name: "General", icon: "󰒓", file: "general/GeneralTab.qml", iconOffsetX: 0 },
        { 
            id: "Display", 
            key: "display", 
            name: "Display", 
            icon: "󰃠", 
            file: "display/DisplayMainTab.qml", 
            iconOffsetX: 0,
            subtabs: [
                { id: "DisplayGeneral", key: "display_general", name: "Display", icon: "󰃠", file: "display/DisplayMainTab.qml", iconOffsetX: 1 },
                { id: "DisplayWidgets", key: "display_widgets", name: "Widgets", icon: "󰕰", file: "display/DisplayWidgetsTab.qml", iconOffsetX: 0 }
            ]
        },
        { id: "Theme", key: "theme", name: "Theme", icon: "󰏘", file: "theme/ThemeTab.qml", iconOffsetX: 0 },
        { 
            id: "Bar", 
            key: "bar", 
            name: "Bar", 
            icon: "󰹑", 
            file: "bar/BarGeneralTab.qml", 
            iconOffsetX: -2,
            subtabs: [
                { id: "BarGeneral", key: "bar_general", name: "General", icon: "󰒓", file: "bar/BarGeneralTab.qml", iconOffsetX: 1 },
                { id: "BarModules", key: "bar_modules", name: "Modules", icon: "󰮯", file: "bar/BarModulesTab.qml", iconOffsetX: 0 }
            ]
        },
        { id: "Launcher", key: "launcher", name: "Launcher", icon: "󰵆", file: "LauncherTab.qml", iconOffsetX: 0 },
        { id: "Dock", key: "dock", name: "Dock", icon: "󰮯", file: "DockTab.qml", iconOffsetX: 0 },
        { id: "On-Screen Display", key: "osd", name: "On-Screen Display", icon: "󰕾", file: "OnScreenDisplayTab.qml", iconOffsetX: 0 },
        { id: "Notifications", key: "notifications", name: "Notifications", icon: "󰂚", file: "notifications/NotificationsTab.qml", iconOffsetX: 0 },
        { id: "Wellbeing", key: "wellbeing", name: "Wellbeing", icon: "󰄉", file: "wellbeing/DigitalWellbeingTab.qml", iconOffsetX: 0 },        
        { id: "Idle", key: "idle", name: "Idle", icon: "󰒲", file: "IdleTab.qml", iconOffsetX: 0 },
        { id: "About", key: "about", name: "About", icon: "󰋽", file: "AboutTab.qml", iconOffsetX: 0 }
    ]

    StackView.onStatusChanged: {
        if (StackView.status === StackView.Active) {
            activationCounter++;
        }
    }

    property var exitCallback: null

    function startExit(onFinished) {
        exitCallback = onFinished;
        closePopup();
    }

    function closePopup() {
        closeSearch();
        startupSequence.stop();
        closeSequence.restart();
    }

    function s(val) {
        return Scaler.s(val);
    }

    function getTabProgress(idx) {
        if (introTabs >= 1.0) return 1.0;
        if (introTabs <= 0.0) return 0.0;
        let start = idx * 0.04;
        let p = Math.min(1.0, Math.max(0.0, (introTabs - start) / 0.42));
        if (p <= 0.0) return 0.0;
        if (p >= 1.0) return 1.0;
        let c1 = 0.85;
        let c3 = c1 + 1;
        return 1 + c3 * Math.pow(p - 1, 3) + c1 * Math.pow(p - 1, 2);
    }

    function getTabOpacity(idx) {
        if (introTabs >= 1.0) return 1.0;
        if (introTabs <= 0.0) return 0.0;
        let start = idx * 0.04;
        let p = Math.min(1.0, Math.max(0.0, (introTabs - start) / 0.28));
        return p;
    }

    function gotoTab(tabName, subTabName) {
        if (tabName === undefined || tabName === null || tabName === "") return;
        let num = parseInt(tabName);
        if (!isNaN(num) && num >= 0 && num < tabsModel.length) {
            currentTab = num;
            expandedTab = (tabsModel[num].subtabs && tabsModel[num].subtabs.length > 0) ? num : -1;
            if (subTabName !== undefined && subTabName !== null && subTabName !== "") {
                let sNum = parseInt(subTabName);
                currentSubTab = !isNaN(sNum) ? sNum : 0;
            } else {
                currentSubTab = 0;
            }
            return;
        }
        let lower = String(tabName).toLowerCase().replace(/^guide\.tabs\./, "");
        for (let i = 0; i < tabsModel.length; i++) {
            let t = tabsModel[i];
            if ((t.id && t.id.toLowerCase() === lower) || 
                (t.name && t.name.toLowerCase() === lower) || 
                (t.key && t.key.toLowerCase() === lower)) {
                currentTab = i;
                expandedTab = (t.subtabs && t.subtabs.length > 0) ? i : -1;
                if (subTabName !== undefined && subTabName !== null && subTabName !== "") {
                    let sLower = String(subTabName).toLowerCase().replace(/^guide\.tabs\./, "");
                    let sNum = parseInt(subTabName);
                    if (!isNaN(sNum) && t.subtabs && sNum >= 0 && sNum < t.subtabs.length) {
                        currentSubTab = sNum;
                    } else if (t.subtabs) {
                        let sIdx = t.subtabs.findIndex(st => 
                            (st.id && st.id.toLowerCase() === sLower) || 
                            (st.name && st.name.toLowerCase() === sLower) || 
                            (st.key && st.key.toLowerCase() === sLower)
                        );
                        currentSubTab = sIdx !== -1 ? sIdx : 0;
                    } else {
                        currentSubTab = 0;
                    }
                } else {
                    currentSubTab = 0;
                }
                return;
            }

            if (t.subtabs && Array.isArray(t.subtabs)) {
                let sIdx = t.subtabs.findIndex(st => 
                    (st.id && st.id.toLowerCase() === lower) || 
                    (st.name && st.name.toLowerCase() === lower) || 
                    (st.key && st.key.toLowerCase() === lower)
                );
                if (sIdx !== -1) {
                    currentTab = i;
                    expandedTab = i;
                    currentSubTab = sIdx;
                    return;
                }
            }
        }
    }

    function resetAndPlayIntro() {
        introBase = 0.0;
        introSidebar = 0.0;
        introContent = 0.0;
        introTabs = 0.0;
        startupSequence.restart();
        Updater.checkUpdate();
    }

    function nextTab() {
        let parentTab = tabsModel[currentTab];
        if (parentTab && parentTab.subtabs && parentTab.subtabs.length > 0 && expandedTab === currentTab) {
            if (currentSubTab < parentTab.subtabs.length - 1) {
                currentSubTab++;
                return;
            }
        }
        currentTab = (currentTab + 1) % tabsModel.length;
        let nextParent = tabsModel[currentTab];
        if (nextParent && nextParent.subtabs && nextParent.subtabs.length > 0) {
            expandedTab = currentTab;
            currentSubTab = 0;
        } else {
            expandedTab = -1;
            currentSubTab = 0;
        }
    }

    function prevTab() {
        let parentTab = tabsModel[currentTab];
        if (parentTab && parentTab.subtabs && parentTab.subtabs.length > 0 && expandedTab === currentTab) {
            if (currentSubTab > 0) {
                currentSubTab--;
                return;
            }
        }
        currentTab = (currentTab - 1 + tabsModel.length) % tabsModel.length;
        let prevParent = tabsModel[currentTab];
        if (prevParent && prevParent.subtabs && prevParent.subtabs.length > 0) {
            expandedTab = currentTab;
            currentSubTab = prevParent.subtabs.length - 1;
        } else {
            expandedTab = -1;
            currentSubTab = 0;
        }
    }

    Timer {
        id: focusTimer
        interval: 50
        repeat: false
        onTriggered: root.forceActiveFocus()
    }

    Timer {
        id: searchFocusTimer
        interval: 40
        repeat: false
        onTriggered: {
            if (sidebar.searchInput) {
                sidebar.searchInput.forceInputFocus();
            }
        }
    }

    Timer {
        id: highlightTimer
        interval: 160
        repeat: false
        onTriggered: root.runPendingHighlight()
    }

    Timer {
        id: searchClearTimer
        interval: 260
        repeat: false
        onTriggered: {
            searchQuery = "";
            if (sidebar.searchInput) sidebar.searchInput.text = "";
        }
    }

    Timer {
        id: searchRebuildTimer
        interval: 30
        repeat: false
        onTriggered: root.rebuildSearchIndex()
    }

    onVisibleChanged: {
        if (visible) {
            forceActiveFocus();
            focusTimer.restart();
            resetAndPlayIntro();
        } else {
            startupSequence.stop();
            closeSequence.stop();
            highlightTimer.stop();
            searchClearTimer.stop();
            searchRebuildTimer.stop();
            rebuildSearchIndex();
            pendingHighlightItem = null;
            introBase = 0.0;
            introSidebar = 0.0;
            introContent = 0.0;
            introTabs = 0.0;
            searchActive = false;
            searchQuery = "";
            searchSelectedIndex = -1;
            if (sidebar.searchInput) sidebar.searchInput.text = "";
            if (root.chargingSoundHandle !== -1 && typeof Sounds !== "undefined") {
                Sounds.stopSfx(root.chargingSoundHandle);
                root.chargingSoundHandle = -1;
            }
        }
    }

    Component.onCompleted: {
        if (visible) {
            forceActiveFocus();
            focusTimer.restart();
            resetAndPlayIntro();
        }
    }

    Shortcut {
        sequences: [StandardKey.Find]
        onActivated: root.openSearch()
    }

    Keys.onEscapePressed: (event) => {
        if (root.searchActive) {
            root.closeSearch();
            event.accepted = true;
            return;
        }
        if (typeof masterWindow !== "undefined" && masterWindow.switchWidget) {
            masterWindow.switchWidget("hidden", "");
        } else {
            closePopup();
        }
        event.accepted = true;
    }
    Keys.onDownPressed: (event) => {
        if (root.searchActive) {
            root.navigateSearch(1);
            event.accepted = true;
        } else {
            root.nextTab();
            event.accepted = true;
        }
    }
    Keys.onUpPressed: (event) => {
        if (root.searchActive) {
            root.navigateSearch(-1);
            event.accepted = true;
        } else {
            root.prevTab();
            event.accepted = true;
        }
    }
    Keys.onLeftPressed: (event) => {
        if (!root.searchActive) {
            root.prevTab();
            event.accepted = true;
        }
    }
    Keys.onRightPressed: (event) => {
        if (!root.searchActive) {
            root.nextTab();
            event.accepted = true;
        }
    }
    Keys.onReturnPressed: (event) => {
        if (root.searchActive) {
            root.activateSelectedSearch();
            event.accepted = true;
        }
    }
    Keys.onEnterPressed: (event) => {
        if (root.searchActive) {
            root.activateSelectedSearch();
            event.accepted = true;
        }
    }
    Keys.onTabPressed: (event) => {
        if (root.searchActive) {
            root.navigateSearch(1);
            event.accepted = true;
            return;
        }
        nextTab();
        event.accepted = true;
    }
    Keys.onBacktabPressed: (event) => {
        if (root.searchActive) {
            root.navigateSearch(-1);
            event.accepted = true;
            return;
        }
        prevTab();
        event.accepted = true;
    }

    SequentialAnimation on colorBlend {
        loops: Animation.Infinite
        running: root.visible
        NumberAnimation { to: 1.0; duration: 15000; easing.type: Easing.InOutSine }
        NumberAnimation { to: 0.0; duration: 15000; easing.type: Easing.InOutSine }
    }

    Timer {
        id: saveTabDebounceTimer
        interval: 350
        repeat: false
        onTriggered: {
            Quickshell.execDetached(["bash", "-c", "echo '" + root.currentTab + ":" + root.currentSubTab + "' > '" + Caching.getCacheDir("guide") + "/last_tab.txt'"]);
        }
    }

    function saveLastTab() {
        saveTabDebounceTimer.restart();
    }

    onCurrentTabChanged: {
        saveLastTab();
        ensureTabVisible(currentTab);
    }
    onCurrentSubTabChanged: saveLastTab()

    FileView {
        id: lastTabWatcher
        path: Caching.getCacheDir("guide") + "/last_tab.txt"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                let val = text().trim();
                if (val !== "") {
                    if (val.indexOf(":") !== -1) {
                        let parts = val.split(":");
                        root.gotoTab(parts[0], parts[1]);
                    } else {
                        root.gotoTab(val);
                    }
                }
            } catch(e) {}
        }
    }

    FileView {
        id: tutorialWatcher
        path: Caching.serpantinumDir ? (Caching.serpantinumDir + "/assets/tutorial.json") : ""
        onLoaded: {
            try {
                let data = JSON.parse(text().trim());
                if (Array.isArray(data)) {
                    root.tutorialSections = data;
                }
            } catch(e) {}
        }
    }

    ParallelAnimation {
        id: startupSequence
        running: false
        NumberAnimation {
            target: root
            property: "introBase"
            from: 0.0
            to: 1.0
            duration: 650
            easing.type: Easing.OutExpo
        }
        SequentialAnimation {
            PauseAnimation { duration: 60 }
            NumberAnimation {
                target: root
                property: "introSidebar"
                from: 0.0
                to: 1.0
                duration: 400
                easing.type: Easing.OutCubic
            }
        }
        SequentialAnimation {
            PauseAnimation { duration: 100 }
            NumberAnimation {
                target: root
                property: "introTabs"
                from: 0.0
                to: 1.0
                duration: 550
                easing.type: Easing.Linear
            }
        }
        SequentialAnimation {
            PauseAnimation { duration: 180 }
            NumberAnimation {
                target: root
                property: "introContent"
                from: 0.0
                to: 1.0
                duration: 650
                easing.type: Easing.OutCubic
            }
        }
    }

    SequentialAnimation {
        id: closeSequence
        ScriptAction {
            script: {
                root.closeSearch();
                if (root.chargingSoundHandle !== -1 && typeof Sounds !== "undefined") {
                    Sounds.stopSfx(root.chargingSoundHandle);
                    root.chargingSoundHandle = -1;
                }
            }
        }
        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "introContent"
                to: 0.0
                duration: 150
                easing.type: Easing.InExpo
            }
            NumberAnimation {
                target: root
                property: "introSidebar"
                to: 0.0
                duration: 150
                easing.type: Easing.InExpo
            }
            NumberAnimation {
                target: root
                property: "introTabs"
                to: 0.0
                duration: 120
                easing.type: Easing.InQuad
            }
        }
        NumberAnimation {
            target: root
            property: "introBase"
            to: 0.0
            duration: 200
            easing.type: Easing.InQuart
        }
        ScriptAction {
            script: {
                if (root.exitCallback) {
                    let cb = root.exitCallback;
                    root.exitCallback = null;
                    cb();
                } else {
                    Quickshell.execDetached(["bash", Caching.serpantinumDir + "/scripts/qs_manager.sh", "close"]);
                }
            }
        }
    }

    Item {
        anchors.fill: parent
        opacity: introBase
        scale: 0.95 + (0.05 * introBase)

        Rectangle {
            anchors.fill: parent
            radius: 0
            color: "#151515"

            McPanel {
                anchors.fill: parent
                bevel: Math.max(2, Math.round(Scaler.s(3)))
                fill: "#151515"
                light: "#3a3a3a"
                dark: "#070707"
            }

            property real time: 0
            NumberAnimation on time {
                from: 0
                to: Math.PI * 2
                duration: 20000
                loops: Animation.Infinite
                running: root.visible
            }

            GuideSidebar {
                id: sidebar
                popup: root
            }

            GuideContent {
                id: contentArea
                popup: root
                x: I18n.rtl ? 1 : (sidebar.width + 1)
                y: 4
                width: Math.max(0, parent.width - sidebar.width - 2)
                height: Math.max(0, parent.height - 8)
            }
        }
    }

    // Steve comes through a Nether portal and stands on the selected settings tab.
    SteveVisitor {
        anchors.fill: parent
        z: 100
        active: root.visible
        style: "nether"
        target: sidebar.activeHighlightItem
        px: Math.max(3, Math.round(Scaler.s(3)))
        phrases: ["Налаштуємо?", "Мені подобається ця тема", "Тицяй вкладки!", "Ой!", "Де тут кнопка «алмази»?"]
        onArrivedSignal: say("Налаштуємо?")
    }
}
