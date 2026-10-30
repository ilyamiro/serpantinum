import QtQuick
import "../../"
import "../../../"
import "../../../bar"

GuideTab {
    id: barTabRoot
    subTabIndex: 0

    property real cardRadius: ThemeBackend.clampedBorderRadius

    property var defaultBarSettings: {
        "position": "top",
        "width": 100,
        "height": 40,
        "style": "modular",
        "distinctPills": false,
        "centerByEdges": true,
        "time": {"format": "HH:mm:ss"},
        "autohide": false,
        "autohideTimeout": 1000,
        "groupColors": {},
        "modules": {
            "left": ["left", "workspaces", "media"],
            "center": ["timedate", "info", "weather"],
            "right": ["tray", ["kb", "wifi", "bt", "vol", "bat"]]
        }
    }

    property var barSettings: Config.getSetting("bar", defaultBarSettings)
    property string barPosition: barSettings.position !== undefined ? barSettings.position : "top"
    property real currentBarWidth: barSettings.width !== undefined ? barSettings.width : 100
    property real currentBarThickness: barSettings.height !== undefined ? barSettings.height : 40
    property string barStyle: {
        let s = barSettings.style;
        if (typeof s === "string") return s;
        if (s && typeof s === "object") {
            if (s.fill || s.mode === "fill") return "fill";
            if (s.solid || s.mode === "solid") return "solid";
        }
        return "modular";
    }
    property bool distinctPills: barSettings.distinctPills !== undefined ? barSettings.distinctPills : false
    property bool centerByEdges: barSettings.centerByEdges !== undefined ? barSettings.centerByEdges : true
    property bool autohide: barSettings.autohide !== undefined ? barSettings.autohide : false
    property int autohideTimeout: barSettings.autohideTimeout !== undefined ? barSettings.autohideTimeout : 1000

    ListModel { id: leftModel }
    ListModel { id: centerModel }
    ListModel { id: rightModel }
    ListModel { id: availableModel }

    property alias leftModel: leftModel
    property alias centerModel: centerModel
    property alias rightModel: rightModel
    property alias availableModel: availableModel
    property alias barWidthDebounceTimer: barWidthDebounceTimer

    property string currentPlaceholderList: ""
    property int currentPlaceholderIndex: -1

    property string pendingGroupModuleId: ""
    property string pendingGroupList: ""
    property var assignedGroupColors: barSettings.groupColors || ({})

    property string lastSavedModulesString: ""

    Timer {
        id: barWidthDebounceTimer
        interval: 100
        repeat: false
        onTriggered: {
            barTabRoot.updateBarSettings();
        }
    }

    function clearPendingGroup() {
        barTabRoot.pendingGroupModuleId = "";
        barTabRoot.pendingGroupList = "";
    }

    function getValidItemCount(m) {
        if (!m) return 0;
        let count = 0;
        for (let i = 0; i < m.count; i++) {
            let it = m.get(i);
            if (it && !it.isPlaceholder) count++;
        }
        return count;
    }

    function getModulesString(modulesObj) {
        if (!modulesObj) return "";
        return JSON.stringify({
            center: modulesObj.center || [],
            left: modulesObj.left || [],
            right: modulesObj.right || []
        });
    }

    function colorToString(c) {
        if (!c) return "#000000";
        if (typeof c === "string") return c;
        if (typeof c === "object" && c.hex) return String(c.hex);
        return String(c);
    }

    function getAllColors() {
        let colors = [
            ThemeBackend.mauve,
            ThemeBackend.pink,
            ThemeBackend.lavender,
            ThemeBackend.blue,
            ThemeBackend.sapphire,
            ThemeBackend.teal,
            ThemeBackend.green,
            ThemeBackend.yellow,
            ThemeBackend.peach,
            ThemeBackend.flamingo
        ];
        let res = [];
        for (let i = 0; i < colors.length; i++) {
            if (colors[i] !== undefined) {
                res.push(colorToString(colors[i]));
            }
        }
        return res;
    }

    function assignGroupColor(gId) {
        if (!gId || gId === "") return;
        if (barTabRoot.assignedGroupColors && barTabRoot.assignedGroupColors[gId]) return;

        let palette = barTabRoot.getAllColors();
        let used = Object.values(barTabRoot.assignedGroupColors || {});

        let chosenColor = "";
        for (let i = 0; i < palette.length; i++) {
            if (used.indexOf(palette[i]) === -1) {
                chosenColor = palette[i];
                break;
            }
        }
        if (chosenColor === "") {
            let count = Object.keys(barTabRoot.assignedGroupColors || {}).length;
            chosenColor = palette[count % palette.length];
        }

        let newAssigned = Object.assign({}, barTabRoot.assignedGroupColors || {});
        newAssigned[gId] = chosenColor;
        barTabRoot.assignedGroupColors = newAssigned;
    }

    function getGroupColor(gId) {
        if (!gId || gId === "") return colorToString(ThemeBackend.surface0);
        if (barTabRoot.assignedGroupColors && barTabRoot.assignedGroupColors[gId]) {
            return barTabRoot.assignedGroupColors[gId];
        }
        let palette = barTabRoot.getAllColors();
        if (!palette || palette.length === 0) return colorToString(ThemeBackend.surface0);
        let hash = 0;
        for (let i = 0; i < gId.length; i++) {
            hash = ((hash << 5) - hash) + gId.charCodeAt(i);
            hash |= 0;
        }
        return palette[Math.abs(hash) % palette.length] || colorToString(ThemeBackend.surface0);
    }

    function getContrastTextColor(bg) {
        let c = Qt.color(bg);
        let bgLum = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b;
        let tColor = Qt.color(ThemeBackend.text);
        let tLum = 0.2126 * tColor.r + 0.7152 * tColor.g + 0.0722 * tColor.b;
        let cColor = Qt.color(ThemeBackend.crust);
        let cLum = 0.2126 * cColor.r + 0.7152 * cColor.g + 0.0722 * cColor.b;
        if (bgLum > 0.5) {
            return tLum < cLum ? ThemeBackend.text : ThemeBackend.crust;
        } else {
            return tLum > cLum ? ThemeBackend.text : ThemeBackend.crust;
        }
    }

    function getModuleInfo(id) {
        let labels = {
            "left": I18n.t("guide.bar.modules.actions"),
            "workspaces": I18n.t("guide.bar.modules.workspaces.name"),
            "focus": I18n.t("guide.bar.modules.focus"),
            "timedate": I18n.t("guide.bar.modules.timedate.name"),
            "info": I18n.t("guide.bar.modules.info"),
            "weather": I18n.t("guide.bar.modules.weather"),
            "media": I18n.t("guide.bar.modules.media"),
            "vis": I18n.t("guide.bar.modules.vis"),
            "tray": I18n.t("guide.bar.modules.tray"),
            "sysmon": I18n.t("guide.bar.modules.sysmon"),
            "hackerstats": I18n.t("guide.bar.modules.hackerstats", "Hacker Stats"),
            "kb": I18n.t("guide.bar.modules.keyboard"),
            "wifi": I18n.t("guide.bar.modules.network"),
            "bt": I18n.t("guide.bar.modules.bluetooth"),
            "vol": I18n.t("guide.bar.modules.volume"),
            "bat": I18n.t("guide.bar.modules.battery")
        };
        let icons = {
            "left": "󰍜",
            "workspaces": "󰮯",
            "focus": "󰈈",
            "timedate": "󰃰",
            "info": "󰋼",
            "weather": "󰖐",
            "media": "󰎈",
            "vis": "󰝚",
            "tray": "󱊞",
            "sysmon": "󰍛",
            "hackerstats": "󰍛",
            "kb": "󰌌",
            "wifi": "󰤨",
            "bt": "󰂲",
            "vol": "󰕾",
            "bat": "󰁹"
        };
        let colors = {
            "left": ThemeBackend.blue,
            "workspaces": ThemeBackend.mauve,
            "focus": ThemeBackend.teal,
            "timedate": ThemeBackend.peach,
            "info": ThemeBackend.red,
            "weather": ThemeBackend.yellow,
            "media": ThemeBackend.green,
            "vis": ThemeBackend.mauve,
            "tray": ThemeBackend.yellow,
            "sysmon": ThemeBackend.mauve,
            "hackerstats": ThemeBackend.mauve,
            "kb": ThemeBackend.text,
            "wifi": ThemeBackend.blue,
            "bt": ThemeBackend.mauve,
            "vol": ThemeBackend.peach,
            "bat": ThemeBackend.green
        };
        let mType = BarModuleRegistry.types ? BarModuleRegistry.types[id] : null;
        return {
            "moduleId": id,
            "moduleLabel": labels[id] || (mType ? mType.name : id),
            "moduleIcon": icons[id] || (mType ? mType.icon : "󰅂"),
            "moduleColor": colorToString(colors[id] || ThemeBackend.text),
            "isPlaceholder": false,
            "placeholderWidth": 0,
            "groupId": ""
        };
    }

    function loadModuleModels() {
        let ms = barTabRoot.barSettings.modules;
        if (!ms) ms = barTabRoot.defaultBarSettings.modules;

        let l = ms.left ? JSON.parse(JSON.stringify(ms.left)) : [];
        let c = ms.center ? JSON.parse(JSON.stringify(ms.center)) : [];
        let r = ms.right ? JSON.parse(JSON.stringify(ms.right)) : [];

        function migrate(arr) {
            if (!arr) return [];
            var res = [];
            for (var i = 0; i < arr.length; i++) {
                if (Array.isArray(arr[i])) {
                    var group = [];
                    for (var j = 0; j < arr[i].length; j++) {
                        if (arr[i][j] === "system") group.push("sysmon", "kb", "wifi", "bt", "vol", "bat");
                        else if (arr[i][j] === "centerbox" || arr[i][j] === "center") group.push("timedate", "info", "weather");
                        else group.push(arr[i][j]);
                    }
                    if (group.length === 1) res.push(group[0]);
                    else if (group.length > 1) res.push(group);
                } else {
                    if (arr[i] === "system") res.push(...["sysmon", "kb", "wifi", "bt", "vol", "bat"]);
                    else if (arr[i] === "centerbox" || arr[i] === "center") res.push(...["timedate", "info", "weather"]);
                    else res.push(arr[i]);
                }
            }
            return res;
        }

        l = migrate(l);
        c = migrate(c);
        r = migrate(r);

        if (!l.length && !c.length && !r.length && ms.active) {
            let order = migrate(ms.active);
            let cIdx = -1;
            for (let i = 0; i < order.length; i++) {
                if (order[i] === "center" || (Array.isArray(order[i]) && order[i].indexOf("center") !== -1)) { cIdx = i; break; }
            }
            for (let i = 0; i < order.length; i++) {
                if (order[i] === "center" || (Array.isArray(order[i]) && order[i].indexOf("center") !== -1)) continue;
                if (cIdx === -1 || i < cIdx) l.push(order[i]);
                else r.push(order[i]);
            }
            c = ["timedate", "info", "weather"];
        }

        function filterCenter(arr) {
            let out = [];
            for (let i = 0; i < arr.length; i++) {
                if (Array.isArray(arr[i])) {
                    let filtered = arr[i].filter(id => id !== "center" && id !== "centerbox");
                    if (filtered.length === 1) out.push(filtered[0]);
                    else if (filtered.length > 1) out.push(filtered);
                } else if (arr[i] !== "center" && arr[i] !== "centerbox") {
                    out.push(arr[i]);
                }
            }
            return out;
        }

        l = filterCenter(l);
        c = filterCenter(c);
        r = filterCenter(r);

        leftModel.clear();
        centerModel.clear();
        rightModel.clear();
        availableModel.clear();

        let used = {};
        function add(arr, model) {
            for (var i = 0; i < arr.length; i++) {
                if (Array.isArray(arr[i])) {
                    var gId = "g_" + arr[i][0];
                    barTabRoot.assignGroupColor(gId);
                    for (var j = 0; j < arr[i].length; j++) {
                        var gModuleId = arr[i][j];
                        if (used[gModuleId]) continue;
                        var info = getModuleInfo(gModuleId);
                        info.groupId = gId;
                        model.append(info);
                        used[gModuleId] = true;
                    }
                } else {
                    var sModuleId = arr[i];
                    if (used[sModuleId]) continue;
                    var info = getModuleInfo(sModuleId);
                    info.groupId = "";
                    model.append(info);
                    used[sModuleId] = true;
                }
            }
        }
        add(l, leftModel);
        add(c, centerModel);
        add(r, rightModel);

        let allKeys = BarModuleRegistry.moduleIds();
        for (let i = 0; i < allKeys.length; i++) {
            if (!used[allKeys[i]]) availableModel.append(getModuleInfo(allKeys[i]));
        }
    }

    function getModel(name) {
        if (name === "left") return leftModel;
        if (name === "center") return centerModel;
        if (name === "right") return rightModel;
        if (name === "available") return availableModel;
        return null;
    }

    function buildModelArray(model) {
        let res = [];
        let currentGroup = [];
        let currentGroupId = "";

        for (let i = 0; i < model.count; i++) {
            let item = model.get(i);
            if (item.isPlaceholder) continue;

            if (item.groupId && item.groupId !== "") {
                if (currentGroupId === item.groupId) {
                    currentGroup.push(item.moduleId);
                } else {
                    if (currentGroup.length > 0) {
                        res.push(currentGroup.length === 1 ? currentGroup[0] : currentGroup);
                    }
                    currentGroupId = item.groupId;
                    currentGroup = [item.moduleId];
                }
            } else {
                if (currentGroup.length > 0) {
                    res.push(currentGroup.length === 1 ? currentGroup[0] : currentGroup);
                    currentGroup = [];
                    currentGroupId = "";
                }
                res.push(item.moduleId);
            }
        }
        if (currentGroup.length > 0) {
            res.push(currentGroup.length === 1 ? currentGroup[0] : currentGroup);
        }
        return res;
    }

    function saveModuleModels() {
        let l = buildModelArray(leftModel);
        let c = buildModelArray(centerModel);
        let r = buildModelArray(rightModel);

        let current = Config.getSetting("bar", barTabRoot.defaultBarSettings);
        current.modules = { "left": l, "center": c, "right": r };
        current.groupColors = barTabRoot.assignedGroupColors;

        barTabRoot.lastSavedModulesString = barTabRoot.getModulesString(current.modules);
        Config.setSetting("bar", current);
    }

    function resetBarSettings() {
        clearPendingGroup();
        let current = Config.getSetting("bar", barTabRoot.defaultBarSettings);
        current.modules = JSON.parse(JSON.stringify(barTabRoot.defaultBarSettings.modules));
        current.groupColors = {};
        current.distinctPills = barTabRoot.defaultBarSettings.distinctPills;
        barTabRoot.assignedGroupColors = {};
        barTabRoot.distinctPills = barTabRoot.defaultBarSettings.distinctPills;
        barTabRoot.lastSavedModulesString = barTabRoot.getModulesString(current.modules);
        Config.setSetting("bar", current);
        barTabRoot.barSettings = current;
        barTabRoot.loadModuleModels();
    }

    function clearPlaceholders() {
        let models = [leftModel, centerModel, rightModel, availableModel];
        for (let m = 0; m < models.length; m++) {
            let model = models[m];
            for (let i = 0; i < model.count; i++) {
                if (model.get(i).isPlaceholder) {
                    model.remove(i, 1);
                    i--;
                }
            }
        }
    }

    function updatePlaceholder(listName, index, width, id, label, icon, sourceListName, sourceModuleId) {
        if (currentPlaceholderList === listName && currentPlaceholderIndex === index) return;

        clearPlaceholders();

        let model = getModel(listName);
        if (model) {
            let rawIndex = index;
            if (listName === sourceListName) {
                for (let i = 0; i < model.count; i++) {
                    let it = model.get(i);
                    if (!it.isPlaceholder && it.moduleId === sourceModuleId) {
                        if (index >= i) rawIndex = index + 1;
                        break;
                    }
                }
            }
            rawIndex = Math.max(0, Math.min(rawIndex, model.count));
            model.insert(rawIndex, {
                moduleId: id,
                moduleLabel: label,
                moduleIcon: icon,
                moduleColor: "#000000",
                isPlaceholder: true,
                placeholderWidth: width,
                groupId: ""
            });
        }
        currentPlaceholderList = listName;
        currentPlaceholderIndex = index;
    }

    function getPendingGroupId() {
        if (barTabRoot.pendingGroupModuleId === "") return "";
        if (barTabRoot.pendingGroupList === "") return "";
        let m = barTabRoot.getModel(barTabRoot.pendingGroupList);
        if (!m) return "";
        for (let i = 0; i < m.count; i++) {
            let it = m.get(i);
            if (it && it.moduleId === barTabRoot.pendingGroupModuleId) return it.groupId || "";
        }
        return "";
    }

    function cleanupGroups() {
        var mList = [leftModel, centerModel, rightModel, availableModel];
        var counts = {};
        var pendingGId = barTabRoot.getPendingGroupId();
        var i = 0;
        var j = 0;

        for (i = 0; i < mList.length; i++) {
            var m = mList[i];
            for (j = 0; j < m.count; j++) {
                var it = m.get(j);
                if (it && it.groupId && it.groupId !== "") {
                    counts[it.groupId] = (counts[it.groupId] || 0) + 1;
                }
            }
        }

        var dissolved = {};
        for (i = 0; i < mList.length; i++) {
            var m = mList[i];
            for (j = 0; j < m.count; j++) {
                var it = m.get(j);
                if (it && it.groupId && it.groupId !== "" && counts[it.groupId] < 2 && it.groupId !== pendingGId) {
                    var gId = it.groupId;
                    if (!dissolved[gId]) {
                        dissolved[gId] = true;
                        if (barTabRoot.assignedGroupColors[gId]) {
                            var newAssigned = Object.assign({}, barTabRoot.assignedGroupColors);
                            delete newAssigned[gId];
                            barTabRoot.assignedGroupColors = newAssigned;
                        }
                    }
                    m.setProperty(j, "groupId", "");
                }
            }
        }
    }

    function uniteElements(pendingId, targetId, listName) {
        if (pendingId === targetId) return;
        let m = barTabRoot.getModel(listName);
        if (!m) return;
        let pIdx = -1;
        let tIdx = -1;

        for (let i = 0; i < m.count; i++) {
            let it = m.get(i);
            if (it && it.moduleId === pendingId && !it.isPlaceholder) pIdx = i;
            if (it && it.moduleId === targetId && !it.isPlaceholder) tIdx = i;
        }

        if (pIdx === -1 || tIdx === -1) return;

        let targetItem = m.get(tIdx);
        let gId = (targetItem && targetItem.groupId) ? targetItem.groupId : "";
        if (!gId || gId === "") {
            gId = "g_" + targetId;
            barTabRoot.assignGroupColor(gId);
            m.setProperty(tIdx, "groupId", gId);
        }

        let pendingItem = m.get(pIdx);
        let pData = {
            moduleId: pendingItem.moduleId,
            moduleLabel: pendingItem.moduleLabel,
            moduleIcon: pendingItem.moduleIcon,
            moduleColor: colorToString(pendingItem.moduleColor),
            isPlaceholder: false,
            placeholderWidth: 0,
            groupId: gId
        };

        let wasBefore = pIdx < tIdx;
        m.remove(pIdx, 1);

        let groupIndices = [];
        for (let i = 0; i < m.count; i++) {
            let it = m.get(i);
            if (it && it.groupId === gId && !it.isPlaceholder) {
                groupIndices.push(i);
            }
        }

        if (groupIndices.length > 0) {
            if (wasBefore) {
                let insertIdx = groupIndices[0];
                m.insert(insertIdx, pData);
            } else {
                let insertIdx = groupIndices[groupIndices.length - 1] + 1;
                m.insert(insertIdx, pData);
            }
        } else {
            m.insert(m.count, pData);
        }

        barTabRoot.cleanupGroups();
        barTabRoot.saveModuleModels();
    }

    function executeDrop(dragSource) {
        let sList = dragSource.listName;
        let sId = dragSource.moduleId;
        let sModel = getModel(sList);
        if (!sModel) return;

        let itemData = null;
        for (let i = 0; i < sModel.count; i++) {
            let item = sModel.get(i);
            if (item && item.moduleId === sId && !item.isPlaceholder) {
                itemData = {
                    moduleId: item.moduleId,
                    moduleLabel: item.moduleLabel,
                    moduleIcon: item.moduleIcon,
                    moduleColor: colorToString(item.moduleColor),
                    isPlaceholder: false,
                    placeholderWidth: 0,
                    groupId: item.groupId || ""
                };
                sModel.remove(i, 1);
                break;
            }
        }

        let tList = currentPlaceholderList;
        let tIdx = currentPlaceholderIndex;

        clearPlaceholders();

        if (itemData && tList !== "") {
            let tModel = getModel(tList);
            if (tModel) {
                tIdx = Math.max(0, Math.min(tIdx, tModel.count));

                if (tList === "available") {
                    itemData.groupId = "";
                } else {
                    let prevItem = (tIdx > 0 && tIdx - 1 < tModel.count) ? tModel.get(tIdx - 1) : null;
                    let nextItem = (tIdx >= 0 && tIdx < tModel.count) ? tModel.get(tIdx) : null;
                    let prevGroup = (prevItem && prevItem.groupId) ? prevItem.groupId : "";
                    let nextGroup = (nextItem && nextItem.groupId) ? nextItem.groupId : "";

                    let joinGroup = "";
                    if (prevGroup !== "" && prevGroup === nextGroup) {
                        joinGroup = prevGroup;
                    } else if (prevGroup !== "" && nextGroup === "") {
                        joinGroup = prevGroup;
                    } else if (nextGroup !== "" && prevGroup === "") {
                        joinGroup = nextGroup;
                    }
                    itemData.groupId = joinGroup;
                }

                tModel.insert(tIdx, itemData);
            }
        } else if (itemData) {
            sModel.insert(sModel.count, itemData);
        }

        currentPlaceholderList = "";
        currentPlaceholderIndex = -1;
        barTabRoot.cleanupGroups();
        saveModuleModels();
    }

    function getDropIndex(flow, mx, my) {
        let count = 0;
        let phIndex = -1;
        let phWidth = 0;
        let hasPlaceholder = false;

        for (let i = 0; i < flow.children.length; i++) {
            let child = flow.children[i];
            if (child.isDelegate && child.isPlaceholder) {
                hasPlaceholder = true;
                phWidth = child.width;
                phIndex = count;
                break;
            }
            if (child.isDelegate && !child.isBeingDragged) {
                count++;
            }
        }

        count = 0;
        let target = 0;
        let found = false;
        for (let i = 0; i < flow.children.length; i++) {
            let child = flow.children[i];
            if (child.isDelegate && !child.isBeingDragged && !child.isPlaceholder) {
                let unshiftedX = child.x;
                if (hasPlaceholder && count >= phIndex) {
                    unshiftedX -= (phWidth + flow.spacing);
                }
                let centerX = unshiftedX + child.width / 2;
                let centerY = child.y + child.height / 2;

                if (!found) {
                    if (Math.abs(my - centerY) < child.height / 2 + flow.spacing / 2) {
                        if (mx < centerX) {
                            target = count;
                            found = true;
                        }
                    } else if (my < child.y) {
                        target = count;
                        found = true;
                    }
                }
                count++;
            }
        }
        if (!found) target = count;
        return target;
    }

    function syncSettings() {
        let ts = Config.getSetting("bar", barTabRoot.defaultBarSettings);
        barTabRoot.barPosition = ts.position !== undefined ? ts.position : "top";
        barTabRoot.currentBarWidth = ts.width !== undefined ? ts.width : 100;
        barTabRoot.currentBarThickness = ts.height !== undefined ? ts.height : 40;
        if (typeof ts.style === "string") {
            barTabRoot.barStyle = ts.style;
        } else if (ts.style && typeof ts.style === "object") {
            if (ts.style.fill || ts.style.mode === "fill") barTabRoot.barStyle = "fill";
            else if (ts.style.solid || ts.style.mode === "solid") barTabRoot.barStyle = "solid";
            else barTabRoot.barStyle = "modular";
        } else {
            barTabRoot.barStyle = "modular";
        }
        barTabRoot.distinctPills = ts.distinctPills !== undefined ? ts.distinctPills : false;
        barTabRoot.centerByEdges = ts.centerByEdges !== undefined ? ts.centerByEdges : true;
        barTabRoot.autohide = ts.autohide !== undefined ? ts.autohide : false;
        barTabRoot.autohideTimeout = ts.autohideTimeout !== undefined ? ts.autohideTimeout : 1000;
        if (ts.groupColors) {
            barTabRoot.assignedGroupColors = ts.groupColors;
        }
        barTabRoot.barSettings = ts;
    }

    Component.onCompleted: {
        syncSettings();
        loadModuleModels();
    }

    Connections {
        target: Config
        function onSettingsLoaded() {
            syncSettings();
            let ts = Config.getSetting("bar", barTabRoot.defaultBarSettings);
            let tsModules = ts.modules || barTabRoot.defaultBarSettings.modules;
            let currentStr = barTabRoot.getModulesString(tsModules);
            if (currentStr === barTabRoot.lastSavedModulesString) {
                return;
            }
            barTabRoot.lastSavedModulesString = "";
            barTabRoot.loadModuleModels();
        }
    }

    function updateBarSettings() {
        let current = Config.getSetting("bar", barTabRoot.defaultBarSettings);
        current.position = barTabRoot.barPosition;
        current.width = barTabRoot.currentBarWidth;
        current.height = barTabRoot.currentBarThickness;
        current.style = barTabRoot.barStyle;
        current.distinctPills = barTabRoot.distinctPills;
        current.centerByEdges = barTabRoot.centerByEdges;
        current.autohide = barTabRoot.autohide;
        current.autohideTimeout = barTabRoot.autohideTimeout;
        if (!current.modules) current.modules = barTabRoot.defaultBarSettings.modules;
        current.groupColors = barTabRoot.assignedGroupColors;

        barTabRoot.lastSavedModulesString = barTabRoot.getModulesString(current.modules);
        Config.setSetting("bar", current);
    }
}
