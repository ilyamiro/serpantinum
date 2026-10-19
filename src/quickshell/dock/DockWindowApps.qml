import QtQuick
import Quickshell
import "../"

DockWindowState {
    id: dockWindow

    property alias dockAppsModel: dockAppsModel
    property alias runningAppsModel: runningAppsModel

    property var runningInfoMap: ({})
    property int runningInfoRevision: 0

    function _recomputeRunningInfo() {
        let groups = (typeof WindowTracker !== "undefined" && WindowTracker.groups) ? WindowTracker.groups : {};
        let newMap = {};
        let currentOutput = dockWindow.myOutput;
        let currentWs = dockWindow.activeIndex;
        let scope = dockWindow.effectiveRunningScope;

        for (let gKey in groups) {
            let grp = groups[gKey];
            if (!grp || !grp.windows) continue;

            let here = [];
            let elsewhere = [];

            for (let i = 0; i < grp.windows.length; i++) {
                let w = grp.windows[i];
                let match = false;

                if (scope === "all") {
                    match = true;
                } else if (scope === "output") {
                    match = (w.output === "" || w.output === currentOutput);
                } else if (scope === "workspace") {
                    let outMatch = (w.output === "" || w.output === currentOutput);
                    let wsMatch = (w.workspace < 0 || w.workspace === currentWs);
                    match = outMatch && wsMatch;
                }

                if (match) {
                    here.push(w);
                } else {
                    elsewhere.push(w);
                }
            }

            let isFoc = here.some(function(w) { return w.focused; });
            let isFocElse = elsewhere.some(function(w) { return w.focused; });
            let activeWin = here.length > 0 ? here[0] : (elsewhere.length > 0 ? elsewhere[0] : null);

            let grpInfo = {
                groupKey: gKey,
                desktopId: grp.desktopId,
                appId: grp.appId,
                count: here.length,
                totalCount: grp.count,
                hasWindows: (here.length > 0 || elsewhere.length > 0),
                here: here,
                elsewhere: elsewhere,
                isFocused: isFoc,
                isFocusedElsewhere: isFocElse,
                activeWindow: activeWin
            };

            newMap[gKey] = grpInfo;
            if (grp.desktopId) {
                newMap[grp.desktopId] = grpInfo;
                if (typeof AppMatcher !== "undefined") {
                    newMap[AppMatcher.canonicalId(grp.desktopId)] = grpInfo;
                }
            }
            if (grp.appId) {
                newMap[grp.appId] = grpInfo;
                if (typeof AppMatcher !== "undefined") {
                    newMap[AppMatcher.canonicalId(grp.appId)] = grpInfo;
                }
                newMap["app:" + String(grp.appId).toLowerCase()] = grpInfo;
            }
            if (typeof AppMatcher !== "undefined") {
                let resolved = AppMatcher.resolve(grp.appId || grp.desktopId);
                if (resolved) {
                    newMap[resolved] = grpInfo;
                    newMap[AppMatcher.canonicalId(resolved)] = grpInfo;
                }
            }
        }

        dockWindow.runningInfoMap = newMap;
        dockWindow.runningInfoRevision++;
    }

    function getRunningInfoForApp(desktopId) {
        if (!desktopId || !runningInfoMap) return null;
        let raw = String(desktopId).trim();
        let lower = raw.toLowerCase();
        let cid = lower.endsWith(".desktop") ? lower.slice(0, -8) : lower;
        return runningInfoMap[raw] || runningInfoMap[cid] || runningInfoMap["app:" + cid] || (typeof AppMatcher !== "undefined" ? runningInfoMap[AppMatcher.canonicalId(desktopId)] : null) || null;
    }

    Connections {
        target: (typeof WindowTracker !== "undefined") ? WindowTracker : null
        function onUpdated() {
            dockWindow._recomputeRunningInfo();
        }
    }

    Connections {
        target: (typeof DockAppMenuController !== "undefined") ? DockAppMenuController : null
        function onRequestPin(dId, name, icon) {
            let cid = (typeof AppMatcher !== "undefined") ? AppMatcher.canonicalId(dId) : String(dId).toLowerCase().replace(/\.desktop$/, "");
            for (let r = runningAppsModel.count - 1; r >= 0; r--) {
                let rItem = runningAppsModel.get(r);
                if (!rItem) continue;
                let rCid = rItem.canonical_id || ((typeof AppMatcher !== "undefined") ? AppMatcher.canonicalId(rItem.desktop_id) : "");
                if (rItem.desktop_id === dId || (cid && rCid === cid) || dockWindow.isAppInDock(rItem.desktop_id)) {
                    runningAppsModel.remove(r);
                }
            }
            if (dockWindow.isAppInDock(dId)) {
                dockWindow._syncRunningApps();
                return;
            }
            let ent = (typeof AppMatcher !== "undefined") ? AppMatcher.entry(dId) : null;
            let finalName = name || (ent ? ent.name : dId);
            let finalIcon = icon || (ent ? ent.icon : dId);
            let finalComment = ent ? (ent.comment || "") : "";
            dockAppsModel.append({
                name: finalName,
                comment: finalComment,
                desktop_id: dId,
                icon: finalIcon
            });
            dockWindow.saveApps();
            dockWindow._syncRunningApps();
        }
        function onRequestUnpin(dId) {
            let cid = (typeof AppMatcher !== "undefined") ? AppMatcher.canonicalId(dId) : dId.toLowerCase();
            for (let i = 0; i < dockAppsModel.count; i++) {
                let it = dockAppsModel.get(i);
                if (it && (it.desktop_id === dId || ((typeof AppMatcher !== "undefined") && AppMatcher.canonicalId(it.desktop_id) === cid))) {
                    dockAppsModel.remove(i);
                    dockWindow.saveApps();
                    dockWindow._syncRunningApps();
                    break;
                }
            }
        }
    }

    onEffectiveRunningScopeChanged: dockWindow._recomputeRunningInfo()

    ListModel {
        id: dockAppsModel
    }

    ListModel {
        id: runningAppsModel
    }

    function _syncRunningApps() {
        if (!dockWindow.showRunningApps || dockWindow.editMode) {
            if (runningAppsModel.count > 0) runningAppsModel.clear();
            return;
        }

        let groups = (typeof WindowTracker !== "undefined" && WindowTracker.groups) ? WindowTracker.groups : {};
        let pinnedSet = {};
        for (let p = 0; p < dockAppsModel.count; p++) {
            let item = dockAppsModel.get(p);
            if (item && item.desktop_id) {
                let did = String(item.desktop_id).trim();
                pinnedSet[did] = true;
                let lower = did.toLowerCase();
                pinnedSet[lower] = true;
                let noExt = lower.endsWith(".desktop") ? lower.slice(0, -8) : lower;
                pinnedSet[noExt] = true;
                pinnedSet[noExt + ".desktop"] = true;
                if (typeof AppMatcher !== "undefined") {
                    let cid = AppMatcher.canonicalId(did);
                    if (cid) {
                        pinnedSet[cid] = true;
                        pinnedSet[cid + ".desktop"] = true;
                    }
                    let res = AppMatcher.resolve(did);
                    if (res) {
                        pinnedSet[res] = true;
                        pinnedSet[res.toLowerCase()] = true;
                        let resCid = AppMatcher.canonicalId(res);
                        if (resCid) {
                            pinnedSet[resCid] = true;
                            pinnedSet[resCid + ".desktop"] = true;
                        }
                    }
                }
            }
        }

        let candidates = [];
        let seenCids = {};
        for (let gKey in groups) {
            let grp = groups[gKey];
            if (!grp || !grp.windows || grp.windows.length === 0) continue;

            let dId = grp.desktopId || "";
            let rawApp = grp.appId || "";
            if (!dId && !rawApp) continue;
            let cid = dId !== "" ? ((typeof AppMatcher !== "undefined") ? AppMatcher.canonicalId(dId) : dId.toLowerCase()) : ((typeof AppMatcher !== "undefined") ? AppMatcher.canonicalId(rawApp) : rawApp.toLowerCase());
            if (!cid) cid = gKey;

            let isPinned = false;
            if (dId && (pinnedSet[dId] || pinnedSet[dId.toLowerCase()])) isPinned = true;
            if (!isPinned && rawApp && (pinnedSet[rawApp] || pinnedSet[rawApp.toLowerCase()])) isPinned = true;
            if (!isPinned && cid && (pinnedSet[cid] || pinnedSet[cid.toLowerCase()])) isPinned = true;
            if (!isPinned && gKey && pinnedSet[gKey]) isPinned = true;
            if (!isPinned && (dockWindow.isAppInDock(dId) || (rawApp && dockWindow.isAppInDock(rawApp)))) isPinned = true;
            if (isPinned) continue;

            if (seenCids[cid]) continue;
            seenCids[cid] = true;

            let ent = (typeof AppMatcher !== "undefined" && dId !== "") ? AppMatcher.entry(dId) : null;
            if (!ent && typeof AppMatcher !== "undefined" && rawApp !== "") ent = AppMatcher.entry(rawApp);
            let appName = ent ? (ent.name || "") : (rawApp || "App");
            let appIcon = ent ? (ent.icon || "") : (rawApp || "");
            let appComment = ent ? (ent.comment || "") : "";

            candidates.push({
                name: appName,
                comment: appComment,
                desktop_id: dId !== "" ? (dId.endsWith(".desktop") ? dId : (dId + ".desktop")) : (rawApp ? (rawApp + ".desktop") : cid),
                icon: appIcon,
                canonical_id: cid,
                is_pinned: false
            });
        }

        for (let r = runningAppsModel.count - 1; r >= 0; r--) {
            let rItem = runningAppsModel.get(r);
            if (!rItem) continue;
            let exists = false;
            for (let c = 0; c < candidates.length; c++) {
                if (candidates[c].canonical_id === rItem.canonical_id || candidates[c].desktop_id === rItem.desktop_id) {
                    exists = true;
                    break;
                }
            }
            if (!exists) {
                runningAppsModel.remove(r);
            }
        }

        for (let c = 0; c < candidates.length; c++) {
            let cand = candidates[c];
            let idx = -1;
            for (let r = c; r < runningAppsModel.count; r++) {
                let rItem = runningAppsModel.get(r);
                if (rItem && (rItem.canonical_id === cand.canonical_id || rItem.desktop_id === cand.desktop_id)) {
                    idx = r;
                    break;
                }
            }
            if (idx === -1) {
                runningAppsModel.insert(c, cand);
            } else if (idx !== c) {
                runningAppsModel.move(idx, c, 1);
            }
        }
    }

    onRunningInfoRevisionChanged: dockWindow._syncRunningApps()
    onShowRunningAppsChanged: dockWindow._syncRunningApps()

    function loadApps() {
        let customApps = rawDockSettings.apps;
        if (!customApps || !Array.isArray(customApps)) customApps = [];
        if (dockAppsModel.count === customApps.length) {
            let matches = true;
            for (let i = 0; i < customApps.length; i++) {
                let cur = dockAppsModel.get(i);
                let app = customApps[i];
                let id = app.desktop_id || app.id || "";
                if (!cur || cur.desktop_id !== id || cur.name !== (app.name || "") || cur.icon !== (app.icon || "")) {
                    matches = false;
                    break;
                }
            }
            if (matches) {
                dockWindow._syncRunningApps();
                return;
            }
        }
        dockAppsModel.clear();
        for (let k = 0; k < customApps.length; k++) {
            let app = customApps[k];
            dockAppsModel.append({
                name: app.name || "",
                comment: app.comment || "",
                desktop_id: app.desktop_id || app.id || "",
                icon: app.icon || ""
            });
        }
        dockWindow._syncRunningApps();
    }

    function saveApps() {
        let arr = [];
        for (let i = 0; i < dockAppsModel.count; i++) {
            let item = dockAppsModel.get(i);
            if (item) {
                arr.push({
                    "name": item.name || "",
                    "comment": item.comment || "",
                    "desktop_id": item.desktop_id || "",
                    "icon": item.icon || ""
                });
            }
        }
        let current = JSON.parse(JSON.stringify(rawDockSettings || defaultDockSettings));
        current.apps = arr;
        current.visibleElements = dockVisibleElements;
        current.enableScrolling = enableScrolling;
        current.exclusive = dockExclusive;
        current.onTop = dockOnTop;
        current.smartAutohide = smartAutohide;
        if (typeof Config !== "undefined" && typeof Config.setSetting === "function") {
            Config.setSetting("dock", current);
        }
    }

    function isAppInDock(desktopId) {
        if (!desktopId) return false;
        let target = String(desktopId).trim();
        let targetLower = target.toLowerCase();
        let targetNoExt = targetLower.endsWith(".desktop") ? targetLower.slice(0, -8) : targetLower;
        let targetCid = (typeof AppMatcher !== "undefined") ? AppMatcher.canonicalId(target) : targetNoExt;

        for (let i = 0; i < dockAppsModel.count; i++) {
            let it = dockAppsModel.get(i);
            if (!it || !it.desktop_id) continue;
            let cur = String(it.desktop_id).trim();
            if (cur === target) return true;
            let curLower = cur.toLowerCase();
            if (curLower === targetLower) return true;
            let curNoExt = curLower.endsWith(".desktop") ? curLower.slice(0, -8) : curLower;
            if (curNoExt === targetNoExt) return true;

            if (typeof AppMatcher !== "undefined") {
                let curCid = AppMatcher.canonicalId(cur);
                if (curCid && curCid === targetCid) return true;
            }
        }

        if (typeof AppMatcher !== "undefined") {
            let targetRes = AppMatcher.resolve(target);
            let targetResCid = targetRes ? AppMatcher.canonicalId(targetRes) : "";
            for (let i = 0; i < dockAppsModel.count; i++) {
                let it = dockAppsModel.get(i);
                if (!it || !it.desktop_id) continue;
                let cur = String(it.desktop_id).trim();
                let curCid = AppMatcher.canonicalId(cur);
                if (targetResCid && curCid && curCid === targetResCid) return true;
                let curRes = AppMatcher.resolve(cur);
                let curResCid = curRes ? AppMatcher.canonicalId(curRes) : "";
                if (curResCid && (curResCid === targetCid || (targetResCid && curResCid === targetResCid))) return true;
            }
        }
        return false;
    }

    function addApp(entry) {
        if (!entry) return;
        let id = entry.id || entry.desktop_id || "";
        let cid = (typeof AppMatcher !== "undefined") ? AppMatcher.canonicalId(id) : String(id).toLowerCase().replace(/\.desktop$/, "");
        for (let r = runningAppsModel.count - 1; r >= 0; r--) {
            let rItem = runningAppsModel.get(r);
            if (!rItem) continue;
            let rCid = rItem.canonical_id || ((typeof AppMatcher !== "undefined") ? AppMatcher.canonicalId(rItem.desktop_id) : "");
            if (rItem.desktop_id === id || (cid && rCid === cid) || dockWindow.isAppInDock(rItem.desktop_id)) {
                runningAppsModel.remove(r);
            }
        }
        if (dockWindow.isAppInDock(id)) {
            dockWindow._syncRunningApps();
            return;
        }
        dockAppsModel.append({
            name: entry.name || "",
            comment: entry.comment || "",
            desktop_id: id,
            icon: entry.icon || ""
        });
        saveApps();
        dockWindow._syncRunningApps();
    }

    function removeAppByDesktopId(desktopId) {
        let cid = (typeof AppMatcher !== "undefined") ? AppMatcher.canonicalId(desktopId) : String(desktopId).toLowerCase().replace(/\.desktop$/, "");
        for (let i = 0; i < dockAppsModel.count; i++) {
            let it = dockAppsModel.get(i);
            if (it && (it.desktop_id === desktopId || ((typeof AppMatcher !== "undefined") && AppMatcher.canonicalId(it.desktop_id) === cid))) {
                dockAppsModel.remove(i, 1);
                saveApps();
                dockWindow._syncRunningApps();
                return;
            }
        }
    }

    function setEditMode(val) {
        let current = JSON.parse(JSON.stringify(rawDockSettings || defaultDockSettings));
        current.editing = val;
        current.visibleElements = dockVisibleElements;
        current.enableScrolling = enableScrolling;
        current.exclusive = dockExclusive;
        current.onTop = dockOnTop;
        current.smartAutohide = smartAutohide;
        if (typeof Config !== "undefined" && typeof Config.setSetting === "function") {
            Config.setSetting("dock", current);
        }
        if (typeof Sounds !== "undefined") {
            Sounds.playSfx(val ? "guide/barconfig/out.wav" : "guide/barconfig/in.wav");
        }
    }

    function launchApp(desktopId) {
        if (typeof DesktopEntries !== "undefined") {
            let entry = DesktopEntries.byId(desktopId);
            if (entry) {
                entry.execute();
            }
        }
    }

    function activateOrLaunch(desktopId, modifiers) {
        if (!desktopId) return;

        let forceNew = modifiers && (modifiers & Qt.ShiftModifier || modifiers & Qt.ControlModifier);
        if (forceNew || !dockWindow.focusRunning) {
            dockWindow.launchApp(desktopId);
            return;
        }

        let info = dockWindow.getRunningInfoForApp(desktopId);
        if (!info || !info.hasWindows) {
            dockWindow.launchApp(desktopId);
            return;
        }

        let targetWin = null;
        if (info.here && info.here.length > 0) {
            if (info.here.length === 1) {
                targetWin = info.here[0];
            } else {
                let curIdx = -1;
                for (let i = 0; i < info.here.length; i++) {
                    if (info.here[i].focused) {
                        curIdx = i;
                        break;
                    }
                }
                let targetIdx = 0;
                if (curIdx >= 0) {
                    targetIdx = (curIdx + 1) % info.here.length;
                }
                targetWin = info.here[targetIdx];
            }
        } else if (info.elsewhere && info.elsewhere.length > 0) {
            targetWin = info.elsewhere[0];
        }

        if (targetWin) {
            if (typeof WindowTracker !== "undefined") {
                WindowTracker.focusWindow(targetWin);
            }
        } else {
            dockWindow.launchApp(desktopId);
        }
    }

    onConfigRevisionChanged: loadApps()
}
