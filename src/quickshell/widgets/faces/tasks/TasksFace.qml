import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../../../reusables"
import "../../../"

Item {
    id: root
    anchors.fill: parent
    implicitWidth: 380
    implicitHeight: 400
    clip: true

    property real minWidth: 340
    property real minHeight: 340
    property real maxWidth: 650
    property real maxHeight: 650
    property real minAspect: 0.5
    property real maxAspect: 2.5
    property bool isRound: false

    property string nerdFont: ThemeBackend.iconFont

    property string methodology: "scrum" // "scrum" | "kanban" | "simple"
    property string activeFilterStage: "sprint" // "backlog" | "sprint" | "in_progress" | "done" | "todo" | "pending"
    property string cycleName: ""
    property string cycleGoal: ""
    property int wipLimit: 2
    property var tasksList: []

    // Keyboard Focus properties for Widget.qml layershell
    property bool wantsKeyboardFocus: isFormOpen || isEditingCycle || isSearchOpen
    property bool keyboardFocus: wantsKeyboardFocus
    property bool isEditingUser: wantsKeyboardFocus

    // Milestone Completion Notification
    property real lastMilestoneNotif: 0

    // Instant Search State
    property bool isSearchOpen: false
    property string searchQuery: ""

    // Self-save race condition flag
    property bool isSaving: false

    // In-widget Form State for Add / Edit
    property bool isFormOpen: false
    property string editingTaskId: ""
    property string formTitle: ""
    property string formDescription: ""
    property int formPoints: 1
    property string formPriority: "medium"
    property string formStatus: "sprint"

    // Inline Cycle Name / Goal editing
    property bool isEditingCycle: false
    property string cycleNameInput: ""
    property string cycleGoalInput: ""

    Timer {
        id: focusInputTimer
        interval: 30
        repeat: false
        onTriggered: {
            if (root.isFormOpen && formTitleInput.visible) {
                formTitleInput.forceActiveFocus();
            } else if (root.isEditingCycle && cycleNameEditInput.visible) {
                cycleNameEditInput.forceActiveFocus();
            } else if (root.isSearchOpen && searchTextInput.visible) {
                searchTextInput.forceActiveFocus();
            }
        }
    }

    function getMethodologyInfo() {
        if (root.methodology === "kanban") {
            return {
                name: "Kanban",
                icon: "󰕰",
                tag: "KANBAN",
                color: ThemeBackend.blue,
                badgeText: root.isWipExceeded ? "WIP EXCEDIDO" : "WIP SALUDABLE",
                badgeColor: root.isWipExceeded ? ThemeBackend.red : ThemeBackend.peach
            };
        } else if (root.methodology === "simple") {
            return {
                name: "Simple",
                icon: "󰄲",
                tag: "SIMPLE",
                color: ThemeBackend.green,
                badgeText: "CHECKLIST",
                badgeColor: ThemeBackend.green
            };
        }
        return {
            name: "Scrum",
            icon: "󰮯",
            tag: "SCRUM",
            color: ThemeBackend.mauve,
            badgeText: "SPRINT ACTIVO",
            badgeColor: ThemeBackend.mauve
        };
    }

    function setMethodology(m) {
        if (root.methodology === m) return;
        root.methodology = m;

        if (m === "scrum") {
            root.activeFilterStage = "sprint";
        } else if (m === "kanban") {
            root.activeFilterStage = "in_progress";
        } else if (m === "simple") {
            root.activeFilterStage = "pending";
        }

        if (typeof Sounds !== "undefined" && typeof Sounds.playSfx === "function") {
            Sounds.playSfx("reusables/toggle/sfx.wav", 0.6);
        }

        root.saveUpdatedTasks(root.tasksList);
    }

    function getTaskEffectiveStatus(t) {
        if (!t) return "todo";
        let st = (t.status || "todo").toLowerCase();
        if (st === "pending") st = "todo";
        if (st === "completed") st = "done";
        if (root.methodology === "kanban") {
            if (st === "backlog" || st === "sprint") return "todo";
            return st;
        } else if (root.methodology === "simple") {
            if (st === "done") return "done";
            return "todo";
        }
        if (st === "todo") return "sprint";
        return st;
    }

    function getPriorityColor(pr) {
        let p = (pr || "medium").toLowerCase();
        if (p === "urgent" || p === "urgente") return ThemeBackend.red;
        if (p === "high" || p === "alta") return ThemeBackend.peach;
        if (p === "medium" || p === "media") return ThemeBackend.blue;
        return ThemeBackend.subtext0;
    }

    function getPriorityLabel(pr) {
        let p = (pr || "medium").toLowerCase();
        if (p === "urgent" || p === "urgente") return "Urgente";
        if (p === "high" || p === "alta") return "Alta";
        if (p === "medium" || p === "media") return "Media";
        return "Baja";
    }

    function getTaskOriginInfo(t) {
        let orig = (t && t.origin) ? t.origin : "";
        if (!orig) {
            if (t && Number(t.points) > 0) orig = "scrum";
            else if (t && (t.status === "backlog" || t.status === "sprint")) orig = "scrum";
            else orig = root.methodology;
        }
        orig = String(orig).toLowerCase();
        if (orig === "kanban") {
            return { tag: "ORIGEN: KANBAN", shortTag: "KANBAN", color: ThemeBackend.blue };
        }
        if (orig === "simple") {
            return { tag: "ORIGEN: SIMPLE", shortTag: "SIMPLE", color: ThemeBackend.green };
        }
        return { tag: "ORIGEN: SCRUM", shortTag: "SCRUM", color: ThemeBackend.mauve };
    }

    readonly property var inProgressTasks: (tasksList || []).filter(t => t && getTaskEffectiveStatus(t) === "in_progress")
    readonly property var sprintTasks: (tasksList || []).filter(t => t && (t.status === "sprint" || (root.methodology === "scrum" && t.status === "todo")))
    readonly property var backlogTasks: (tasksList || []).filter(t => t && t.status === "backlog")
    readonly property var todoTasks: (tasksList || []).filter(t => t && getTaskEffectiveStatus(t) === "todo")
    readonly property var doneTasks: (tasksList || []).filter(t => t && getTaskEffectiveStatus(t) === "done")

    readonly property var activeScopeTasks: {
        let list = tasksList || [];
        if (root.methodology === "scrum") {
            return list.filter(t => {
                let s = getTaskEffectiveStatus(t);
                return s === "sprint" || s === "in_progress" || s === "done";
            });
        }
        return list;
    }

    readonly property int totalScopePoints: {
        let pts = 0;
        let list = activeScopeTasks || [];
        for (let i = 0; i < list.length; i++) {
            if (list[i]) pts += (Number(list[i].points) || 0);
        }
        return pts;
    }

    readonly property int completedScopePoints: {
        let pts = 0;
        let list = doneTasks || [];
        for (let i = 0; i < list.length; i++) {
            if (list[i]) pts += (Number(list[i].points) || 0);
        }
        return pts;
    }

    readonly property real progressRatio: {
        let inProg = inProgressTasks || [];
        let done = doneTasks || [];
        let total = tasksList || [];
        let actScope = activeScopeTasks || [];
        if (root.methodology === "kanban") {
            return root.wipLimit > 0 ? Math.min(1.0, inProg.length / root.wipLimit) : 0.0;
        }
        if (root.methodology === "simple") {
            return total.length > 0 ? Math.min(1.0, done.length / total.length) : 0.0;
        }
        if (totalScopePoints > 0) {
            return Math.min(1.0, completedScopePoints / totalScopePoints);
        }
        if (actScope.length > 0) {
            return Math.min(1.0, done.length / actScope.length);
        }
        return 0.0;
    }

    readonly property int progressPercent: Math.round(progressRatio * 100)
    readonly property bool isWipExceeded: (root.methodology === "kanban" || root.methodology === "scrum") && ((inProgressTasks || []).length > wipLimit)

    function matchesSearch(t) {
        if (!t) return false;
        let q = (root.searchQuery || "").trim().toLowerCase();
        if (!q) return true;
        let title = (t.title || "").toLowerCase();
        let desc = (t.description || "").toLowerCase();
        return title.indexOf(q) !== -1 || desc.indexOf(q) !== -1;
    }

    readonly property var activeHeroTask: {
        if (root.methodology === "simple") return null;

        let getCandidates = function(list) {
            return (list || []).filter(function(t) { return t && root.matchesSearch(t); });
        };

        if (root.activeFilterStage === "backlog") {
            let bkl = getCandidates(backlogTasks);
            return bkl.length > 0 ? bkl[0] : null;
        }
        if (root.activeFilterStage === "sprint") {
            let spr = getCandidates(sprintTasks);
            return spr.length > 0 ? spr[0] : null;
        }
        if (root.activeFilterStage === "in_progress") {
            let inProg = getCandidates(inProgressTasks);
            return inProg.length > 0 ? inProg[0] : null;
        }
        if (root.activeFilterStage === "done") {
            let done = getCandidates(doneTasks);
            return done.length > 0 ? done[0] : null;
        }
        if (root.activeFilterStage === "todo") {
            let todo = getCandidates(todoTasks);
            return todo.length > 0 ? todo[0] : null;
        }

        let inProg = getCandidates(inProgressTasks);
        if (inProg.length > 0) return inProg[0];
        let spr = getCandidates(sprintTasks);
        if (root.methodology === "scrum" && spr.length > 0) return spr[0];
        let todo = getCandidates(todoTasks);
        if (todo.length > 0) return todo[0];
        let uncompleted = (tasksList || []).filter(function(t) { return t && t.status !== "done" && root.matchesSearch(t); });
        if (uncompleted.length > 0) return uncompleted[0];
        let allMatching = (tasksList || []).filter(function(t) { return t && root.matchesSearch(t); });
        if (allMatching.length > 0) return allMatching[0];
        return null;
    }

    readonly property var filteredQueueTasks: {
        if (root.methodology === "simple") return [];
        let heroId = activeHeroTask ? activeHeroTask.id : "";

        let filterList = function(list) {
            return (list || []).filter(function(t) { return t && t.id !== heroId && root.matchesSearch(t); });
        };

        if (root.activeFilterStage === "backlog") {
            return filterList(backlogTasks);
        }
        if (root.activeFilterStage === "sprint") {
            return filterList(sprintTasks);
        }
        if (root.activeFilterStage === "in_progress") {
            return filterList(inProgressTasks);
        }
        if (root.activeFilterStage === "done") {
            return filterList(doneTasks);
        }
        if (root.activeFilterStage === "todo") {
            return filterList(todoTasks);
        }

        let list = (tasksList || []).filter(function(t) { return t && root.matchesSearch(t); });
        let uncompleted = list.filter(function(t) { return t && t.status !== "done" && t.id !== heroId; });
        if (uncompleted.length === 0) {
            return list.filter(function(t) { return t && t.id !== heroId; });
        }
        return uncompleted;
    }

    function alpha(color, a) { return Qt.rgba(color.r, color.g, color.b, a); }

    function toBase64(str) {
        let chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=";
        let utf8 = [];
        for (let i = 0; i < str.length; i++) {
            let c = str.charCodeAt(i);
            if (c < 128) {
                utf8.push(c);
            } else if (c < 2048) {
                utf8.push((c >> 6) | 192, (c & 63) | 128);
            } else if (((c & 0xFC00) === 0xD800) && (i + 1 < str.length) && ((str.charCodeAt(i + 1) & 0xFC00) === 0xDC00)) {
                let c2 = str.charCodeAt(++i);
                let cp = 0x10000 + (((c & 0x3FF) << 10) | (c2 & 0x3FF));
                utf8.push((cp >> 18) | 240, ((cp >> 12) & 63) | 128, ((cp >> 6) & 63) | 128, (cp & 63) | 128);
            } else {
                utf8.push((c >> 12) | 224, ((c >> 6) & 63) | 128, (c & 63) | 128);
            }
        }
        let res = "";
        let idx = 0;
        while (idx < utf8.length) {
            let b1 = utf8[idx++];
            let b2 = idx < utf8.length ? utf8[idx++] : NaN;
            let b3 = idx < utf8.length ? utf8[idx++] : NaN;
            let e1 = b1 >> 2;
            let e2 = ((b1 & 3) << 4) | (isNaN(b2) ? 0 : b2 >> 4);
            let e3 = isNaN(b2) ? 64 : (((b2 & 15) << 2) | (isNaN(b3) ? 0 : b3 >> 6));
            let e4 = isNaN(b3) ? 64 : (b3 & 63);
            res += chars.charAt(e1) + chars.charAt(e2) + chars.charAt(e3) + chars.charAt(e4);
        }
        return res;
    }

    function parseTasksData(rawText) {
        let txt = (rawText || "").trim();
        if (txt === "" || txt === "{}") {
            root.tasksList = [];
            return;
        }
        try {
            let data = JSON.parse(txt);
            if (!data) return;
            if (Array.isArray(data)) {
                root.tasksList = data.filter(t => t && typeof t === "object" && t.id !== undefined);
                return;
            }
            if (typeof data !== "object") return;
            if (data.methodology && typeof data.methodology === "string") {
                let m = data.methodology.toLowerCase();
                if (m === "scrum" || m === "kanban" || m === "simple") {
                    root.methodology = m;
                }
            }

            if (data.cycleName !== undefined) root.cycleName = String(data.cycleName || "");
            else if (data.sprint && data.sprint.name !== undefined) root.cycleName = String(data.sprint.name || "");

            if (data.cycleGoal !== undefined) root.cycleGoal = String(data.cycleGoal || "");
            else if (data.sprint && data.sprint.goal !== undefined) root.cycleGoal = String(data.sprint.goal || "");

            if (data.wipLimit !== undefined) root.wipLimit = Math.max(1, Number(data.wipLimit) || 2);
            if (Array.isArray(data.tasks)) {
                root.tasksList = data.tasks.filter(t => t && typeof t === "object" && t.id !== undefined);
            } else {
                root.tasksList = [];
            }

            // Ensure activeFilterStage matches loaded methodology
            if (root.methodology === "scrum") {
                if (!["backlog", "sprint", "in_progress", "done"].includes(root.activeFilterStage)) {
                    root.activeFilterStage = "sprint";
                }
            } else if (root.methodology === "kanban") {
                if (!["todo", "in_progress", "done"].includes(root.activeFilterStage)) {
                    root.activeFilterStage = "in_progress";
                }
            } else if (root.methodology === "simple") {
                if (!["pending", "done"].includes(root.activeFilterStage)) {
                    root.activeFilterStage = "pending";
                }
            }
        } catch (e) {
            console.warn("[TasksFace.qml] Error reading tasks data:", e);
        }
    }

    function saveUpdatedTasks(updatedList) {
        root.isSaving = true;
        root.tasksList = updatedList;
        let dir = (typeof Caching !== "undefined" && Caching.stateDir ? Caching.stateDir : ((Quickshell.env("HOME") || "") + "/.local/state/serpantinum")) + "/quickactions";
        let payload = {
            methodology: root.methodology,
            cycleName: root.cycleName || "",
            cycleGoal: root.cycleGoal || "",
            sprint: { name: root.cycleName || "", goal: root.cycleGoal || "" },
            wipLimit: root.wipLimit,
            tasks: updatedList
        };
        let jsonStr = JSON.stringify(payload, null, 2);
        let b64 = toBase64(jsonStr);
        saveProc.running = false;
        saveProc.command = ["bash", "-c", "mkdir -p '" + dir + "' && printf '%s' '" + b64 + "' | base64 -d > '" + dir + "/tasks.json.tmp' && mv -f '" + dir + "/tasks.json.tmp' '" + dir + "/tasks.json'"];
        saveProc.running = true;
    }

    Process {
        id: saveProc
        onExited: resetSavingTimer.restart()
    }

    Timer {
        id: resetSavingTimer
        interval: 100
        repeat: false
        onTriggered: root.isSaving = false
    }

    function handleFileLoaded() {
        if (root.isSaving) return;
        let tasksTxt = "";
        let scrumTxt = "";
        try {
            tasksTxt = (typeof tasksWatch.text === "function" ? tasksWatch.text() : tasksWatch.text) || "";
        } catch (e) {}
        try {
            scrumTxt = (typeof scrumWatch.text === "function" ? scrumWatch.text() : scrumWatch.text) || "";
        } catch (e) {}

        if (tasksTxt && tasksTxt.trim() !== "" && tasksTxt.trim() !== "{}") {
            root.parseTasksData(tasksTxt);
        } else if (scrumTxt && scrumTxt.trim() !== "" && scrumTxt.trim() !== "{}") {
            root.parseTasksData(scrumTxt);
        }
    }

    FileView {
        id: tasksWatch
        path: (typeof Caching !== "undefined" && Caching.stateDir ? Caching.stateDir : ((Quickshell.env("HOME") || "") + "/.local/state/serpantinum")) + "/quickactions/tasks.json"
        watchChanges: true
        onLoaded: root.handleFileLoaded()
        onFileChanged: {
            if (!root.isSaving) tasksWatch.reload();
        }
    }

    FileView {
        id: scrumWatch
        path: (typeof Caching !== "undefined" && Caching.stateDir ? Caching.stateDir : ((Quickshell.env("HOME") || "") + "/.local/state/serpantinum")) + "/quickactions/scrum.json"
        watchChanges: true
        onLoaded: root.handleFileLoaded()
        onFileChanged: {
            if (!root.isSaving) scrumWatch.reload();
        }
    }

    Component.onCompleted: {
        root.handleFileLoaded();
    }

    // CRUD Helper Functions
    function openCreateForm() {
        root.editingTaskId = "";
        root.formTitle = "";
        root.formDescription = "";
        root.formPoints = root.methodology === "scrum" ? 1 : 0;
        root.formPriority = "medium";
        if (root.methodology === "scrum") {
            root.formStatus = (root.activeFilterStage === "backlog") ? "backlog" : (root.activeFilterStage === "in_progress" ? "in_progress" : (root.activeFilterStage === "done" ? "done" : "sprint"));
        } else if (root.methodology === "kanban") {
            root.formStatus = (root.activeFilterStage === "in_progress") ? "in_progress" : (root.activeFilterStage === "done" ? "done" : "todo");
        } else {
            root.formStatus = (root.activeFilterStage === "done") ? "done" : "todo";
        }
        root.isFormOpen = true;
        focusInputTimer.restart();
    }

    function openEditForm(task) {
        if (!task) return;
        root.editingTaskId = task.id;
        root.formTitle = task.title || "";
        root.formDescription = task.description || "";
        root.formPoints = Number(task.points) || (root.methodology === "scrum" ? 1 : 0);
        root.formPriority = task.priority || "medium";
        root.formStatus = task.status || "todo";
        root.isFormOpen = true;
        focusInputTimer.restart();
    }

    function closeForm() {
        root.isFormOpen = false;
        root.editingTaskId = "";
        root.formTitle = "";
        root.formDescription = "";
    }

    function saveFormTask() {
        let trimmed = (root.formTitle || "").trim();
        if (trimmed === "") return;

        let descTrimmed = (root.formDescription || "").trim();
        let list = (root.tasksList || []).slice();
        let targetStatus = root.formStatus;
        if (targetStatus === "pending") targetStatus = "todo";
        if (targetStatus === "completed") targetStatus = "done";

        let isDoneSaved = false;
        if (root.editingTaskId !== "") {
            for (let i = 0; i < list.length; i++) {
                if (list[i] && list[i].id === root.editingTaskId) {
                    let updated = Object.assign({}, list[i]);
                    updated.title = trimmed;
                    updated.description = descTrimmed;
                    updated.points = root.formPoints;
                    updated.priority = root.formPriority;
                    let oldStatus = updated.status;
                    updated.status = targetStatus;
                    if (targetStatus === "done" && oldStatus !== "done") {
                        updated.completedAt = Date.now();
                        isDoneSaved = true;
                    } else if (targetStatus !== "done") {
                        delete updated.completedAt;
                    }
                    list[i] = updated;
                    break;
                }
            }
            if (typeof Sounds !== "undefined" && typeof Sounds.playSfx === "function") {
                Sounds.playSfx("reusables/clickbutton/click.wav", 0.8);
            }
        } else {
            let newTask = {
                id: "task_" + Date.now() + "_" + Math.floor(Math.random() * 1000),
                title: trimmed,
                description: descTrimmed,
                points: root.formPoints,
                priority: root.formPriority,
                status: targetStatus,
                origin: root.methodology,
                createdAt: Date.now()
            };
            if (targetStatus === "done") {
                newTask.completedAt = Date.now();
                isDoneSaved = true;
            }
            list.unshift(newTask);
            if (typeof Sounds !== "undefined" && typeof Sounds.playSfx === "function") {
                Sounds.playSfx("reusables/clickbutton/click2.wav", 0.9);
            }
        }
        closeForm();
        if (isDoneSaved) {
            root.checkMilestoneCompletion(list);
        }
        saveUpdatedTasks(list);
    }

    function deleteTask(taskId) {
        if (!taskId) return;
        let list = (root.tasksList || []).filter(t => t && t.id !== taskId);
        if (root.editingTaskId === taskId) {
            closeForm();
        }
        if (typeof Sounds !== "undefined" && typeof Sounds.playSfx === "function") {
            Sounds.playSfx("guide/barconfig/out.wav", 0.8);
        }
        saveUpdatedTasks(list);
    }

    function getNextStatus(status) {
        let curr = (status || "").toLowerCase();
        if (root.methodology === "kanban") {
            if (curr === "todo" || curr === "backlog" || curr === "sprint") return "in_progress";
            if (curr === "in_progress") return "done";
            return "done";
        } else if (root.methodology === "simple") {
            return "done";
        }
        // scrum:
        if (curr === "backlog") return "sprint";
        if (curr === "sprint" || curr === "todo") return "in_progress";
        if (curr === "in_progress") return "done";
        return "done";
    }

    function getPrevStatus(status) {
        let curr = (status || "").toLowerCase();
        if (root.methodology === "kanban") {
            if (curr === "done") return "in_progress";
            if (curr === "in_progress") return "todo";
            return "todo";
        } else if (root.methodology === "simple") {
            return "todo";
        }
        // scrum:
        if (curr === "done") return "in_progress";
        if (curr === "in_progress") return "sprint";
        if (curr === "sprint") return "backlog";
        return "backlog";
    }

    function checkMilestoneCompletion(customList) {
        let list = customList || root.tasksList || [];
        if (!list || list.length === 0) return;

        let isCompleted = false;
        if (root.methodology === "scrum") {
            // Sprint items are those with effective status in sprint, in_progress, or done
            let sprintItems = list.filter(function(t) {
                let s = root.getTaskEffectiveStatus(t);
                return s === "sprint" || s === "in_progress" || s === "done";
            });
            if (sprintItems.length > 0) {
                let allDone = sprintItems.every(function(t) {
                    return root.getTaskEffectiveStatus(t) === "done";
                });
                if (allDone) isCompleted = true;
            }
        } else if (root.methodology === "simple" || root.methodology === "kanban") {
            // All active tasks completed
            let allDone = list.every(function(t) {
                return root.getTaskEffectiveStatus(t) === "done";
            });
            if (allDone) isCompleted = true;
        }

        if (isCompleted) {
            let now = Date.now();
            if (now - root.lastMilestoneNotif >= 15000) {
                root.lastMilestoneNotif = now;
                let summary = (typeof I18n !== "undefined" && typeof I18n.t === "function") ? I18n.t("widgets.tasks.milestone.summary") : "Sprint Completed";
                let body = (typeof I18n !== "undefined" && typeof I18n.t === "function") ? I18n.t("widgets.tasks.milestone.body") : "Great job! All sprint tasks have been completed.";
                if (typeof Quickshell !== "undefined" && typeof Quickshell.execDetached === "function") {
                    Quickshell.execDetached(["notify-send", "-a", "Serpantinum", "-u", "normal", "-i", "checkbox-checked-symbolic", summary, body]);
                }
                if (typeof Sounds !== "undefined" && typeof Sounds.playSfx === "function") {
                    Sounds.playSfx("notifications/Botanica.wav", 0.9);
                }
            }
        }
    }

    function updateTaskStatus(taskId, newStatus) {
        if (taskId === undefined || taskId === null) return;
        let isDoneTransition = false;
        let isRevertTransition = false;
        let updated = (root.tasksList || []).map(t => {
            if (t && t.id === taskId) {
                let copy = Object.assign({}, t, { status: newStatus });
                if (newStatus === "done") {
                    copy.completedAt = Date.now();
                    isDoneTransition = true;
                } else {
                    if (t.status === "done") isRevertTransition = true;
                    delete copy.completedAt;
                }
                return copy;
            }
            return t;
        });

        if (typeof Sounds !== "undefined" && typeof Sounds.playSfx === "function") {
            if (isDoneTransition) {
                Sounds.playSfx("notifications/Progress.wav", 0.8);
            } else if (isRevertTransition) {
                Sounds.playSfx("reusables/switch/sfx.wav", 0.7);
            } else {
                Sounds.playSfx("reusables/draggable/tick.wav", 0.7);
            }
        }

        if (isDoneTransition) {
            root.checkMilestoneCompletion(updated);
        }

        saveUpdatedTasks(updated);
    }

    function markTaskDone(taskId) {
        root.updateTaskStatus(taskId, "done");
    }

    function advanceTask(task) {
        if (!task) return;
        let t = (typeof task === "object") ? task : (root.tasksList || []).find(item => item && item.id === task);
        if (!t || t.id === undefined) return;
        let curr = (t.status || "todo").toLowerCase();
        if (curr === "done") {
            root.reopenTask(t.id);
        } else if (curr === "in_progress") {
            root.markTaskDone(t.id);
        } else if (root.methodology === "scrum" && curr === "backlog") {
            root.updateTaskStatus(t.id, "sprint");
        } else {
            root.updateTaskStatus(t.id, "in_progress");
        }
    }

    function startTask(taskId) {
        if (!taskId) return;
        let id = (typeof taskId === "object" && taskId.id !== undefined) ? taskId.id : taskId;
        let t = (root.tasksList || []).find(item => item && item.id === id);
        let curr = t ? (t.status || "todo").toLowerCase() : "todo";
        if (root.methodology === "scrum" && curr === "backlog") {
            root.updateTaskStatus(id, "sprint");
        } else {
            root.updateTaskStatus(id, "in_progress");
        }
    }

    function reopenTask(taskId) {
        let targetStatus = (root.methodology === "scrum") ? "sprint" : "todo";
        root.updateTaskStatus(taskId, targetStatus);
    }

    function openCycleEdit() {
        root.cycleNameInput = root.cycleName || "";
        root.cycleGoalInput = root.cycleGoal || "";
        root.isEditingCycle = true;
        focusInputTimer.restart();
    }

    function saveCycleEdit() {
        root.cycleName = root.cycleNameInput.trim();
        root.cycleGoal = root.cycleGoalInput.trim();
        root.isEditingCycle = false;
        root.saveUpdatedTasks(root.tasksList);
    }

    function cancelCycleEdit() {
        root.isEditingCycle = false;
    }

    function openTasksPanel() {
        if (typeof FloatingController !== "undefined" && typeof FloatingController.showTasks === "function") {
            FloatingController.showTasks(root.Window.window ? root.Window.window.screen : null);
        } else if (typeof FloatingController !== "undefined" && typeof FloatingController.showScrum === "function") {
            FloatingController.showScrum(root.Window.window ? root.Window.window.screen : null);
        } else if (typeof FloatingController !== "undefined" && typeof FloatingController.setIndex === "function") {
            FloatingController.setIndex(3, root.Window.window ? root.Window.window.screen : null);
        }
    }

    // Main Desktop Widget Layout
    Rectangle {
        id: bg
        anchors.fill: parent
        radius: ThemeBackend.clampedBorderRadius
        color: Qt.alpha(ThemeBackend.surface0, ThemeBackend.elementOpacity)
        border.color: ThemeBackend.surface1
        border.width: 1
        clip: true

        WallpaperBlur {
            z: -1
            anchors.fill: parent
            radius: parent.radius
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 8

            // 1. Header (Row 1): 3-mode pill switcher (SCRUM | KANBAN | SIMPLE) + Metric badge + Add (+) + Drawer
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                // Switcher de Metodología (Scrum / Kanban / Simple)
                Rectangle {
                    implicitWidth: switchRow.width + 6
                    implicitHeight: 24
                    Layout.preferredWidth: implicitWidth
                    Layout.preferredHeight: implicitHeight
                    radius: 12
                    color: ThemeBackend.surface0
                    border.color: ThemeBackend.surface1
                    border.width: 1

                    Row {
                        id: switchRow
                        anchors.centerIn: parent
                        spacing: 2

                        Repeater {
                            model: [
                                { id: "scrum", label: "SCRUM", color: ThemeBackend.mauve },
                                { id: "kanban", label: "KANBAN", color: ThemeBackend.blue },
                                { id: "simple", label: "SIMPLE", color: ThemeBackend.green }
                            ]

                            delegate: Rectangle {
                                width: btnText.implicitWidth + 16
                                height: 20
                                radius: 10
                                color: root.methodology === modelData.id ? modelData.color : (btnMa.containsMouse ? root.alpha(ThemeBackend.surface1, 0.5) : "transparent")

                                Text {
                                    id: btnText
                                    anchors.centerIn: parent
                                    text: modelData.label
                                    font.family: ThemeBackend.fontFamily
                                    font.pixelSize: 9
                                    font.bold: true
                                    color: root.methodology === modelData.id ? ThemeBackend.crust : ThemeBackend.subtext0
                                }

                                MouseArea {
                                    id: btnMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.setMethodology(modelData.id)
                                }
                            }
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                // Metric Badge
                Text {
                    text: {
                        if (root.methodology === "kanban") {
                            return "WIP: " + root.inProgressTasks.length + "/" + root.wipLimit + " MÁX";
                        }
                        if (root.methodology === "simple") {
                            return root.doneTasks.length + "/" + (root.tasksList ? root.tasksList.length : 0) + " Hechas";
                        }
                        if (root.totalScopePoints > 0) {
                            return root.completedScopePoints + "/" + root.totalScopePoints + " pts (" + root.progressPercent + "%)";
                        }
                        return root.doneTasks.length + "/" + (root.activeScopeTasks ? root.activeScopeTasks.length : 0) + " (" + root.progressPercent + "%)";
                    }
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: 11
                    font.bold: true
                    color: {
                        if (root.methodology === "kanban") {
                            return root.isWipExceeded ? ThemeBackend.red : ThemeBackend.peach;
                        }
                        if (root.methodology === "simple") {
                            return ThemeBackend.green;
                        }
                        return root.progressPercent >= 100 ? ThemeBackend.green : ThemeBackend.mauve;
                    }
                }

                // Search Toggle Button (24x24)
                Rectangle {
                    width: 24
                    height: 24
                    radius: 6
                    color: root.isSearchOpen ? root.getMethodologyInfo().color : (searchBtnMa.containsMouse ? root.alpha(root.getMethodologyInfo().color, 0.25) : ThemeBackend.surface0)
                    border.color: root.isSearchOpen ? root.getMethodologyInfo().color : ThemeBackend.surface1
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "󰍉"
                        font.family: root.nerdFont
                        font.pixelSize: 13
                        color: root.isSearchOpen ? ThemeBackend.crust : (searchBtnMa.containsMouse ? root.getMethodologyInfo().color : ThemeBackend.subtext0)
                    }

                    MouseArea {
                        id: searchBtnMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.isSearchOpen = !root.isSearchOpen;
                            if (root.isSearchOpen) {
                                focusInputTimer.restart();
                            } else {
                                root.searchQuery = "";
                            }
                        }
                    }
                }

                // Add Task Button (+)
                Rectangle {
                    width: 24
                    height: 24
                    radius: 6
                    color: root.isFormOpen ? root.getMethodologyInfo().color : (addBtnMa.containsMouse ? root.alpha(root.getMethodologyInfo().color, 0.25) : ThemeBackend.surface0)
                    border.color: root.isFormOpen ? root.getMethodologyInfo().color : ThemeBackend.surface1
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "󰐕"
                        font.family: root.nerdFont
                        font.pixelSize: 13
                        color: root.isFormOpen ? ThemeBackend.crust : (addBtnMa.containsMouse ? root.getMethodologyInfo().color : ThemeBackend.text)
                    }

                    MouseArea {
                        id: addBtnMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.isFormOpen && root.editingTaskId === "") {
                                root.closeForm();
                            } else {
                                root.openCreateForm();
                            }
                        }
                    }
                }

                // Quickaction drawer trigger
                Rectangle {
                    width: 24
                    height: 24
                    radius: 6
                    color: openMa.containsMouse ? ThemeBackend.surface1 : ThemeBackend.surface0
                    border.color: ThemeBackend.surface1
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "󰍜"
                        font.family: root.nerdFont
                        font.pixelSize: 13
                        color: ThemeBackend.subtext0
                    }

                    MouseArea {
                        id: openMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.openTasksPanel()
                    }
                }
            }

            // Search Bar (renders when isSearchOpen is true)
            Rectangle {
                id: searchBarContainer
                visible: root.isSearchOpen
                Layout.fillWidth: true
                Layout.preferredHeight: 30
                radius: ThemeBackend.borderRadius
                color: ThemeBackend.surface0
                border.color: ThemeBackend.surface1
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 6

                    Text {
                        text: "󰍉"
                        font.family: root.nerdFont
                        font.pixelSize: 12
                        color: ThemeBackend.subtext0
                    }

                    TextInput {
                        id: searchTextInput
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        verticalAlignment: TextInput.AlignVCenter
                        text: root.searchQuery
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: 11
                        color: ThemeBackend.text
                        clip: true
                        selectByMouse: true
                        activeFocusOnTab: true

                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            visible: !searchTextInput.text && !searchTextInput.inputMethodComposing
                            text: (typeof I18n !== "undefined" && typeof I18n.t === "function") ? I18n.t("widgets.tasks.search_placeholder") : "Search tasks..."
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: 11
                            color: ThemeBackend.subtext0
                        }

                        onTextChanged: {
                            root.searchQuery = text;
                        }

                        Keys.onEscapePressed: function(event) {
                            root.searchQuery = "";
                            root.isSearchOpen = false;
                            event.accepted = true;
                        }
                    }

                    // Clear button (visible when query is not empty)
                    Rectangle {
                        visible: root.searchQuery.trim().length > 0
                        width: 18
                        height: 18
                        radius: 9
                        color: clearMa.containsMouse ? ThemeBackend.surface1 : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "󰅖"
                            font.family: root.nerdFont
                            font.pixelSize: 11
                            color: clearMa.containsMouse ? ThemeBackend.text : ThemeBackend.subtext0
                        }

                        MouseArea {
                            id: clearMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                searchTextInput.text = "";
                                root.searchQuery = "";
                                searchTextInput.forceActiveFocus();
                            }
                        }
                    }
                }
            }

            // 2. Full-width Progress Bar (Row 2)
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 5
                radius: 3
                color: ThemeBackend.surface1
                clip: true

                Rectangle {
                    height: parent.height
                    width: parent.width * Math.max(0.0, Math.min(1.0, root.progressRatio))
                    radius: 3
                    color: {
                        if (root.methodology === "kanban") {
                            return root.isWipExceeded ? ThemeBackend.red : ThemeBackend.peach;
                        }
                        if (root.methodology === "simple") {
                            return ThemeBackend.green;
                        }
                        return root.progressRatio >= 1.0 ? ThemeBackend.green : ThemeBackend.mauve;
                    }

                    Behavior on width {
                        NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                    }
                }
            }

            // 3. Subheader Contextual (Banner with 3px left accent border, clickable to edit)
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: root.isEditingCycle ? 56 : 36
                radius: 8
                color: ThemeBackend.surface0
                border.color: root.isEditingCycle ? root.getMethodologyInfo().color : ThemeBackend.surface1
                border.width: 1

                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 3
                    radius: 2
                    color: root.getMethodologyInfo().color
                }

                // Normal View Mode
                MouseArea {
                    anchors.fill: parent
                    visible: !root.isEditingCycle
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openCycleEdit()

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 6

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Text {
                                text: {
                                    if (root.cycleName && root.cycleName.trim() !== "") return root.cycleName;
                                    if (root.methodology === "scrum") return "Sprint 1 • Wayland Suite";
                                    if (root.methodology === "kanban") return "Tablero Kanban Continuo";
                                    return "Lista de Tareas Personal";
                                }
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: 11
                                font.bold: true
                                color: ThemeBackend.text
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Text {
                                text: {
                                    if (root.cycleGoal && root.cycleGoal.trim() !== "") return root.cycleGoal;
                                    if (root.methodology === "scrum") return "Meta: Pulir interfaz y widgets de productividad";
                                    if (root.methodology === "kanban") return "Flujo de valor sin sprints cerrados";
                                    return "Checklist directo sin ceremonias";
                                }
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: 9
                                color: ThemeBackend.subtext0
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        Text {
                            text: root.getMethodologyInfo().badgeText
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: 9
                            font.bold: true
                            color: root.getMethodologyInfo().badgeColor
                        }
                    }
                }

                // Inline Edit Mode
                ColumnLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    anchors.topMargin: 4
                    anchors.bottomMargin: 4
                    spacing: 4
                    visible: root.isEditingCycle

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 22
                            radius: 4
                            color: ThemeBackend.surface1
                            border.color: ThemeBackend.surface2
                            border.width: 1

                            TextInput {
                                id: cycleNameEditInput
                                anchors.fill: parent
                                anchors.leftMargin: 6
                                anchors.rightMargin: 6
                                verticalAlignment: TextInput.AlignVCenter
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: 10
                                color: ThemeBackend.text
                                text: root.cycleNameInput
                                activeFocusOnTab: true
                                focus: true
                                onTextChanged: root.cycleNameInput = text
                                clip: true
                                onVisibleChanged: {
                                    if (visible) focusInputTimer.restart();
                                }

                                Text {
                                    anchors.fill: parent
                                    verticalAlignment: Text.AlignVCenter
                                    text: "Nombre del ciclo (ej. Sprint 1)..."
                                    font.family: ThemeBackend.fontFamily
                                    font.pixelSize: 10
                                    color: ThemeBackend.subtext0
                                    visible: !cycleNameEditInput.text && !cycleNameEditInput.activeFocus
                                }
                                onAccepted: root.saveCycleEdit()
                            }
                        }

                        Rectangle {
                            width: 20
                            height: 20
                            radius: 4
                            color: cycleSaveMa.containsMouse ? ThemeBackend.green : root.alpha(ThemeBackend.green, 0.3)

                            Text {
                                anchors.centerIn: parent
                                text: "󰄬"
                                font.family: root.nerdFont
                                font.pixelSize: 11
                                color: ThemeBackend.crust
                            }

                            MouseArea {
                                id: cycleSaveMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.saveCycleEdit()
                            }
                        }

                        Rectangle {
                            width: 20
                            height: 20
                            radius: 4
                            color: cycleCancelMa.containsMouse ? root.alpha(ThemeBackend.red, 0.3) : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "󰅖"
                                font.family: root.nerdFont
                                font.pixelSize: 11
                                color: cycleCancelMa.containsMouse ? ThemeBackend.red : ThemeBackend.subtext0
                            }

                            MouseArea {
                                id: cycleCancelMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.cancelCycleEdit()
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 20
                        radius: 4
                        color: ThemeBackend.surface1
                        border.color: ThemeBackend.surface2
                        border.width: 1

                        TextInput {
                            id: cycleGoalEditInput
                            anchors.fill: parent
                            anchors.leftMargin: 6
                            anchors.rightMargin: 6
                            verticalAlignment: TextInput.AlignVCenter
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: 9
                            color: ThemeBackend.text
                            text: root.cycleGoalInput
                            activeFocusOnTab: true
                            onTextChanged: root.cycleGoalInput = text
                            clip: true

                            Text {
                                anchors.fill: parent
                                verticalAlignment: Text.AlignVCenter
                                text: "Meta u objetivo del ciclo..."
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: 9
                                color: ThemeBackend.subtext0
                                visible: !cycleGoalEditInput.text && !cycleGoalEditInput.activeFocus
                            }
                            onAccepted: root.saveCycleEdit()
                        }
                    }
                }
            }

            // 4. Selector de Etapas / Filtro (Chips)
            Rectangle {
                visible: !root.isFormOpen && (root.tasksList || []).length > 0
                Layout.fillWidth: true
                Layout.preferredHeight: 26
                radius: 8
                color: ThemeBackend.mantle

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 3
                    spacing: 3

                    Repeater {
                        model: {
                            if (root.methodology === "scrum") {
                                return [
                                    { id: "backlog", label: "BACKLOG (" + root.backlogTasks.length + ")" },
                                    { id: "sprint", label: "SPRINT (" + root.sprintTasks.length + ")" },
                                    { id: "in_progress", label: "EN CURSO (" + root.inProgressTasks.length + ")" },
                                    { id: "done", label: "HECHO (" + root.doneTasks.length + ")" }
                                ];
                            } else if (root.methodology === "kanban") {
                                return [
                                    { id: "todo", label: "POR HACER (" + root.todoTasks.length + ")" },
                                    { id: "in_progress", label: "EN CURSO (" + root.inProgressTasks.length + "/" + root.wipLimit + ")" },
                                    { id: "done", label: "HECHO (" + root.doneTasks.length + ")" }
                                ];
                            }
                            return [
                                { id: "pending", label: "PENDIENTES (" + root.todoTasks.length + ")" },
                                { id: "done", label: "COMPLETADAS (" + root.doneTasks.length + ")" }
                            ];
                        }

                        delegate: Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 6
                            color: root.activeFilterStage === modelData.id ? ThemeBackend.surface0 : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: modelData.label
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: 9
                                font.bold: true
                                color: {
                                    if (root.activeFilterStage === modelData.id) {
                                        if (modelData.id === "in_progress") return ThemeBackend.peach;
                                        if (modelData.id === "done") return ThemeBackend.green;
                                        return ThemeBackend.text;
                                    }
                                    if (modelData.id === "in_progress") return root.alpha(ThemeBackend.peach, 0.7);
                                    if (modelData.id === "done") return root.alpha(ThemeBackend.green, 0.7);
                                    return ThemeBackend.subtext0;
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.activeFilterStage = modelData.id
                            }
                        }
                    }
                }
            }

            // 5. Main Area: Form Card OR Empty State OR (Hero Card + Queue List for Scrum/Kanban) OR (Checklist for Simple)

            // VIEW A: Form Card (Add / Edit)
            Rectangle {
                visible: root.isFormOpen
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 8
                color: ThemeBackend.surface0
                border.color: ThemeBackend.surface1
                border.width: 1
                clip: true

                Flickable {
                    anchors.fill: parent
                    anchors.margins: 10
                    contentWidth: width
                    contentHeight: formContentCol.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds

                    ColumnLayout {
                        id: formContentCol
                        width: parent.width
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                text: root.editingTaskId !== "" ? "Editar ToDo" : "Nuevo ToDo"
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: 12
                                font.bold: true
                                color: ThemeBackend.text
                                Layout.fillWidth: true
                            }

                            Rectangle {
                                width: 20
                                height: 20
                                radius: 4
                                color: formCloseMa.containsMouse ? root.alpha(ThemeBackend.red, 0.2) : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰅖"
                                    font.family: root.nerdFont
                                    font.pixelSize: 12
                                    color: formCloseMa.containsMouse ? ThemeBackend.red : ThemeBackend.subtext0
                                }

                                MouseArea {
                                    id: formCloseMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.closeForm()
                                }
                            }
                        }

                        // Title Input
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 32
                            radius: 6
                            color: ThemeBackend.surface1
                            border.color: formTitleInput.activeFocus ? ThemeBackend.mauve : ThemeBackend.surface2
                            border.width: 1

                            TextInput {
                                id: formTitleInput
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                verticalAlignment: TextInput.AlignVCenter
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: 11
                                color: ThemeBackend.text
                                text: root.formTitle
                                activeFocusOnTab: true
                                focus: true
                                onTextChanged: root.formTitle = text
                                clip: true
                                onVisibleChanged: {
                                    if (visible) focusInputTimer.restart();
                                }

                                Text {
                                    anchors.fill: parent
                                    verticalAlignment: Text.AlignVCenter
                                    text: "Título del ToDo..."
                                    font.family: ThemeBackend.fontFamily
                                    font.pixelSize: 11
                                    color: ThemeBackend.subtext0
                                    visible: !formTitleInput.text && !formTitleInput.activeFocus
                                }

                                onAccepted: {
                                    if (formTitleInput.text.trim() !== "") {
                                        root.saveFormTask();
                                    }
                                }
                            }
                        }

                        // Description Input
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 52
                            radius: 6
                            color: ThemeBackend.surface1
                            border.color: formDescInput.activeFocus ? ThemeBackend.mauve : ThemeBackend.surface2
                            border.width: 1

                            Flickable {
                                anchors.fill: parent
                                anchors.margins: 6
                                contentWidth: width
                                contentHeight: formDescInput.implicitHeight
                                boundsBehavior: Flickable.StopAtBounds
                                clip: true

                                TextEdit {
                                    id: formDescInput
                                    width: parent.width
                                    wrapMode: TextEdit.Wrap
                                    font.family: ThemeBackend.fontFamily
                                    font.pixelSize: 10
                                    color: ThemeBackend.text
                                    text: root.formDescription
                                    activeFocusOnTab: true
                                    onTextChanged: root.formDescription = text
                                    selectByMouse: true

                                    Text {
                                        anchors.fill: parent
                                        text: "Descripción detallada (opcional)..."
                                        font.family: ThemeBackend.fontFamily
                                        font.pixelSize: 10
                                        color: ThemeBackend.subtext0
                                        visible: !formDescInput.text && !formDescInput.activeFocus
                                    }
                                }
                            }
                        }

                        // Story Points & Priority Row
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            ColumnLayout {
                                visible: root.methodology === "scrum"
                                spacing: 3

                                Text {
                                    text: "Puntos (Fibonacci):"
                                    font.family: ThemeBackend.fontFamily
                                    font.pixelSize: 9
                                    color: ThemeBackend.subtext0
                                }

                                RowLayout {
                                    spacing: 3

                                    Repeater {
                                        model: [1, 2, 3, 5, 8]

                                        delegate: Rectangle {
                                            Layout.preferredWidth: 24
                                            Layout.preferredHeight: 20
                                            radius: 4
                                            color: root.formPoints === modelData ? ThemeBackend.mauve : (ptsChipMa.containsMouse ? ThemeBackend.surface2 : ThemeBackend.surface1)

                                            Text {
                                                anchors.centerIn: parent
                                                text: String(modelData)
                                                font.family: ThemeBackend.fontFamily
                                                font.pixelSize: 9
                                                font.bold: true
                                                color: root.formPoints === modelData ? ThemeBackend.crust : ThemeBackend.text
                                            }

                                            MouseArea {
                                                id: ptsChipMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.formPoints = modelData
                                            }
                                        }
                                    }
                                }
                            }

                            Item { Layout.fillWidth: true; visible: root.methodology === "scrum" }

                            ColumnLayout {
                                Layout.fillWidth: root.methodology !== "scrum"
                                spacing: 3

                                Text {
                                    text: "Prioridad:"
                                    font.family: ThemeBackend.fontFamily
                                    font.pixelSize: 9
                                    color: ThemeBackend.subtext0
                                }

                                RowLayout {
                                    spacing: 3

                                    Repeater {
                                        model: [
                                            { id: "low", label: "Baja", color: ThemeBackend.subtext0 },
                                            { id: "medium", label: "Media", color: ThemeBackend.blue },
                                            { id: "high", label: "Alta", color: ThemeBackend.peach },
                                            { id: "urgent", label: "Urgente", color: ThemeBackend.red }
                                        ]

                                        delegate: Rectangle {
                                            Layout.preferredHeight: 20
                                            Layout.preferredWidth: prioText.implicitWidth + 8
                                            radius: 4
                                            color: root.formPriority === modelData.id ? root.alpha(modelData.color, 0.3) : (prioChipMa.containsMouse ? ThemeBackend.surface2 : ThemeBackend.surface1)
                                            border.color: root.formPriority === modelData.id ? modelData.color : "transparent"
                                            border.width: 1

                                            Text {
                                                id: prioText
                                                anchors.centerIn: parent
                                                text: modelData.label
                                                font.family: ThemeBackend.fontFamily
                                                font.pixelSize: 9
                                                font.bold: root.formPriority === modelData.id
                                                color: root.formPriority === modelData.id ? modelData.color : ThemeBackend.subtext0
                                            }

                                            MouseArea {
                                                id: prioChipMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.formPriority = modelData.id
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Stage Selector matching active methodology
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3

                            Text {
                                text: "Etapa / Estado:"
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: 9
                                color: ThemeBackend.subtext0
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 4

                                Repeater {
                                    model: {
                                        if (root.methodology === "scrum") {
                                            return [
                                                { id: "backlog", label: "Backlog" },
                                                { id: "sprint", label: "Sprint" },
                                                { id: "in_progress", label: "En Curso" },
                                                { id: "done", label: "Hecho" }
                                            ];
                                        } else if (root.methodology === "kanban") {
                                            return [
                                                { id: "todo", label: "Por Hacer" },
                                                { id: "in_progress", label: "En Curso" },
                                                { id: "done", label: "Hecho" }
                                            ];
                                        }
                                        return [
                                            { id: "todo", label: "Pendiente" },
                                            { id: "done", label: "Hecho" }
                                        ];
                                    }

                                    delegate: Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 22
                                        radius: 4
                                        color: root.formStatus === modelData.id ? root.alpha(ThemeBackend.mauve, 0.3) : (stageChipMa.containsMouse ? ThemeBackend.surface2 : ThemeBackend.surface1)
                                        border.color: root.formStatus === modelData.id ? ThemeBackend.mauve : "transparent"
                                        border.width: 1

                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.label
                                            font.family: ThemeBackend.fontFamily
                                            font.pixelSize: 9
                                            font.bold: root.formStatus === modelData.id
                                            color: root.formStatus === modelData.id ? ThemeBackend.text : ThemeBackend.subtext0
                                        }

                                        MouseArea {
                                            id: stageChipMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.formStatus = modelData.id
                                        }
                                    }
                                }
                            }
                        }

                        // Action Buttons: Cancelar & Guardar
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.topMargin: 4
                            spacing: 8

                            Item { Layout.fillWidth: true }

                            Rectangle {
                                Layout.preferredHeight: 24
                                Layout.preferredWidth: cancelBtnText.implicitWidth + 14
                                radius: 4
                                color: cancelBtnMa.containsMouse ? ThemeBackend.surface2 : ThemeBackend.surface1

                                RowLayout {
                                    id: cancelBtnText
                                    anchors.centerIn: parent
                                    spacing: 4

                                    Text {
                                        text: "󰅖"
                                        font.family: root.nerdFont
                                        font.pixelSize: 10
                                        color: ThemeBackend.subtext0
                                    }

                                    Text {
                                        text: "Cancelar"
                                        font.family: ThemeBackend.fontFamily
                                        font.pixelSize: 10
                                        color: ThemeBackend.subtext0
                                    }
                                }

                                MouseArea {
                                    id: cancelBtnMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.closeForm()
                                }
                            }

                            Rectangle {
                                readonly property bool canSave: (root.formTitle || "").trim() !== ""
                                Layout.preferredHeight: 24
                                Layout.preferredWidth: saveBtnText.implicitWidth + 14
                                radius: 4
                                color: canSave ? (saveBtnMa.containsMouse ? Qt.lighter(ThemeBackend.mauve, 1.1) : ThemeBackend.mauve) : ThemeBackend.surface2
                                opacity: canSave ? 1.0 : 0.5

                                RowLayout {
                                    id: saveBtnText
                                    anchors.centerIn: parent
                                    spacing: 4

                                    Text {
                                        text: "󰄬"
                                        font.family: root.nerdFont
                                        font.pixelSize: 10
                                        color: parent.parent.canSave ? ThemeBackend.crust : ThemeBackend.subtext0
                                    }

                                    Text {
                                        text: "Guardar"
                                        font.family: ThemeBackend.fontFamily
                                        font.pixelSize: 10
                                        font.bold: true
                                        color: parent.parent.canSave ? ThemeBackend.crust : ThemeBackend.subtext0
                                    }
                                }

                                MouseArea {
                                    id: saveBtnMa
                                    anchors.fill: parent
                                    hoverEnabled: parent.canSave
                                    cursorShape: parent.canSave ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: {
                                        if (parent.canSave) {
                                            root.saveFormTask();
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // VIEW B: Empty State (When tasksList is empty and form is closed)
            Item {
                visible: !root.isFormOpen && (root.tasksList || []).length === 0
                Layout.fillWidth: true
                Layout.fillHeight: true

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 8

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "󰄲"
                        font.family: root.nerdFont
                        font.pixelSize: 36
                        color: root.alpha(ThemeBackend.mauve, 0.7)
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "Sin tareas pendientes"
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: 13
                        font.bold: true
                        color: ThemeBackend.text
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "Presioná + para agregar tu primer ToDo"
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: 11
                        color: ThemeBackend.subtext0
                    }

                    Item { Layout.preferredHeight: 4 }

                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredHeight: 28
                        Layout.preferredWidth: addEmptyText.implicitWidth + 20
                        radius: 6
                        color: emptyAddMa.containsMouse ? Qt.lighter(ThemeBackend.mauve, 1.1) : ThemeBackend.mauve

                        RowLayout {
                            id: addEmptyText
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                text: "󰐕"
                                font.family: root.nerdFont
                                font.pixelSize: 12
                                color: ThemeBackend.crust
                            }

                            Text {
                                text: "Agregar ToDo"
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: 11
                                font.bold: true
                                color: ThemeBackend.crust
                            }
                        }

                        MouseArea {
                            id: emptyAddMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.openCreateForm()
                        }
                    }
                }
            }

            // VIEW C: Simple Mode Checklist (As in 03-simple-mode.html)
            ListView {
                id: simpleListView
                visible: !root.isFormOpen && (root.tasksList || []).length > 0 && root.methodology === "simple"
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 6
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: {
                    let base = root.activeFilterStage === "done" ? root.doneTasks : root.todoTasks;
                    return (base || []).filter(function(t) { return t && root.matchesSearch(t); });
                }

                delegate: Rectangle {
                    id: checkItemCard
                    readonly property bool isDone: Boolean(modelData && (modelData.status === "done" || modelData.status === "completed"))
                    readonly property bool hasDesc: Boolean(modelData && modelData.description && modelData.description.trim() !== "")
                    width: simpleListView.width
                    height: hasDesc ? 44 : 36
                    radius: 8
                    color: simpleItemMa.containsMouse ? ThemeBackend.surface1 : ThemeBackend.surface0
                    border.color: isDone ? root.alpha(ThemeBackend.surface1, 0.5) : (simpleItemMa.containsMouse ? ThemeBackend.surface2 : ThemeBackend.surface1)
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 10

                        // Square Checkbox (18x18, radius 4)
                        Rectangle {
                            width: 18
                            height: 18
                            radius: 4
                            color: checkItemCard.isDone ? ThemeBackend.green : "transparent"
                            border.color: checkItemCard.isDone ? ThemeBackend.green : (cbMa.containsMouse ? ThemeBackend.text : ThemeBackend.surface2)
                            border.width: 1.5

                            Text {
                                anchors.centerIn: parent
                                visible: checkItemCard.isDone
                                text: "✓"
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: 11
                                font.bold: true
                                color: ThemeBackend.crust
                            }

                            MouseArea {
                                id: cbMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (!modelData || modelData.id === undefined) return;
                                    if (checkItemCard.isDone) {
                                        root.reopenTask(modelData.id);
                                    } else {
                                        root.markTaskDone(modelData.id);
                                    }
                                }
                            }
                        }

                        // Task Title & Optional Description
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Text {
                                text: (modelData && modelData.title) ? modelData.title : ""
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: 11
                                font.strikeout: checkItemCard.isDone
                                font.bold: !checkItemCard.isDone
                                color: checkItemCard.isDone ? ThemeBackend.subtext0 : ThemeBackend.text
                                opacity: checkItemCard.isDone ? 0.75 : 1.0
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Text {
                                visible: checkItemCard.hasDesc
                                text: (modelData && modelData.description) ? modelData.description : ""
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: 9
                                color: ThemeBackend.subtext0
                                opacity: 0.8
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                Layout.fillWidth: true
                            }
                        }

                        // Edit Button (󰏫)
                        Rectangle {
                            width: 22
                            height: 22
                            radius: 4
                            color: simpleEditMa.containsMouse ? root.alpha(ThemeBackend.mauve, 0.25) : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "󰏫"
                                font.family: root.nerdFont
                                font.pixelSize: 11
                                color: simpleEditMa.containsMouse ? ThemeBackend.mauve : ThemeBackend.subtext0
                            }

                            MouseArea {
                                id: simpleEditMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (modelData) root.openEditForm(modelData);
                                }
                            }
                        }

                        // Delete Button (󰆴)
                        Rectangle {
                            width: 22
                            height: 22
                            radius: 4
                            color: simpleDelMa.containsMouse ? root.alpha(ThemeBackend.red, 0.25) : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "󰆴"
                                font.family: root.nerdFont
                                font.pixelSize: 11
                                color: simpleDelMa.containsMouse ? ThemeBackend.red : ThemeBackend.subtext0
                            }

                            MouseArea {
                                id: simpleDelMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (modelData && modelData.id !== undefined) {
                                        root.deleteTask(modelData.id);
                                    }
                                }
                            }
                        }
                    }

                    MouseArea {
                        id: simpleItemMa
                        anchors.fill: parent
                        hoverEnabled: true
                        z: -1
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (!modelData || modelData.id === undefined) return;
                            if (checkItemCard.isDone) {
                                root.reopenTask(modelData.id);
                            } else {
                                root.markTaskDone(modelData.id);
                            }
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: simpleListView.count === 0
                    text: root.activeFilterStage === "done" ? "Sin tareas completadas" : "Sin tareas pendientes"
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: 11
                    color: ThemeBackend.subtext0
                }
            }

            // VIEW D: Hero Card + Queue List (For Scrum & Kanban when tasksList has items and form is closed)
            ColumnLayout {
                visible: !root.isFormOpen && (root.tasksList || []).length > 0 && root.methodology !== "simple"
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 6

                // Hero Card
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: heroCol.implicitHeight + 16
                    radius: 8
                    color: root.activeHeroTask ? root.alpha(ThemeBackend.peach, 0.15) : ThemeBackend.surface0
                    border.color: root.activeHeroTask ? root.alpha(ThemeBackend.peach, 0.5) : ThemeBackend.surface1
                    border.width: 1

                    ColumnLayout {
                        id: heroCol
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            visible: root.activeHeroTask !== null

                            Text {
                                text: {
                                    if (root.methodology === "kanban") return "● EN CURSO (" + root.inProgressTasks.length + "/" + root.wipLimit + ")";
                                    return "● EN PROGRESO";
                                }
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: 9
                                font.bold: true
                                color: ThemeBackend.peach
                            }

                            Rectangle {
                                readonly property var originInfo: root.getTaskOriginInfo(root.activeHeroTask)
                                height: 16
                                width: heroOriginText.implicitWidth + 10
                                radius: 4
                                color: root.alpha(originInfo.color, 0.2)
                                border.color: root.alpha(originInfo.color, 0.35)
                                border.width: 1

                                Text {
                                    id: heroOriginText
                                    anchors.centerIn: parent
                                    text: parent.originInfo.tag
                                    font.family: ThemeBackend.fontFamily
                                    font.pixelSize: 8
                                    font.bold: true
                                    color: parent.originInfo.color
                                }
                            }

                            Item { Layout.fillWidth: true }

                            Rectangle {
                                visible: root.activeHeroTask !== null && Number(root.activeHeroTask.points) > 0
                                height: 16
                                width: heroPtsText.implicitWidth + 8
                                radius: 4
                                color: root.alpha(ThemeBackend.mauve, 0.2)
                                border.color: root.alpha(ThemeBackend.mauve, 0.35)
                                border.width: 1

                                Text {
                                    id: heroPtsText
                                    anchors.centerIn: parent
                                    text: (root.activeHeroTask ? root.activeHeroTask.points : 0) + " pts"
                                    font.family: ThemeBackend.fontFamily
                                    font.pixelSize: 9
                                    font.bold: true
                                    color: ThemeBackend.mauve
                                }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: {
                                if (root.activeHeroTask) return root.activeHeroTask.title;
                                if (root.activeFilterStage === "backlog") return "Sin tareas en el Backlog";
                                if (root.activeFilterStage === "sprint") return "Sin tareas en el Sprint";
                                if (root.activeFilterStage === "in_progress") return "Sin tareas en curso";
                                if (root.activeFilterStage === "done") return "Sin tareas completadas";
                                if (root.activeFilterStage === "todo") return "Sin tareas por hacer";
                                return "Sin tareas en esta etapa";
                            }
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: 12
                            font.bold: true
                            color: root.activeHeroTask ? "#ffffff" : ThemeBackend.subtext0
                            elide: Text.ElideRight
                        }

                        Text {
                            visible: root.activeHeroTask !== null && Boolean(root.activeHeroTask.description && root.activeHeroTask.description.trim() !== "")
                            Layout.fillWidth: true
                            text: (root.activeHeroTask && root.activeHeroTask.description) ? root.activeHeroTask.description : ""
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: 10
                            color: ThemeBackend.subtext1
                            elide: Text.ElideRight
                            maximumLineCount: 2
                            wrapMode: Text.Wrap
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            visible: root.activeHeroTask !== null
                            spacing: 6

                            Text {
                                text: {
                                    if (!root.activeHeroTask) return "";
                                    let prio = root.getPriorityLabel(root.activeHeroTask.priority);
                                    return "Prioridad: " + prio;
                                }
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: 9
                                color: ThemeBackend.subtext0
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }

                            // Edit Hero Task
                            Rectangle {
                                width: 22
                                height: 22
                                radius: 4
                                color: heroEditMa.containsMouse ? root.alpha(ThemeBackend.mauve, 0.25) : ThemeBackend.surface1

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰏫"
                                    font.family: root.nerdFont
                                    font.pixelSize: 11
                                    color: heroEditMa.containsMouse ? ThemeBackend.mauve : ThemeBackend.subtext0
                                }

                                MouseArea {
                                    id: heroEditMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (root.activeHeroTask) {
                                            root.openEditForm(root.activeHeroTask);
                                        }
                                    }
                                }
                            }

                            // Delete Hero Task
                            Rectangle {
                                width: 22
                                height: 22
                                radius: 4
                                color: heroDelMa.containsMouse ? root.alpha(ThemeBackend.red, 0.25) : ThemeBackend.surface1

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰆴"
                                    font.family: root.nerdFont
                                    font.pixelSize: 11
                                    color: heroDelMa.containsMouse ? ThemeBackend.red : ThemeBackend.subtext0
                                }

                                MouseArea {
                                    id: heroDelMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (root.activeHeroTask && root.activeHeroTask.id !== undefined) {
                                            root.deleteTask(root.activeHeroTask.id);
                                        }
                                    }
                                }
                            }

                            // Prev Stage Button
                            Rectangle {
                                visible: root.activeHeroTask !== null && root.getPrevStatus(root.activeHeroTask.status) !== root.activeHeroTask.status
                                width: 22
                                height: 22
                                radius: 4
                                color: heroPrevMa.containsMouse ? ThemeBackend.surface2 : ThemeBackend.surface1

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰁍"
                                    font.family: root.nerdFont
                                    font.pixelSize: 11
                                    color: heroPrevMa.containsMouse ? ThemeBackend.text : ThemeBackend.subtext0
                                }

                                MouseArea {
                                    id: heroPrevMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (root.activeHeroTask && root.activeHeroTask.id !== undefined) {
                                            root.updateTaskStatus(root.activeHeroTask.id, root.getPrevStatus(root.activeHeroTask.status));
                                        }
                                    }
                                }
                            }

                            // Next Stage Button
                            Rectangle {
                                visible: root.activeHeroTask !== null && root.getNextStatus(root.activeHeroTask.status) !== root.activeHeroTask.status
                                width: 22
                                height: 22
                                radius: 4
                                color: heroNextMa.containsMouse ? root.alpha(ThemeBackend.peach, 0.3) : ThemeBackend.surface1

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰁔"
                                    font.family: root.nerdFont
                                    font.pixelSize: 11
                                    color: heroNextMa.containsMouse ? ThemeBackend.peach : ThemeBackend.subtext0
                                }

                                MouseArea {
                                    id: heroNextMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (root.activeHeroTask && root.activeHeroTask.id !== undefined) {
                                            root.updateTaskStatus(root.activeHeroTask.id, root.getNextStatus(root.activeHeroTask.status));
                                        }
                                    }
                                }
                            }

                            // Status Action Button
                            Rectangle {
                                readonly property bool isHeroDone: root.activeHeroTask && (root.activeHeroTask.status === "done" || root.activeHeroTask.status === "completed")
                                readonly property bool isHeroProg: root.activeHeroTask && root.activeHeroTask.status === "in_progress"
                                readonly property bool isHeroBacklog: root.activeHeroTask && root.activeHeroTask.status === "backlog" && root.methodology === "scrum"
                                height: 22
                                width: heroDoneBtnRow.implicitWidth + 12
                                radius: 4
                                color: {
                                    if (isHeroDone) return heroDoneMa.containsMouse ? root.alpha(ThemeBackend.mauve, 0.25) : root.alpha(ThemeBackend.green, 0.2);
                                    if (isHeroProg) return heroDoneMa.containsMouse ? Qt.lighter(ThemeBackend.green, 1.15) : ThemeBackend.green;
                                    if (isHeroBacklog) return heroDoneMa.containsMouse ? root.alpha(ThemeBackend.mauve, 0.35) : root.alpha(ThemeBackend.mauve, 0.2);
                                    return heroDoneMa.containsMouse ? root.alpha(ThemeBackend.peach, 0.3) : ThemeBackend.surface1;
                                }
                                border.color: isHeroBacklog ? root.alpha(ThemeBackend.mauve, 0.5) : (isHeroDone ? root.alpha(ThemeBackend.green, 0.3) : "transparent")
                                border.width: (isHeroBacklog || isHeroDone) ? 1 : 0

                                RowLayout {
                                    id: heroDoneBtnRow
                                    anchors.centerIn: parent
                                    spacing: 3

                                    Text {
                                        text: {
                                            if (parent.parent.isHeroDone) return "↺ Reabrir";
                                            if (parent.parent.isHeroProg) return "✓ Hecho";
                                            if (parent.parent.isHeroBacklog) return "▶ Al Sprint";
                                            return "▶ Iniciar";
                                        }
                                        font.family: ThemeBackend.fontFamily
                                        font.pixelSize: 10
                                        font.bold: true
                                        color: {
                                            if (parent.parent.isHeroDone) return ThemeBackend.green;
                                            if (parent.parent.isHeroProg) return ThemeBackend.crust;
                                            if (parent.parent.isHeroBacklog) return ThemeBackend.mauve;
                                            return ThemeBackend.text;
                                        }
                                    }
                                }

                                MouseArea {
                                    id: heroDoneMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (!root.activeHeroTask || root.activeHeroTask.id === undefined) return;
                                        if (parent.isHeroDone) {
                                            root.reopenTask(root.activeHeroTask.id);
                                        } else if (parent.isHeroProg) {
                                            root.markTaskDone(root.activeHeroTask.id);
                                        } else {
                                            root.advanceTask(root.activeHeroTask);
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Queue Section Header
                Text {
                    text: {
                        let count = root.filteredQueueTasks.length;
                        if (root.methodology === "scrum") {
                            if (root.activeFilterStage === "backlog") return "BACKLOG (" + count + ")";
                            if (root.activeFilterStage === "sprint") return "SPRINT BACKLOG (" + count + ")";
                            if (root.activeFilterStage === "in_progress") return "EN CURSO (" + count + ")";
                            if (root.activeFilterStage === "done") return "HECHAS (" + count + ")";
                            return "SIGUIENTES EN LA COLA (" + count + ")";
                        }
                        if (root.methodology === "kanban") {
                            if (root.activeFilterStage === "todo") return "COLA POR HACER (" + count + ")";
                            if (root.activeFilterStage === "in_progress") return "EN CURSO (" + count + ")";
                            if (root.activeFilterStage === "done") return "HECHAS (" + count + ")";
                            return "COLA KANBAN (" + count + ")";
                        }
                        return "SIGUIENTES EN LA COLA (" + count + ")";
                    }
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: 10
                    font.bold: true
                    color: ThemeBackend.subtext0
                }

                // Queue ListView
                ListView {
                    id: queueListView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 5
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    model: root.filteredQueueTasks

                    delegate: Rectangle {
                        id: queueItemCard
                        readonly property var originInfo: root.getTaskOriginInfo(modelData)
                        readonly property bool hasDesc: Boolean(modelData && modelData.description && modelData.description.trim() !== "")
                        width: queueListView.width
                        height: hasDesc ? 40 : 28
                        radius: 6
                        color: itemHoverMa.containsMouse ? ThemeBackend.surface1 : ThemeBackend.surface0
                        border.color: itemHoverMa.containsMouse ? ThemeBackend.surface2 : ThemeBackend.surface1
                        border.width: 1

                        MouseArea {
                            id: itemHoverMa
                            anchors.fill: parent
                            hoverEnabled: true
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 6

                            // Origin Badge
                            Rectangle {
                                height: 16
                                width: itemOriginText.implicitWidth + 8
                                radius: 4
                                color: root.alpha(originInfo.color, 0.2)
                                border.color: root.alpha(originInfo.color, 0.35)
                                border.width: 1

                                Text {
                                    id: itemOriginText
                                    anchors.centerIn: parent
                                    text: originInfo.shortTag
                                    font.family: ThemeBackend.fontFamily
                                    font.pixelSize: 8
                                    font.bold: true
                                    color: originInfo.color
                                }
                            }

                            // Task Title & Optional Description
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1

                                Text {
                                    text: modelData.title || ""
                                    font.family: ThemeBackend.fontFamily
                                    font.pixelSize: 10
                                    color: ThemeBackend.text
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                Text {
                                    visible: queueItemCard.hasDesc
                                    text: (modelData && modelData.description) ? modelData.description : ""
                                    font.family: ThemeBackend.fontFamily
                                    font.pixelSize: 9
                                    color: ThemeBackend.subtext1
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                    Layout.fillWidth: true
                                }
                            }

                            // Points (if Scrum / points > 0)
                            Text {
                                visible: Number(modelData.points) > 0
                                text: (modelData.points || 0) + "p"
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: 9
                                font.bold: true
                                color: ThemeBackend.mauve
                            }

                            // Prev Button
                            Rectangle {
                                visible: root.getPrevStatus(modelData.status) !== modelData.status
                                width: 20
                                height: 20
                                radius: 4
                                color: itemPrevMa.containsMouse ? ThemeBackend.surface2 : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰁍"
                                    font.family: root.nerdFont
                                    font.pixelSize: 11
                                    color: itemPrevMa.containsMouse ? ThemeBackend.text : ThemeBackend.subtext0
                                }

                                MouseArea {
                                    id: itemPrevMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (modelData && modelData.id !== undefined) {
                                            root.updateTaskStatus(modelData.id, root.getPrevStatus(modelData.status));
                                        }
                                    }
                                }
                            }

                            // Next Button
                            Rectangle {
                                visible: root.getNextStatus(modelData.status) !== modelData.status
                                width: 20
                                height: 20
                                radius: 4
                                color: itemNextMa.containsMouse ? root.alpha(ThemeBackend.peach, 0.25) : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰁔"
                                    font.family: root.nerdFont
                                    font.pixelSize: 11
                                    color: itemNextMa.containsMouse ? ThemeBackend.peach : ThemeBackend.subtext0
                                }

                                MouseArea {
                                    id: itemNextMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (modelData && modelData.id !== undefined) {
                                            root.updateTaskStatus(modelData.id, root.getNextStatus(modelData.status));
                                        }
                                    }
                                }
                            }

                            // Edit Button
                            Rectangle {
                                width: 20
                                height: 20
                                radius: 4
                                color: itemEditMa.containsMouse ? root.alpha(ThemeBackend.mauve, 0.2) : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰏫"
                                    font.family: root.nerdFont
                                    font.pixelSize: 11
                                    color: itemEditMa.containsMouse ? ThemeBackend.mauve : ThemeBackend.subtext0
                                }

                                MouseArea {
                                    id: itemEditMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.openEditForm(modelData)
                                }
                            }

                            // Delete Button
                            Rectangle {
                                width: 20
                                height: 20
                                radius: 4
                                color: itemDelMa.containsMouse ? root.alpha(ThemeBackend.red, 0.25) : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰆴"
                                    font.family: root.nerdFont
                                    font.pixelSize: 11
                                    color: itemDelMa.containsMouse ? ThemeBackend.red : ThemeBackend.subtext0
                                }

                                MouseArea {
                                    id: itemDelMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (modelData && modelData.id !== undefined) {
                                            root.deleteTask(modelData.id);
                                        }
                                    }
                                }
                            }

                            // 1-Click Action Button (Start / Mark Done / Reopen)
                            Rectangle {
                                readonly property bool isDone: modelData.status === "done" || modelData.status === "completed"
                                readonly property bool isInProgress: modelData.status === "in_progress"
                                readonly property bool isBacklog: modelData.status === "backlog" && root.methodology === "scrum"
                                height: 20
                                width: actionBtnRow.implicitWidth + 10
                                radius: 4
                                color: {
                                    if (isDone) return itemActionMa.containsMouse ? root.alpha(ThemeBackend.mauve, 0.2) : root.alpha(ThemeBackend.green, 0.15);
                                    if (isInProgress) return itemActionMa.containsMouse ? Qt.lighter(ThemeBackend.green, 1.15) : ThemeBackend.green;
                                    if (isBacklog) return itemActionMa.containsMouse ? root.alpha(ThemeBackend.mauve, 0.3) : root.alpha(ThemeBackend.mauve, 0.15);
                                    return itemActionMa.containsMouse ? root.alpha(ThemeBackend.peach, 0.25) : ThemeBackend.surface1;
                                }
                                border.color: isDone ? root.alpha(ThemeBackend.green, 0.3) : (isBacklog ? root.alpha(ThemeBackend.mauve, 0.4) : "transparent")
                                border.width: (isDone || isBacklog) ? 1 : 0

                                RowLayout {
                                    id: actionBtnRow
                                    anchors.centerIn: parent
                                    spacing: 3

                                    Text {
                                        text: {
                                            if (parent.parent.isDone) return "↺ Reabrir";
                                            if (parent.parent.isInProgress) return "✓ Hecho";
                                            if (parent.parent.isBacklog) return "▶ Al Sprint";
                                            return "▶ Iniciar";
                                        }
                                        font.family: ThemeBackend.fontFamily
                                        font.pixelSize: 9
                                        font.bold: true
                                        color: {
                                            if (parent.parent.isDone) return itemActionMa.containsMouse ? ThemeBackend.mauve : ThemeBackend.green;
                                            if (parent.parent.isInProgress) return ThemeBackend.crust;
                                            if (parent.parent.isBacklog) return ThemeBackend.mauve;
                                            return itemActionMa.containsMouse ? ThemeBackend.peach : ThemeBackend.subtext0;
                                        }
                                    }
                                }

                                MouseArea {
                                    id: itemActionMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (!modelData || modelData.id === undefined) return;
                                        if (parent.isDone) {
                                            root.reopenTask(modelData.id);
                                        } else if (parent.isInProgress) {
                                            root.markTaskDone(modelData.id);
                                        } else {
                                            root.advanceTask(modelData);
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: queueListView.count === 0 && root.activeHeroTask !== null
                        text: "No hay más tareas en esta etapa"
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: 10
                        color: ThemeBackend.subtext0
                    }
                }
            }
        }
    }
}
