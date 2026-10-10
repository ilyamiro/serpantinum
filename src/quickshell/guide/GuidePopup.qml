import QtQuick
import QtQuick.Window
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../"
import "../reusables"
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
        if (!itemObj || !searchResultsFlickable) return;
        try {
            let mapped = itemObj.mapToItem(searchResultsCol, 0, 0);
            let itemY = mapped.y;
            let itemH = itemObj.height;
            let viewTop = searchResultsFlickable.contentY;
            let viewHeight = searchResultsFlickable.height;
            let viewBottom = viewTop + viewHeight;

            if (itemY < viewTop) {
                searchResultsFlickable.contentY = Math.max(0, itemY - root.s(8));
            } else if (itemY + itemH > viewBottom) {
                let maxScroll = Math.max(0, searchResultsFlickable.contentHeight - viewHeight);
                searchResultsFlickable.contentY = Math.min(maxScroll, itemY + itemH - viewHeight + root.s(8));
            }
        } catch(e) {}
    }

    function ensureTabVisible(idx) {
        if (!tabsFlickable || idx < 0 || !tabsRepeater || idx >= tabsRepeater.count) return;
        try {
            let item = tabsRepeater.itemAt(idx);
            if (!item) return;
            let itemY = item.y;
            let itemH = item.height;
            let viewTop = tabsFlickable.contentY;
            let viewHeight = tabsFlickable.height;
            let viewBottom = viewTop + viewHeight;

            if (itemY < viewTop) {
                tabsFlickable.contentY = Math.max(0, itemY - root.s(8));
            } else if (itemY + itemH > viewBottom) {
                let maxScroll = Math.max(0, tabsFlickable.contentHeight - viewHeight);
                tabsFlickable.contentY = Math.min(maxScroll, itemY + itemH - viewHeight + root.s(8));
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
            if (settingsSearchInput) {
                settingsSearchInput.forceInputFocus();
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
            if (settingsSearchInput) settingsSearchInput.text = "";
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
            if (settingsSearchInput) settingsSearchInput.text = "";
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
            radius: ThemeBackend.clampedBorderRadius
            color: ThemeBackend.base

            property real time: 0
            NumberAnimation on time {
                from: 0
                to: Math.PI * 2
                duration: 20000
                loops: Animation.Infinite
                running: root.visible
            }

            Rectangle {
                id: sidebar
                x: I18n.rtl ? (parent.width - width) : 0
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: root.searchActive ? root.s(340) : root.s(260)
                
                topLeftRadius: !I18n.rtl ? ThemeBackend.clampedBorderRadius : 0
                bottomLeftRadius: !I18n.rtl ? ThemeBackend.clampedBorderRadius : 0
                topRightRadius: I18n.rtl ? ThemeBackend.clampedBorderRadius : 0
                bottomRightRadius: I18n.rtl ? ThemeBackend.clampedBorderRadius : 0
                
                color: Qt.alpha(ThemeBackend.surface0, 0.4)
                opacity: introSidebar
                transform: Translate { x: (I18n.rtl ? root.s(30) : root.s(-30)) * (1.0 - introSidebar) }

                Behavior on width {
                    NumberAnimation {
                        id: sidebarWidthAnim
                        duration: 240
                        easing.type: Easing.OutCubic
                    }
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: root.s(16)
                    spacing: root.s(10)

                    Item {
                        id: searchHeader
                        Layout.fillWidth: true
                        implicitHeight: root.s(36)
                        Layout.preferredHeight: root.s(36)

                        Text {
                            id: settingsTitleText
                            x: I18n.rtl ? (parent.width - width) : 0
                            anchors.verticalCenter: parent.verticalCenter
                            horizontalAlignment: I18n.textAlignment
                            text: I18n.t("guide.settings", "Settings")
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: root.s(15)
                            font.bold: true
                            color: ThemeBackend.text
                            opacity: root.searchActive ? 0.0 : 1.0
                            scale: root.searchActive ? 0.92 : 1.0
                            visible: opacity > 0.001

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 180
                                    easing.type: Easing.OutCubic
                                }
                            }
                            Behavior on scale {
                                NumberAnimation {
                                    duration: 220
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }

                        Item {
                            id: searchMorphBox
                            property real openProgress: root.searchActive ? 1.0 : 0.0
                            Behavior on openProgress { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

                            x: I18n.rtl ? 0 : (parent.width - width)
                            anchors.verticalCenter: parent.verticalCenter
                            width: root.s(36) + (parent.width - root.s(36)) * openProgress
                            height: root.s(36)
                            clip: true

                            Input {
                                id: settingsSearchInput
                                anchors.fill: parent
                                implicitHeight: root.s(36)
                                placeholderText: I18n.t("guide.search.placeholder", "Search settings...")
                                fontPixelSize: root.s(12)
                                baseColor: Qt.alpha(ThemeBackend.surface0, 0.7)
                                accentColor: ThemeBackend.mauve
                                textColor: ThemeBackend.text
                                subTextColor: ThemeBackend.subtext0
                                borderColor: Qt.alpha(ThemeBackend.surface2, 0.5)
                                cornerRadius: ThemeBackend.borderRadius
                                opacity: root.searchActive ? 1.0 : 0.0
                                visible: opacity > 0.001
                                enabled: root.searchActive

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: 180
                                        easing.type: Easing.OutCubic
                                    }
                                }

                                onTextEdited: (txt) => {
                                    root.searchQuery = txt;
                                    root.searchSelectedIndex = -1;
                                }

                                Keys.onEscapePressed: (event) => {
                                    root.closeSearch();
                                    event.accepted = true;
                                }
                                Keys.onDownPressed: (event) => {
                                    root.navigateSearch(1);
                                    event.accepted = true;
                                }
                                Keys.onUpPressed: (event) => {
                                    root.navigateSearch(-1);
                                    event.accepted = true;
                                }
                                Keys.onReturnPressed: (event) => {
                                    root.activateSelectedSearch();
                                    event.accepted = true;
                                }
                                Keys.onEnterPressed: (event) => {
                                    root.activateSelectedSearch();
                                    event.accepted = true;
                                }
                            }

                            IconButton {
                                id: closeSearchBtn
                                anchors.right: parent.right
                                anchors.rightMargin: root.s(4)
                                anchors.verticalCenter: parent.verticalCenter
                                size: root.s(28)
                                cornerRadius: root.s(6)
                                buttonIcon: "󰅖"
                                iconFontSize: root.s(14)
                                accentColor: "transparent"
                                textColor: ThemeBackend.subtext0
                                visible: opacity > 0.001
                                opacity: root.searchActive ? 1.0 : 0.0
                                enabled: root.searchActive
                                z: 3

                                Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                                onClicked: root.closeSearch()
                            }

                            IconButton {
                                id: searchBtn
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                width: root.s(36)
                                size: root.s(36)
                                cornerRadius: ThemeBackend.borderRadius
                                buttonIcon: "󰍉"
                                iconFontSize: root.s(16)
                                accentColor: Qt.alpha(ThemeBackend.surface0, 0.7)
                                textColor: ThemeBackend.text
                                visible: opacity > 0.001
                                opacity: root.searchActive ? 0.0 : 1.0
                                enabled: !root.searchActive

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: 180
                                        easing.type: Easing.OutCubic
                                    }
                                }

                                onClicked: {
                                    root.openSearch();
                                }
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        Flickable {
                            id: searchResultsFlickable
                            anchors.fill: parent
                            visible: opacity > 0.001
                            opacity: root.searchActive ? 1.0 : 0.0
                            contentHeight: searchResultsCol.implicitHeight + root.s(10)
                            contentWidth: width
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds

                            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                            ScrollBar.vertical: ScrollBar {
                                active: searchResultsFlickable.moving || searchResultsFlickable.movingVertically
                                width: root.s(4)
                                policy: ScrollBar.AsNeeded
                                contentItem: Rectangle {
                                    implicitWidth: root.s(4)
                                    radius: root.s(2)
                                    color: ThemeBackend.surface2
                                }
                            }

                            ColumnLayout {
                                id: searchResultsCol
                                width: parent.width
                                spacing: root.s(8)

                                Text {
                                    visible: root.searchActive && root.searchQuery.trim() === ""
                                    Layout.fillWidth: true
                                    Layout.topMargin: root.s(24)
                                    horizontalAlignment: Text.AlignHCenter
                                    text: I18n.t("guide.search.prompt", "Type to search settings...")
                                    font.family: ThemeBackend.fontFamily
                                    font.pixelSize: root.s(12)
                                    color: ThemeBackend.subtext0
                                }

                                Text {
                                    visible: root.searchActive && root.searchQuery.trim() !== "" && root.filteredSearchResults.length === 0
                                    Layout.fillWidth: true
                                    Layout.topMargin: root.s(24)
                                    horizontalAlignment: Text.AlignHCenter
                                    text: I18n.t("guide.search.no_results", "No settings found")
                                    font.family: ThemeBackend.fontFamily
                                    font.pixelSize: root.s(12)
                                    color: ThemeBackend.subtext0
                                }

                                Repeater {
                                    id: searchTabsRepeater
                                    model: root.groupedSearchResults
                                    delegate: ColumnLayout {
                                        id: tabGroup
                                        required property var modelData
                                        required property int index

                                        Layout.fillWidth: true
                                        spacing: root.s(4)

                                        Rectangle {
                                            id: tabHeaderItem
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: root.s(44)
                                            implicitHeight: root.s(44)
                                            radius: ThemeBackend.borderRadius
                                            z: 1

                                            color: tabHeaderItemMa.containsMouse ? Qt.alpha(ThemeBackend.surface1, 0.5) : "transparent"
                                            Behavior on color { ColorAnimation { duration: 150 } }

                                            scale: tabHeaderItemMa.pressed ? 0.98 : 1.0
                                            Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: root.s(10)
                                                anchors.rightMargin: root.s(14)
                                                spacing: root.s(10)

                                                IconButton {
                                                    enabled: false
                                                    size: root.s(32)
                                                    Layout.preferredWidth: root.s(32)
                                                    Layout.preferredHeight: root.s(32)
                                                    Layout.alignment: Qt.AlignVCenter
                                                    cornerRadius: ThemeBackend.borderRadius
                                                    buttonIcon: tabGroup.modelData.icon || "󰒓"
                                                    iconOffsetX: tabGroup.modelData.iconOffsetX ?? 0
                                                    iconFontSize: root.s(16)
                                                    accentColor: ThemeBackend.surface0
                                                    textColor: "#ffffff"
                                                }

                                                Text {
                                                    text: tabGroup.modelData.title
                                                    font.family: ThemeBackend.fontFamily
                                                    font.weight: Font.Medium
                                                    font.pixelSize: root.s(13)
                                                    color: tabHeaderItemMa.containsMouse ? ThemeBackend.text : ThemeBackend.subtext0
                                                    Layout.fillWidth: true
                                                    Layout.alignment: Qt.AlignVCenter
                                                    elide: Text.ElideRight
                                                    Behavior on color { ColorAnimation { duration: 150 } }
                                                }
                                            }

                                            MouseArea {
                                                id: tabHeaderItemMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    root.gotoTab(tabGroup.modelData.tabKey);
                                                    root.closeSearch();
                                                }
                                            }
                                        }

                                        RowLayout {
                                            id: tabIndentRow
                                            visible: (tabGroup.modelData.directItems.length + tabGroup.modelData.subgroups.length) > 0
                                            Layout.fillWidth: true
                                            spacing: root.s(6)

                                            Item {
                                                Layout.preferredWidth: root.s(20)
                                                Layout.fillHeight: true

                                                Rectangle {
                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                    anchors.top: parent.top
                                                    anchors.bottom: parent.bottom
                                                    anchors.topMargin: root.s(2)
                                                    anchors.bottomMargin: root.s(2)
                                                    width: Math.max(1, root.s(2))
                                                    radius: root.s(1)
                                                    color: Qt.rgba(ThemeBackend.surface2.r, ThemeBackend.surface2.g, ThemeBackend.surface2.b, 0.7)
                                                }
                                            }

                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: root.s(4)

                                                Repeater {
                                                    id: directItemsRepeater
                                                    model: tabGroup.modelData.directItems
                                                    delegate: Rectangle {
                                                        id: directItemRow
                                                        required property var modelData
                                                        required property int index

                                                        property bool isSelected: root.searchSelectedIndex >= 0 &&
                                                                                  root.searchSelectedIndex < root.flatSearchResults.length &&
                                                                                  (root.flatSearchResults[root.searchSelectedIndex] === directItemRow.modelData ||
                                                                                   (root.flatSearchResults[root.searchSelectedIndex] && root.flatSearchResults[root.searchSelectedIndex].key === directItemRow.modelData.key) ||
                                                                                   (root.flatSearchResults[root.searchSelectedIndex] && root.flatSearchResults[root.searchSelectedIndex].id === directItemRow.modelData.id))

                                                        onIsSelectedChanged: {
                                                            if (isSelected) {
                                                                root.ensureSearchItemVisible(directItemRow);
                                                            }
                                                        }

                                                        Layout.fillWidth: true
                                                        implicitHeight: (directItemRow.modelData && (directItemRow.modelData.desc || directItemRow.modelData.description)) ? root.s(48) : root.s(38)
                                                        radius: ThemeBackend.borderRadius
                                                        color: directItemRow.isSelected
                                                            ? ThemeBackend.mauve
                                                            : (directItemMa.containsMouse ? Qt.alpha(ThemeBackend.surface1, 0.6) : Qt.alpha(ThemeBackend.surface0, 0.35))
                                                        border.color: "transparent"

                                                        Behavior on color { ColorAnimation { duration: 150 } }

                                                        MouseArea {
                                                            id: directItemMa
                                                            anchors.fill: parent
                                                            hoverEnabled: true
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: root.selectSearchResult(directItemRow.modelData)
                                                        }

                                                        RowLayout {
                                                            anchors.fill: parent
                                                            anchors.leftMargin: root.s(8) + (directItemRow.isSelected ? root.s(4) : 0)
                                                            anchors.rightMargin: root.s(8)
                                                            anchors.topMargin: root.s(6)
                                                            anchors.bottomMargin: root.s(6)
                                                            spacing: root.s(8)

                                                            Behavior on anchors.leftMargin { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }

                                                            IconButton {
                                                                enabled: false
                                                                size: root.s(28)
                                                                Layout.preferredWidth: root.s(28)
                                                                Layout.preferredHeight: root.s(28)
                                                                Layout.alignment: Qt.AlignVCenter
                                                                cornerRadius: root.s(6)
                                                                buttonIcon: directItemRow.modelData.icon || "󰒓"
                                                                iconFontSize: root.s(14)
                                                                accentColor: ThemeBackend.surface0
                                                                textColor: "#ffffff"
                                                            }

                                                            ColumnLayout {
                                                                Layout.fillWidth: true
                                                                Layout.alignment: Qt.AlignVCenter
                                                                spacing: 0

                                                                Text {
                                                                    Layout.fillWidth: true
                                                                    text: root.resolveI18nText(directItemRow.modelData.title)
                                                                    font.family: ThemeBackend.fontFamily
                                                                    font.pixelSize: root.s(12)
                                                                    font.bold: true
                                                                    color: directItemRow.isSelected ? ThemeBackend.crust : ThemeBackend.text
                                                                    elide: Text.ElideRight

                                                                    Behavior on color { ColorAnimation { duration: 150 } }
                                                                }

                                                                Text {
                                                                    Layout.fillWidth: true
                                                                    text: root.resolveI18nText(directItemRow.modelData.desc || directItemRow.modelData.description || "")
                                                                    visible: text !== ""
                                                                    font.family: ThemeBackend.fontFamily
                                                                    font.pixelSize: root.s(10)
                                                                    color: directItemRow.isSelected ? Qt.alpha(ThemeBackend.crust, 0.75) : ThemeBackend.subtext0
                                                                    elide: Text.ElideRight

                                                                    Behavior on color { ColorAnimation { duration: 150 } }
                                                                }
                                                            }
                                                        }
                                                    }
                                                }

                                                Repeater {
                                                    id: subGroupRepeater
                                                    model: tabGroup.modelData.subgroups
                                                    delegate: ColumnLayout {
                                                        id: subGroup
                                                        required property var modelData
                                                        required property int index

                                                        Layout.fillWidth: true
                                                        spacing: root.s(4)

                                                        Rectangle {
                                                            id: subtabHeaderItem
                                                            Layout.fillWidth: true
                                                            Layout.preferredHeight: root.s(36)
                                                            implicitHeight: root.s(36)
                                                            radius: ThemeBackend.borderRadius
                                                            z: 1

                                                            color: subtabHeaderItemMa.containsMouse ? Qt.alpha(ThemeBackend.surface1, 0.5) : "transparent"
                                                            Behavior on color { ColorAnimation { duration: 150 } }

                                                            scale: subtabHeaderItemMa.pressed ? 0.98 : 1.0
                                                            Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }

                                                            RowLayout {
                                                                anchors.fill: parent
                                                                anchors.leftMargin: root.s(8)
                                                                anchors.rightMargin: root.s(10)
                                                                spacing: root.s(8)

                                                                IconButton {
                                                                    enabled: false
                                                                    size: root.s(26)
                                                                    Layout.preferredWidth: root.s(26)
                                                                    Layout.preferredHeight: root.s(26)
                                                                    Layout.alignment: Qt.AlignVCenter
                                                                    cornerRadius: ThemeBackend.borderRadius
                                                                    buttonIcon: subGroup.modelData.icon || "󰒓"
                                                                    iconOffsetX: subGroup.modelData.iconOffsetX ?? 0
                                                                    iconFontSize: root.s(13)
                                                                    accentColor: ThemeBackend.surface0
                                                                    textColor: "#ffffff"
                                                                }

                                                                Text {
                                                                    text: subGroup.modelData.title
                                                                    font.family: ThemeBackend.fontFamily
                                                                    font.weight: Font.Medium
                                                                    font.pixelSize: root.s(12)
                                                                    color: subtabHeaderItemMa.containsMouse ? ThemeBackend.text : ThemeBackend.subtext0
                                                                    Layout.fillWidth: true
                                                                    Layout.alignment: Qt.AlignVCenter
                                                                    elide: Text.ElideRight
                                                                    Behavior on color { ColorAnimation { duration: 150 } }
                                                                }
                                                            }

                                                            MouseArea {
                                                                id: subtabHeaderItemMa
                                                                anchors.fill: parent
                                                                hoverEnabled: true
                                                                cursorShape: Qt.PointingHandCursor
                                                                onClicked: {
                                                                    root.gotoTab(tabGroup.modelData.tabKey, subGroup.modelData.subKey);
                                                                    root.closeSearch();
                                                                }
                                                            }
                                                        }

                                                        RowLayout {
                                                            id: subIndentRow
                                                            visible: subGroup.modelData.items.length > 0
                                                            Layout.fillWidth: true
                                                            spacing: root.s(6)

                                                            Item {
                                                                Layout.preferredWidth: root.s(20)
                                                                Layout.fillHeight: true

                                                                Rectangle {
                                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                                    anchors.top: parent.top
                                                                    anchors.bottom: parent.bottom
                                                                    anchors.topMargin: root.s(2)
                                                                    anchors.bottomMargin: root.s(2)
                                                                    width: Math.max(1, root.s(2))
                                                                    radius: root.s(1)
                                                                    color: Qt.rgba(ThemeBackend.surface2.r, ThemeBackend.surface2.g, ThemeBackend.surface2.b, 0.7)
                                                                }
                                                            }

                                                            ColumnLayout {
                                                                Layout.fillWidth: true
                                                                spacing: root.s(4)

                                                                Repeater {
                                                                    id: subGroupItemsRepeater
                                                                    model: subGroup.modelData.items
                                                                    delegate: Rectangle {
                                                                        id: subItemRow
                                                                        required property var modelData
                                                                        required property int index

                                                                        property bool isSelected: root.searchSelectedIndex >= 0 &&
                                                                                                  root.searchSelectedIndex < root.flatSearchResults.length &&
                                                                                                  (root.flatSearchResults[root.searchSelectedIndex] === subItemRow.modelData ||
                                                                                                   (root.flatSearchResults[root.searchSelectedIndex] && root.flatSearchResults[root.searchSelectedIndex].key === subItemRow.modelData.key) ||
                                                                                                   (root.flatSearchResults[root.searchSelectedIndex] && root.flatSearchResults[root.searchSelectedIndex].id === subItemRow.modelData.id))

                                                                        onIsSelectedChanged: {
                                                                            if (isSelected) {
                                                                                root.ensureSearchItemVisible(subItemRow);
                                                                            }
                                                                        }

                                                                        Layout.fillWidth: true
                                                                        implicitHeight: (subItemRow.modelData && (subItemRow.modelData.desc || subItemRow.modelData.description)) ? root.s(48) : root.s(38)
                                                                        radius: ThemeBackend.borderRadius
                                                                        color: subItemRow.isSelected
                                                                            ? ThemeBackend.mauve
                                                                            : (subItemMa.containsMouse ? Qt.alpha(ThemeBackend.surface1, 0.6) : Qt.alpha(ThemeBackend.surface0, 0.35))
                                                                        border.color: "transparent"

                                                                        Behavior on color { ColorAnimation { duration: 150 } }

                                                                        MouseArea {
                                                                            id: subItemMa
                                                                            anchors.fill: parent
                                                                            hoverEnabled: true
                                                                            cursorShape: Qt.PointingHandCursor
                                                                            onClicked: root.selectSearchResult(subItemRow.modelData)
                                                                        }

                                                                        RowLayout {
                                                                            anchors.fill: parent
                                                                            anchors.leftMargin: root.s(8) + (subItemRow.isSelected ? root.s(4) : 0)
                                                                            anchors.rightMargin: root.s(8)
                                                                            anchors.topMargin: root.s(6)
                                                                            anchors.bottomMargin: root.s(6)
                                                                            spacing: root.s(8)

                                                                            Behavior on anchors.leftMargin { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }

                                                                            IconButton {
                                                                                enabled: false
                                                                                size: root.s(28)
                                                                                Layout.preferredWidth: root.s(28)
                                                                                Layout.preferredHeight: root.s(28)
                                                                                Layout.alignment: Qt.AlignVCenter
                                                                                cornerRadius: root.s(6)
                                                                                buttonIcon: subItemRow.modelData.icon || "󰒓"
                                                                                iconFontSize: root.s(14)
                                                                                accentColor: ThemeBackend.surface0
                                                                                textColor: "#ffffff"
                                                                            }

                                                                            ColumnLayout {
                                                                                Layout.fillWidth: true
                                                                                Layout.alignment: Qt.AlignVCenter
                                                                                spacing: 0

                                                                                Text {
                                                                                    Layout.fillWidth: true
                                                                                    text: root.resolveI18nText(subItemRow.modelData.title)
                                                                                    font.family: ThemeBackend.fontFamily
                                                                                    font.pixelSize: root.s(12)
                                                                                    font.bold: true
                                                                                    color: subItemRow.isSelected ? ThemeBackend.crust : ThemeBackend.text
                                                                                    elide: Text.ElideRight

                                                                                    Behavior on color { ColorAnimation { duration: 150 } }
                                                                                }

                                                                                Text {
                                                                                    Layout.fillWidth: true
                                                                                    text: root.resolveI18nText(subItemRow.modelData.desc || subItemRow.modelData.description || "")
                                                                                    visible: text !== ""
                                                                                    font.family: ThemeBackend.fontFamily
                                                                                    font.pixelSize: root.s(10)
                                                                                    color: subItemRow.isSelected ? Qt.alpha(ThemeBackend.crust, 0.75) : ThemeBackend.subtext0
                                                                                    elide: Text.ElideRight

                                                                                    Behavior on color { ColorAnimation { duration: 150 } }
                                                                                }
                                                                            }
                                                                        }
                                                                    }
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Flickable {
                            id: tabsFlickable
                            anchors.fill: parent
                            visible: opacity > 0.001
                            opacity: root.searchActive ? 0.0 : 1.0
                            contentHeight: tabsCol.implicitHeight + root.s(20)
                            contentWidth: width
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds

                            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                            ScrollBar.vertical: ScrollBar {
                                active: tabsFlickable.moving || tabsFlickable.movingVertically
                                width: root.s(4)
                                policy: ScrollBar.AsNeeded
                                contentItem: Rectangle {
                                    implicitWidth: root.s(4)
                                    radius: root.s(2)
                                    color: ThemeBackend.surface2
                                }
                            }

                            Rectangle {
                                id: activeHighlight
                                z: 0
                                visible: !root.searchActive || opacity > 0.001
                                radius: ThemeBackend.borderRadius
                                color: ThemeBackend.mauve

                                property Item activeGroupItem: (root.currentTab >= 0 && tabsRepeater && root.currentTab < tabsRepeater.count) ? tabsRepeater.itemAt(root.currentTab) : null
                                property bool isSubActive: root.currentTab === root.expandedTab && root.expandedTab !== -1

                                property real targetX: isSubActive ? (I18n.rtl ? 0 : root.s(26)) : 0
                                property real targetY: {
                                    let baseY = activeGroupItem ? activeGroupItem.y : (root.currentTab * (root.s(44) + root.s(4)));
                                    if (isSubActive) {
                                        return baseY + root.s(44) + root.s(4) + root.currentSubTab * (root.s(36) + root.s(4));
                                    }
                                    return baseY;
                                }
                                property real targetW: isSubActive ? (tabsCol.width - root.s(26)) : tabsCol.width
                                property real targetH: isSubActive ? root.s(36) : root.s(44)

                                x: targetX
                                y: targetY
                                width: targetW
                                height: targetH

                                opacity: root.getTabOpacity(root.currentTab)
                                transform: Translate { x: (I18n.rtl ? root.s(24) : root.s(-24)) * (1.0 - root.getTabProgress(root.currentTab)) }

                                Behavior on x { enabled: !sidebarWidthAnim.running; NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }
                                Behavior on y { enabled: !sidebarWidthAnim.running; NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }
                                Behavior on width { enabled: !sidebarWidthAnim.running; NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }
                                Behavior on height { enabled: !sidebarWidthAnim.running; NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }
                            }

                            ColumnLayout {
                                id: tabsCol
                                width: tabsFlickable.width - (tabsFlickable.contentHeight > tabsFlickable.height ? root.s(6) : 0)
                                spacing: root.s(4)

                                readonly property var tabItems: tabsRepeater

                                Repeater {
                                    id: tabsRepeater
                                    model: root.tabsModel
                                    delegate: ColumnLayout {
                                        id: tabDelegate
                                        required property var modelData
                                        required property int index

                                        readonly property int tabIndex: index
                                        readonly property bool hasSubtabs: Boolean(modelData.subtabs && modelData.subtabs.length > 0)
                                        readonly property bool isExpanded: hasSubtabs && root.expandedTab === tabIndex
                                        readonly property real fullSubtabsHeight: hasSubtabs ? (modelData.subtabs.length * root.s(36) + (modelData.subtabs.length - 1) * root.s(4) + root.s(8)) : 0
                                        property real expandProgress: isExpanded ? 1.0 : 0.0

                                        Behavior on expandProgress {
                                            NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
                                        }

                                        Layout.fillWidth: true
                                        spacing: 0

                                        opacity: root.getTabOpacity(tabIndex)
                                        transform: Translate { x: root.s(-24) * (1.0 - root.getTabProgress(tabIndex)) }

                                        Rectangle {
                                            id: tabHeaderItem
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: root.s(44)
                                            implicitHeight: root.s(44)
                                            radius: ThemeBackend.borderRadius
                                            z: 1

                                            property bool isDirectActive: tabDelegate.hasSubtabs ? (root.currentTab === tabDelegate.tabIndex && !tabDelegate.isExpanded) : (root.currentTab === tabDelegate.tabIndex)

                                            color: tabHeaderMa.containsMouse && !isDirectActive ? Qt.alpha(ThemeBackend.surface1, 0.5) : "transparent"
                                            Behavior on color { ColorAnimation { duration: 150 } }

                                            scale: tabHeaderMa.pressed ? 0.98 : 1.0
                                            Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }

                                            RowLayout {
                                                layoutDirection: I18n.layoutDirection
                                                anchors.fill: parent
                                                anchors.leftMargin: I18n.rtl ? root.s(14) : (root.s(10) + (tabHeaderItem.isDirectActive ? root.s(4) : 0))
                                                anchors.rightMargin: I18n.rtl ? (root.s(10) + (tabHeaderItem.isDirectActive ? root.s(4) : 0)) : root.s(14)
                                                spacing: root.s(10)

                                                Behavior on anchors.leftMargin { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }
                                                Behavior on anchors.rightMargin { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }

                                                IconButton {
                                                    enabled: false
                                                    size: root.s(32)
                                                    Layout.preferredWidth: root.s(32)
                                                    Layout.preferredHeight: root.s(32)
                                                    Layout.alignment: Qt.AlignVCenter
                                                    cornerRadius: ThemeBackend.borderRadius
                                                    buttonIcon: tabDelegate.modelData.icon || "󰒓"
                                                    iconOffsetX: tabDelegate.modelData.iconOffsetX ?? 0
                                                    iconFontSize: root.s(16)
                                                    accentColor: ThemeBackend.surface0
                                                    textColor: "#ffffff"
                                                }

                                                Text {
                                                    text: I18n.t("guide.tabs." + (tabDelegate.modelData.key || tabDelegate.modelData.id).toLowerCase(), tabDelegate.modelData.name || tabDelegate.modelData.id)
                                                    font.family: ThemeBackend.fontFamily
                                                    font.weight: tabHeaderItem.isDirectActive ? Font.Bold : Font.Medium
                                                    font.pixelSize: root.s(13)
                                                    color: tabHeaderItem.isDirectActive 
                                                        ? ThemeBackend.crust 
                                                        : (tabHeaderMa.containsMouse ? ThemeBackend.text : ThemeBackend.subtext0)
                                                    Layout.fillWidth: true
                                                    Layout.alignment: Qt.AlignVCenter
                                                    horizontalAlignment: I18n.textAlignment
                                                    elide: Text.ElideRight
                                                    Behavior on color { ColorAnimation { duration: 150 } }
                                                }

                                                Text {
                                                    visible: tabDelegate.hasSubtabs
                                                    text: "󰅀"
                                                    font.family: ThemeBackend.iconFont
                                                    font.pixelSize: root.s(14)
                                                    color: tabHeaderItem.isDirectActive 
                                                        ? ThemeBackend.crust 
                                                        : (tabHeaderMa.containsMouse ? ThemeBackend.text : ThemeBackend.subtext0)
                                                    Layout.alignment: Qt.AlignVCenter
                                                    rotation: tabDelegate.expandProgress * 180 - 180
                                                    Behavior on rotation { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                                                    Behavior on color { ColorAnimation { duration: 150 } }
                                                }
                                            }

                                            MouseArea {
                                                id: tabHeaderMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (tabDelegate.hasSubtabs) {
                                                        if (root.expandedTab === tabDelegate.tabIndex) {
                                                            root.expandedTab = -1;
                                                        } else {
                                                            root.expandedTab = tabDelegate.tabIndex;
                                                            if (root.currentTab !== tabDelegate.tabIndex) {
                                                                root.currentTab = tabDelegate.tabIndex;
                                                                root.currentSubTab = 0;
                                                            }
                                                        }
                                                    } else {
                                                        root.expandedTab = -1;
                                                        root.currentTab = tabDelegate.tabIndex;
                                                        root.currentSubTab = 0;
                                                    }
                                                }
                                            }
                                        }

                                        Item {
                                            id: subtabsWrapper
                                            visible: tabDelegate.hasSubtabs && tabDelegate.expandProgress > 0.001
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: tabDelegate.fullSubtabsHeight * tabDelegate.expandProgress
                                            implicitHeight: tabDelegate.fullSubtabsHeight * tabDelegate.expandProgress
                                            opacity: Math.max(0.0, (tabDelegate.expandProgress - 0.15) / 0.85)
                                            clip: true

                                            RowLayout {
                                                layoutDirection: I18n.layoutDirection
                                                anchors.fill: parent
                                                anchors.topMargin: root.s(4)
                                                anchors.bottomMargin: root.s(4)
                                                spacing: root.s(6)

                                                Item {
                                                    Layout.preferredWidth: root.s(20)
                                                    Layout.fillHeight: true

                                                    Rectangle {
                                                        anchors.horizontalCenter: parent.horizontalCenter
                                                        anchors.top: parent.top
                                                        anchors.bottom: parent.bottom
                                                        anchors.topMargin: root.s(2)
                                                        anchors.bottomMargin: root.s(2)
                                                        width: Math.max(1, root.s(2))
                                                        radius: root.s(1)
                                                        color: Qt.rgba(ThemeBackend.surface2.r, ThemeBackend.surface2.g, ThemeBackend.surface2.b, 0.7)
                                                    }
                                                }

                                                ColumnLayout {
                                                    Layout.fillWidth: true
                                                    spacing: root.s(4)

                                                    Repeater {
                                                        model: tabDelegate.hasSubtabs ? tabDelegate.modelData.subtabs : []
                                                        delegate: Rectangle {
                                                            id: subtabItem
                                                            required property var modelData
                                                            required property int index

                                                            readonly property int subIndex: index
                                                            readonly property int parentIndex: tabDelegate.tabIndex

                                                            Layout.fillWidth: true
                                                            Layout.preferredHeight: root.s(36)
                                                            implicitHeight: root.s(36)
                                                            radius: ThemeBackend.borderRadius
                                                            z: 1

                                                            property bool isSubActive: root.currentTab === parentIndex && root.expandedTab === parentIndex && root.currentSubTab === subIndex

                                                            color: subtabMa.containsMouse && !isSubActive ? Qt.alpha(ThemeBackend.surface1, 0.5) : "transparent"
                                                            Behavior on color { ColorAnimation { duration: 150 } }

                                                            scale: subtabMa.pressed ? 0.98 : 1.0
                                                            Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }

                                                            RowLayout {
                                                                layoutDirection: I18n.layoutDirection
                                                                anchors.fill: parent
                                                                anchors.leftMargin: I18n.rtl ? root.s(10) : (root.s(8) + (subtabItem.isSubActive ? root.s(4) : 0))
                                                                anchors.rightMargin: I18n.rtl ? (root.s(8) + (subtabItem.isSubActive ? root.s(4) : 0)) : root.s(10)
                                                                spacing: root.s(8)

                                                                Behavior on anchors.leftMargin { NumberAnimation { duration: 300; easing.type: Easing.OutQuint } }
                                                                Behavior on anchors.rightMargin { NumberAnimation { duration: 300; easing.type: Easing.OutQuint } }

                                                                IconButton {
                                                                    enabled: false
                                                                    size: root.s(26)
                                                                    Layout.preferredWidth: root.s(26)
                                                                    Layout.preferredHeight: root.s(26)
                                                                    Layout.alignment: Qt.AlignVCenter
                                                                    cornerRadius: ThemeBackend.borderRadius
                                                                    buttonIcon: subtabItem.modelData.icon || "󰒓"
                                                                    iconOffsetX: subtabItem.modelData.iconOffsetX ?? 0
                                                                    iconFontSize: root.s(13)
                                                                    accentColor: ThemeBackend.surface0
                                                                    textColor: "#ffffff"
                                                                }

                                                                Text {
                                                                    text: I18n.t("guide.tabs." + (subtabItem.modelData.key || subtabItem.modelData.id).toLowerCase(), subtabItem.modelData.name || subtabItem.modelData.id)
                                                                    font.family: ThemeBackend.fontFamily
                                                                    font.weight: subtabItem.isSubActive ? Font.Bold : Font.Medium
                                                                    font.pixelSize: root.s(12)
                                                                    color: subtabItem.isSubActive ? ThemeBackend.crust : ThemeBackend.subtext0
                                                                    Layout.fillWidth: true
                                                                    Layout.alignment: Qt.AlignVCenter
                                                                    horizontalAlignment: I18n.textAlignment
                                                                    elide: Text.ElideRight
                                                                    Behavior on color { ColorAnimation { duration: 150 } }
                                                                }
                                                            }

                                                            MouseArea {
                                                                id: subtabMa
                                                                anchors.fill: parent
                                                                hoverEnabled: true
                                                                cursorShape: Qt.PointingHandCursor
                                                                onClicked: {
                                                                    root.currentTab = parentIndex;
                                                                    root.expandedTab = parentIndex;
                                                                    root.currentSubTab = subIndex;
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    ClickButton {
                        visible: Updater.updateAvailable && !root.searchActive
                        Layout.fillWidth: true
                        implicitHeight: root.s(38)
                        cornerRadius: ThemeBackend.borderRadius
                        buttonText: I18n.t("guide.update_available")
                        buttonIcon: "󰚰"
                        iconFontSize: root.s(16)
                        textFontSize: root.s(13)
                        accentColor: ThemeBackend.green
                        textColor: ThemeBackend.crust
                        opacity: root.getTabOpacity(root.tabsModel.length)
                        transform: Translate { x: root.s(-24) * (1.0 - root.getTabProgress(root.tabsModel.length)) }
                        onClicked: {
                            root.gotoTab("about");
                        }
                    }
                }
            }

            Item {
                id: contentArea
                x: I18n.rtl ? 1 : (sidebar.width + 1)
                y: 4
                width: Math.max(0, parent.width - sidebar.width - 2)
                height: Math.max(0, parent.height - 8)

                opacity: introContent
                scale: 0.95 + (0.05 * introContent)
                transform: Translate { y: root.s(20) * (1.0 - introContent) }

                Repeater {
                    id: contentRepeater
                    model: root.tabsModel
                    delegate: Item {
                        id: tabContentWrapper
                        anchors.fill: parent

                        property int parentTabIndex: index
                        property int tabIndex: parentTabIndex
                        property var tabData: modelData
                        property bool hasSubtabs: Boolean(tabData.subtabs && tabData.subtabs.length > 0)
                        property alias singleLoader: singleTabLoader
                        property alias subLoadersRepeater: subRepeat

                        property bool isCurrent: root.currentTab === parentTabIndex
                        visible: isCurrent || opacity > 0.001
                        opacity: isCurrent ? 1.0 : 0.0
                        property real animY: isCurrent ? 0 : root.s(10)
                        transform: Translate { y: tabContentWrapper.animY }

                        Behavior on opacity {
                            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                        }
                        Behavior on animY {
                            NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
                        }

                        Loader {
                            id: singleTabLoader
                            anchors.fill: parent
                            asynchronous: false
                            active: !tabContentWrapper.hasSubtabs
                            visible: !tabContentWrapper.hasSubtabs && tabContentWrapper.visible
                            property int tabIndex: tabContentWrapper.parentTabIndex
                            property int subTabIndex: -1

                            function ensureLoaded() {
                                if (status === Loader.Null && tabData.file) {
                                    setSource(tabData.file, {
                                        "rootObj": root,
                                        "tabIndex": tabContentWrapper.parentTabIndex
                                    });
                                }
                            }

                            onStatusChanged: {
                                if (status === Loader.Error) {
                                    console.warn("Guide tab failed to load:", source);
                                }
                            }

                            onLoaded: {
                                root.registerTabSearchItems(item);
                                Qt.callLater(function() {
                                    root.registerTabSearchItems(singleTabLoader.item);
                                });
                            }

                            Component.onCompleted: ensureLoaded()

                            Connections {
                                target: root
                                function onCurrentTabChanged() {
                                    if (root.currentTab === tabContentWrapper.parentTabIndex && !tabContentWrapper.hasSubtabs) singleTabLoader.ensureLoaded();
                                }
                                function onRequestLoadAll() {
                                    singleTabLoader.ensureLoaded();
                                }
                            }

                            Connections {
                                target: singleTabLoader.item
                                ignoreUnknownSignals: true
                                function onSearchItemsChanged() {
                                    root.registerTabSearchItems(singleTabLoader.item);
                                }
                                function onSearchEntriesChanged() {
                                    root.registerTabSearchItems(singleTabLoader.item);
                                }
                            }
                        }

                        Repeater {
                            id: subRepeat
                            model: tabContentWrapper.hasSubtabs ? tabData.subtabs : []

                            delegate: Loader {
                                id: subTabLoader
                                anchors.fill: parent
                                asynchronous: false
                                property int subIndex: index
                                property int tabIndex: tabContentWrapper.parentTabIndex
                                property int subTabIndex: subIndex
                                property var subData: modelData

                                property bool isSubCurrent: root.currentTab === tabContentWrapper.parentTabIndex && root.currentSubTab === subIndex
                                visible: isSubCurrent || opacity > 0.001
                                opacity: isSubCurrent ? 1.0 : 0.0
                                property real subAnimY: isSubCurrent ? 0 : root.s(10)
                                transform: Translate { y: subTabLoader.subAnimY }

                                Behavior on opacity {
                                    NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                                }
                                Behavior on subAnimY {
                                    NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
                                }

                                function ensureLoaded() {
                                    if (status === Loader.Null && subData.file) {
                                        setSource(subData.file, {
                                            "rootObj": root,
                                            "tabIndex": tabContentWrapper.parentTabIndex
                                        });
                                        if (item && item.subTabIndex !== undefined) {
                                            item.subTabIndex = subIndex;
                                        }
                                    }
                                }

                                onStatusChanged: {
                                    if (status === Loader.Error) {
                                        console.warn("Guide tab failed to load:", source);
                                    }
                                }

                                onLoaded: {
                                    if (item && item.subTabIndex !== undefined) {
                                        item.subTabIndex = subIndex;
                                    }
                                    root.registerTabSearchItems(item);
                                    Qt.callLater(function() {
                                        root.registerTabSearchItems(subTabLoader.item);
                                    });
                                }

                                Component.onCompleted: ensureLoaded()

                                Connections {
                                    target: root
                                    function onCurrentTabChanged() {
                                        if (root.currentTab === tabContentWrapper.parentTabIndex && root.currentSubTab === subIndex) subTabLoader.ensureLoaded();
                                    }
                                    function onCurrentSubTabChanged() {
                                        if (root.currentTab === tabContentWrapper.parentTabIndex && root.currentSubTab === subIndex) subTabLoader.ensureLoaded();
                                    }
                                    function onRequestLoadAll() {
                                        subTabLoader.ensureLoaded();
                                    }
                                }

                                Connections {
                                    target: subTabLoader.item
                                    ignoreUnknownSignals: true
                                    function onSearchItemsChanged() {
                                        root.registerTabSearchItems(subTabLoader.item);
                                    }
                                    function onSearchEntriesChanged() {
                                        root.registerTabSearchItems(subTabLoader.item);
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
