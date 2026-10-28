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
    property bool standalone: false
    readonly property bool loadsTabs: standalone || visible
    readonly property bool compact: width < s(780)

    signal requestLoad(int order)
    signal releaseTabs()
    signal exitRequested()

    property int activationCounter: 0
    property var appPaths: Caching
    property int currentTab: 0
    property int currentSubTab: 0
    property int expandedTab: -1

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
    property int searchLoadCursor: 0

    readonly property int totalTabSlots: {
        let n = 0;
        for (let i = 0; i < tabsModel.length; i++) {
            let st = tabsModel[i].subtabs;
            n += st && st.length > 0 ? st.length : 1;
        }
        return n;
    }

    function tabLoadOrder(tab, sub) {
        let n = 0;
        for (let i = 0; i < tab && i < tabsModel.length; i++) {
            let st = tabsModel[i].subtabs;
            n += st && st.length > 0 ? st.length : 1;
        }
        return n + Math.max(0, sub);
    }

    function searchHaystack(item) {
        if (item.hay === undefined) {
            item.hay = [
                item.title, resolveI18nText(item.title),
                item.desc || item.description, resolveI18nText(item.desc || item.description),
                resolveTabTitle(item.tab), resolveSubtabTitle(item.tab, item.subtab),
                item.tab, item.subtab, item.keywords
            ].join("\n").toLowerCase();
        }
        return item.hay;
    }

    function clearSearchHaystacks() {
        for (let k in searchIndexMap) {
            delete searchIndexMap[k].hay;
        }
    }

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
        let hits = [];
        for (let i = 0; i < searchIndex.length; i++) {
            let item = searchIndex[i];
            if (searchHaystack(item).indexOf(q) === -1) continue;
            let title = String(resolveI18nText(item.title)).toLowerCase();
            let at = title.indexOf(q);
            hits.push({ item: item, rank: title === q ? 0 : (at === 0 ? 1 : (at > 0 ? 2 : 3)) });
        }
        if (hits.length > 60) {
            hits.sort((a, b) => a.rank - b.rank);
            hits = hits.slice(0, 60);
        }
        return hits.map(h => h.item);
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
        searchSelectedIndex = Math.max(0, Math.min(count - 1, searchSelectedIndex + dir));
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
        if (!itemObj || !contentArea.searchResults) return;
        try {
            let mapped = itemObj.mapToItem(contentArea.searchResults.column, 0, 0);
            let itemY = mapped.y;
            let itemH = itemObj.height;
            let viewTop = contentArea.searchResults.contentY;
            let viewHeight = contentArea.searchResults.height;
            let viewBottom = viewTop + viewHeight;

            if (itemY < viewTop) {
                contentArea.searchResults.contentY = Math.max(0, itemY - root.s(8));
            } else if (itemY + itemH > viewBottom) {
                let maxScroll = Math.max(0, contentArea.searchResults.contentHeight - viewHeight);
                contentArea.searchResults.contentY = Math.min(maxScroll, itemY + itemH - viewHeight + root.s(8));
            }
        } catch(e) {}
    }

    function ensureTabVisible(idx) {
        if (!sidebar.tabsView || idx < 0 || !sidebar.tabsItems || idx >= sidebar.tabsItems.count) return;
        let item = sidebar.tabsItems.itemAt(idx);
        if (!item) return;
        let view = sidebar.tabsView;
        if (item.y < view.contentY) {
            view.contentY = Math.max(0, item.y - s(8));
        } else if (item.y + item.height > view.contentY + view.height) {
            view.contentY = Math.min(Math.max(0, view.contentHeight - view.height), item.y + item.height - view.height + s(8));
        }
    }

    function triggerHighlight(settingId) {
        highlightedSettingId = settingId;
        highlightToken++;
    }

    function openSearch() {
        searchRebuildTimer.stop();
        rebuildSearchIndex();
        searchClearTimer.stop();
        searchActive = true;
        searchSelectedIndex = 0;
        searchFocusTimer.restart();
        if (searchLoadCursor < totalTabSlots && !searchLoadTimer.running) {
            searchLoadTimer.interval = 280;
            searchLoadTimer.restart();
        }
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
        { id: "Welcome", key: "welcome", name: "Welcome", icon: "󰋜", file: "WelcomeTab.qml" },
        { id: "General", key: "general", name: "General", icon: "󰒓", file: "general/GeneralTab.qml" },
        {
            id: "Display",
            key: "display",
            name: "Display",
            icon: "󰃠",
            file: "display/DisplayMainTab.qml",
            subtabs: [
                { id: "DisplayGeneral", key: "display_general", name: "Display", icon: "󰍹", file: "display/DisplayMainTab.qml" },
                { id: "DisplayWidgets", key: "display_widgets", name: "Widgets", icon: "󰕰", file: "display/DisplayWidgetsTab.qml" },
                { id: "DisplayLockscreen", key: "display_lockscreen", name: "Lock screen", icon: "󰌾", file: "display/DisplayLockscreenTab.qml" }
            ]
        },
        { id: "Touchpad", key: "touchpad", name: "Touchpad", icon: "󰟀", file: "TouchpadTab.qml" },
        { id: "Theme", key: "theme", name: "Theme", icon: "󰏘", file: "theme/ThemeTab.qml" },
        {
            id: "Bar",
            key: "bar",
            name: "Bar",
            icon: "󰖲",
            separatorBefore: true,
            file: "bar/BarGeneralTab.qml",
            subtabs: [
                { id: "BarGeneral", key: "bar_general", name: "General", icon: "󰍜", file: "bar/BarGeneralTab.qml" },
                { id: "BarModules", key: "bar_modules", name: "Modules", icon: "󰐱", file: "bar/BarModulesTab.qml" }
            ]
        },
        { id: "Dock", key: "dock", name: "Dock", icon: "󰮯", file: "DockTab.qml" },
        { id: "Launcher", key: "launcher", name: "Launcher", icon: "󰵆", file: "LauncherTab.qml" },
        { id: "On-Screen Display", key: "osd", name: "On-Screen Display", icon: "󰕾", file: "OnScreenDisplayTab.qml" },
        { id: "Notifications", key: "notifications", name: "Notifications", icon: "󰂚", file: "notifications/NotificationsTab.qml" },
        { id: "Screenshot", key: "screenshot", name: "Screenshot", icon: "󰹑", file: "screenshot/ScreenshotTab.qml" },
        { id: "Wellbeing", key: "wellbeing", name: "Wellbeing", icon: "󰄉", separatorBefore: true, file: "wellbeing/DigitalWellbeingTab.qml" },
        { id: "Idle", key: "idle", name: "Idle", icon: "󰒲", file: "IdleTab.qml" },
        { id: "About", key: "about", name: "About", icon: "󰋽", separatorBefore: true, file: "AboutTab.qml" }
    ]

    readonly property var currentTabModel: tabsModel[currentTab] || null
    readonly property bool hasSubTabs: !!(currentTabModel && currentTabModel.subtabs && currentTabModel.subtabs.length > 0)

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

    function dismissHost() {
        if (standalone) {
            exitRequested();
        } else if (typeof masterWindow !== "undefined" && masterWindow.switchWidget) {
            masterWindow.switchWidget("hidden", "");
        } else {
            Quickshell.execDetached(["bash", Caching.serpantinumDir + "/scripts/qs_manager.sh", "close"]);
        }
    }

    function s(val) {
        return Scaler.s(val);
    }

    function gotoTab(tabName, subTabName) {
        if (tabName === undefined || tabName === null || tabName === "") return;
        tabName = String(tabName);
        if (!subTabName && tabName.indexOf(":") !== -1) {
            let parts = tabName.split(":");
            tabName = parts[0];
            subTabName = parts[1];
        }
        let r = resolveIndices(tabName, subTabName);
        let num = parseInt(tabName);
        if (r.tabIndex < 0 && !isNaN(num) && num >= 0 && num < tabsModel.length) {
            let t = tabsModel[num];
            let sNum = parseInt(subTabName);
            r = { tabIndex: num, subIndex: (!isNaN(sNum) && t.subtabs && sNum >= 0 && sNum < t.subtabs.length) ? sNum : 0 };
        }
        if (r.tabIndex < 0) return;
        currentTab = r.tabIndex;
        let t = tabsModel[r.tabIndex];
        expandedTab = (t.subtabs && t.subtabs.length > 0) ? r.tabIndex : -1;
        currentSubTab = Math.max(0, r.subIndex);
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
        return Math.min(1.0, Math.max(0.0, (introTabs - start) / 0.28));
    }

    function resetAndPlayIntro() {
        introBase = 0.0;
        if (root.standalone) {
            introSidebar = 1.0;
            introContent = 1.0;
            introTabs = 1.0;
            startupSequence.restart();
        } else {
            introSidebar = 0.0;
            introContent = 0.0;
            introTabs = 0.0;
            shellStartupSequence.restart();
        }
        Updater.checkUpdate();
        if (root.standalone && searchLoadCursor < totalTabSlots && !searchLoadTimer.running) {
            searchLoadTimer.interval = 400;
            searchLoadTimer.restart();
        }
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

    function focusInContent() {
        let f = root.Window.window ? root.Window.window.activeFocusItem : null;
        return !!f && f !== root;
    }

    function moveFocus(forward) {
        let next = root.Window.window.activeFocusItem.nextItemInFocusChain(forward);
        if (next && next !== root) next.forceActiveFocus(forward ? Qt.TabFocusReason : Qt.BacktabFocusReason);
    }

    function scrollIntoView(item) {
        if (!item) return;
        let p = item.parent;
        while (p) {
            if (p.contentY !== undefined && p.contentItem !== undefined && p.contentHeight !== undefined) {
                let y = item.mapToItem(p.contentItem, 0, 0).y;
                let margin = s(24);
                if (y < p.contentY + margin) {
                    p.contentY = Math.max(0, y - margin);
                } else if (y + item.height > p.contentY + p.height - margin) {
                    p.contentY = Math.min(Math.max(0, p.contentHeight - p.height), y + item.height - p.height + margin);
                }
                return;
            }
            p = p.parent;
        }
    }

    function activeFlickable() {
        let queue = [contentArea];
        while (queue.length > 0) {
            let it = queue.shift();
            if (it.visible === false) continue;
            if (it !== contentArea && it.contentY !== undefined && it.contentHeight !== undefined && it.contentItem !== undefined) return it;
            for (let i = 0; i < it.children.length; i++) queue.push(it.children[i]);
        }
        return null;
    }

    function scrollPage(kind) {
        let f = activeFlickable();
        if (!f) return;
        let maxY = Math.max(0, f.contentHeight - f.height);
        let y = f.contentY;
        if (kind === "down") y += f.height * 0.9;
        else if (kind === "up") y -= f.height * 0.9;
        else if (kind === "home") y = 0;
        else if (kind === "end") y = maxY;
        f.contentY = Math.max(0, Math.min(maxY, y));
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
            if (contentArea.searchInput) {
                contentArea.searchInput.forceInputFocus();
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
        interval: 900
        repeat: false
        onTriggered: {
            searchQuery = "";
            if (contentArea.searchInput) contentArea.searchInput.text = "";
        }
    }

    Timer {
        id: searchLoadTimer
        interval: 280
        repeat: true
        onTriggered: {
            if (startupSequence.running || closeSequence.running) return;
            interval = root.standalone ? 30 : 100;
            if (root.searchLoadCursor >= root.totalTabSlots) {
                stop();
                return;
            }
            root.requestLoad(root.searchLoadCursor++);
        }
    }

    Timer {
        id: searchRebuildTimer
        interval: 30
        repeat: false
        onTriggered: root.rebuildSearchIndex()
    }

    Timer {
        id: tabReleaseTimer
        interval: 600000
        repeat: false
        onTriggered: {
            if (root.visible || root.standalone) return;
            root.searchLoadCursor = 0;
            root.releaseTabs();
        }
    }

    onVisibleChanged: {
        if (!standalone) {
            if (visible) tabReleaseTimer.stop();
            else tabReleaseTimer.restart();
        }
        if (visible) {
            forceActiveFocus();
            focusTimer.restart();
            resetAndPlayIntro();
        } else {
            startupSequence.stop();
            closeSequence.stop();
            shellStartupSequence.stop();
            searchLoadTimer.stop();
            highlightTimer.stop();
            searchClearTimer.stop();
            searchRebuildTimer.stop();
            clearSearchHaystacks();
            rebuildSearchIndex();
            pendingHighlightItem = null;
            introBase = 0.0;
            introSidebar = 0.0;
            introContent = 0.0;
            introTabs = 0.0;
            searchActive = false;
            searchQuery = "";
            searchSelectedIndex = -1;
            if (contentArea.searchInput) contentArea.searchInput.text = "";
            if (root.chargingSoundHandle !== -1 && typeof Sounds !== "undefined") {
                Sounds.stopSfx(root.chargingSoundHandle);
                root.chargingSoundHandle = -1;
            }
        }
    }

    Component.onCompleted: {
        if (root.standalone && searchLoadCursor < totalTabSlots && !searchLoadTimer.running) {
            searchLoadTimer.interval = 120;
            searchLoadTimer.restart();
        }
        if (visible) {
            forceActiveFocus();
            focusTimer.restart();
            resetAndPlayIntro();
        }
    }

    Shortcut {
        sequences: [StandardKey.Find, "Ctrl+K"]
        onActivated: root.openSearch()
    }

    Shortcut {
        sequences: ["Ctrl+PgDown", "Ctrl+Tab"]
        onActivated: root.nextTab()
    }

    Shortcut {
        sequences: ["Ctrl+PgUp", "Ctrl+Shift+Tab"]
        onActivated: root.prevTab()
    }

    Shortcut {
        sequences: [StandardKey.Close, "Ctrl+Q"]
        onActivated: root.closePopup()
    }

    Connections {
        target: root.Window.window
        function onActiveFocusItemChanged() {
            let f = root.Window.window.activeFocusItem;
            if (f && f !== root) root.scrollIntoView(f);
        }
    }

    Keys.onPressed: (event) => {
        let plain = !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier));
        if (event.key === Qt.Key_Escape) {
            if (root.searchActive) {
                if (root.searchQuery !== "") {
                    root.searchQuery = "";
                    if (contentArea.searchInput) contentArea.searchInput.text = "";
                } else {
                    root.closeSearch();
                }
            } else if (root.focusInContent()) {
                root.forceActiveFocus();
            } else if (!root.standalone) {
                root.dismissHost();
            }
            event.accepted = true;
        } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Up) {
            let dir = event.key === Qt.Key_Down ? 1 : -1;
            if (root.searchActive) root.navigateSearch(dir);
            else if (root.focusInContent()) root.moveFocus(dir > 0);
            else if (dir > 0) root.nextTab();
            else root.prevTab();
            event.accepted = true;
        } else if ((event.key === Qt.Key_Left || event.key === Qt.Key_Right) && plain) {
            let dir = (event.key === Qt.Key_Right) !== I18n.rtl ? 1 : -1;
            if (!root.searchActive && !root.focusInContent()) { if (dir > 0) root.nextTab(); else root.prevTab(); }
            event.accepted = !root.searchActive;
        } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && root.searchActive) {
            root.activateSelectedSearch();
            event.accepted = true;
        } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
            let forward = event.key === Qt.Key_Tab;
            if (root.searchActive) root.navigateSearch(forward ? 1 : -1);
            else if (forward) root.nextTab();
            else root.prevTab();
            event.accepted = true;
        } else if (!root.searchActive && !root.focusInContent()) {
            if (event.key === Qt.Key_PageDown || event.key === Qt.Key_Space) root.scrollPage("down");
            else if (event.key === Qt.Key_PageUp) root.scrollPage("up");
            else if (event.key === Qt.Key_Home) root.scrollPage("home");
            else if (event.key === Qt.Key_End) root.scrollPage("end");
            else if (event.key === Qt.Key_Slash || (plain && event.text.length === 1 && event.text >= " " && event.text !== " ")) {
                root.openSearch();
                if (event.key !== Qt.Key_Slash && contentArea.searchInput) {
                    contentArea.searchInput.text = event.text;
                    root.searchQuery = event.text;
                }
            } else return;
            event.accepted = true;
        }
    }

    Timer {
        id: saveTabDebounceTimer
        interval: 350
        repeat: false
        onTriggered: {
            let t = root.currentTabModel;
            let st = root.hasSubTabs ? root.currentTabModel.subtabs[root.currentSubTab] : null;
            let val = t ? (t.key + (st ? ":" + st.key : "")) : "";
            if (val !== "") Quickshell.execDetached(["bash", "-c", "echo '" + val + "' > '" + Caching.getCacheDir("guide") + "/last_tab.txt'"]);
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

    NumberAnimation {
        id: startupSequence
        target: root
        property: "introBase"
        from: 0.0
        to: 1.0
        duration: 160
        easing.type: Easing.OutCubic
    }

    ParallelAnimation {
        id: shellStartupSequence
        NumberAnimation {
            target: root
            property: "introBase"
            from: 0.0
            to: 1.0
            duration: 380
            easing.type: Easing.OutExpo
        }
        SequentialAnimation {
            PauseAnimation { duration: 30 }
            NumberAnimation {
                target: root
                property: "introSidebar"
                from: 0.0
                to: 1.0
                duration: 250
                easing.type: Easing.OutCubic
            }
        }
        SequentialAnimation {
            PauseAnimation { duration: 50 }
            NumberAnimation {
                target: root
                property: "introTabs"
                from: 0.0
                to: 1.0
                duration: 250
                easing.type: Easing.Linear
            }
        }
        SequentialAnimation {
            PauseAnimation { duration: 90 }
            NumberAnimation {
                target: root
                property: "introContent"
                from: 0.0
                to: 1.0
                duration: 360
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
                duration: root.standalone ? 0 : 100
                easing.type: Easing.InExpo
            }
            NumberAnimation {
                target: root
                property: "introSidebar"
                to: 0.0
                duration: root.standalone ? 0 : 100
                easing.type: Easing.InExpo
            }
            NumberAnimation {
                target: root
                property: "introTabs"
                to: 0.0
                duration: root.standalone ? 0 : 80
                easing.type: Easing.InQuad
            }
        }
        NumberAnimation {
            target: root
            property: "introBase"
            to: 0.0
            duration: root.standalone ? 110 : 130
            easing.type: root.standalone ? Easing.InQuad : Easing.InQuart
        }
        ScriptAction {
            script: {
                if (root.exitCallback) {
                    let cb = root.exitCallback;
                    root.exitCallback = null;
                    cb();
                } else {
                    root.dismissHost();
                }
            }
        }
    }

    Item {
        anchors.fill: parent
        opacity: introBase
        scale: root.standalone ? 1.0 : 0.95 + (0.05 * introBase)

        Rectangle {
            anchors.fill: parent
            radius: root.standalone ? 0 : ThemeBackend.clampedBorderRadius
            color: Qt.alpha(ThemeBackend.base, ThemeBackend.elementOpacity)

            WallpaperBlur {
                z: -1
                anchors.fill: parent
                topLeftRadius: parent.topLeftRadius
                topRightRadius: parent.topRightRadius
                bottomLeftRadius: parent.bottomLeftRadius
                bottomRightRadius: parent.bottomRightRadius
            }

            GuideSidebar {
                id: sidebar
                popup: root
            }

            GuideContent {
                id: contentArea
                popup: root
                x: I18n.rtl ? 0 : sidebar.width
                width: Math.max(0, parent.width - sidebar.width)
                height: parent.height
            }
        }
    }
}
