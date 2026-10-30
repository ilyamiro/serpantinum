import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../../reusables"
import "../../"

Item {
    id: root

    property int requestedLayoutTemplate: 1
    property bool isActiveTab: typeof isCurrentTarget !== "undefined" ? isCurrentTarget : true
    property string nerdFont: ThemeBackend.iconFont
    property string safeActiveEdge: typeof activeEdge !== "undefined" ? activeEdge : "left"

    property bool stateLoaded: false

    function s(val) {
        return typeof scaleFunc === "function" ? scaleFunc(val) : val;
    }

    property real baseW: s(520)
    property real baseL: s(480)

    property real preferredWidth: (root.safeActiveEdge === "bottom" || root.safeActiveEdge === "top") ? baseL + 50 : baseW
    property real preferredExtraLength: (root.safeActiveEdge === "bottom" || root.safeActiveEdge === "top") ? baseW : baseL

    property real counterRotation: {
        if (root.safeActiveEdge === "right") return 180;
        if (root.safeActiveEdge === "bottom") return 90;
        if (root.safeActiveEdge === "top") return -90;
        return 0;
    }

    function alpha(color, a) { return Qt.rgba(color.r, color.g, color.b, a); }

    function getStorageDir() {
        return (typeof Caching !== "undefined" && Caching.stateDir ? Caching.stateDir : ((Quickshell.env("HOME") || "") + "/.local/state/serpantinum")) + "/quickactions";
    }

    // State data
    property string methodology: "simple" // "scrum" | "kanban" | "simple"
    property string cycleName: ""
    property string cycleGoal: ""
    property int wipLimit: 2
    property var tasksList: []
    property string activeFilter: "all"
    property bool isCreatingTask: false

    readonly property bool hasInputFocus: taskTitleInput.activeFocus

    function unfocusInputs() {
        if (taskTitleInput.activeFocus) {
            taskTitleInput.focus = false;
        }
    }

    function getMethodologyInfo() {
        if (root.methodology === "kanban") {
            return { name: "Kanban", icon: "󰕰", tag: "KANBAN" };
        } else if (root.methodology === "simple") {
            return { name: "Simple", icon: "󰄲", tag: "SIMPLE" };
        }
        return { name: "Scrum", icon: "󰮯", tag: "SCRUM" };
    }

    function cycleMethodology() {
        if (root.methodology === "scrum") {
            root.methodology = "kanban";
        } else if (root.methodology === "kanban") {
            root.methodology = "simple";
        } else {
            root.methodology = "scrum";
        }
        root.activeFilter = "all";
        if (typeof Sounds !== "undefined" && typeof Sounds.playSfx === "function") {
            Sounds.playSfx("reusables/toggle/sfx.wav", 0.6);
        }
        root.saveTasksState();
    }

    // Normalizing status mapping across methodologies
    function getTaskEffectiveStatus(t) {
        if (!t) return "todo";
        let st = t.status || "todo";
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

    // Computed collections
    readonly property var backlogTasks: tasksList.filter(t => t && getTaskEffectiveStatus(t) === "backlog")
    readonly property var sprintBacklogTasks: tasksList.filter(t => t && getTaskEffectiveStatus(t) === "sprint")
    readonly property var todoTasks: tasksList.filter(t => t && getTaskEffectiveStatus(t) === "todo")
    readonly property var inProgressTasks: tasksList.filter(t => t && getTaskEffectiveStatus(t) === "in_progress")
    readonly property var doneTasks: tasksList.filter(t => t && getTaskEffectiveStatus(t) === "done")

    readonly property var activeScopeTasks: {
        if (root.methodology === "scrum") {
            return tasksList.filter(t => {
                let s = getTaskEffectiveStatus(t);
                return s === "sprint" || s === "in_progress" || s === "done";
            });
        }
        return tasksList;
    }

    readonly property int totalScopePoints: {
        let pts = 0;
        for (let i = 0; i < activeScopeTasks.length; i++) {
            pts += (Number(activeScopeTasks[i].points) || 0);
        }
        return pts;
    }

    readonly property int completedScopePoints: {
        let pts = 0;
        for (let i = 0; i < doneTasks.length; i++) {
            pts += (Number(doneTasks[i].points) || 0);
        }
        return pts;
    }

    readonly property real progressRatio: {
        if (totalScopePoints > 0) {
            return Math.min(1.0, completedScopePoints / totalScopePoints);
        }
        if (activeScopeTasks.length > 0) {
            return Math.min(1.0, doneTasks.length / activeScopeTasks.length);
        }
        return 0.0;
    }

    readonly property int progressPercent: Math.round(progressRatio * 100)
    readonly property bool isWipExceeded: (root.methodology === "scrum" || root.methodology === "kanban") && (inProgressTasks.length > wipLimit)

    // Filter configurations per methodology
    readonly property var scrumFilters: [
        { key: "all", label: "Tablero", icon: "󰮯", count: tasksList.length },
        { key: "backlog", label: "Backlog", icon: "󰠦", count: backlogTasks.length },
        { key: "sprint", label: "Sprint", icon: "󰔛", count: sprintBacklogTasks.length },
        { key: "in_progress", label: "En Curso", icon: "󰑮", count: inProgressTasks.length },
        { key: "done", label: "Hecho", icon: "󰄲", count: doneTasks.length }
    ]

    readonly property var kanbanFilters: [
        { key: "all", label: "Tablero", icon: "󰮯", count: tasksList.length },
        { key: "todo", label: "Por Hacer", icon: "󰔛", count: todoTasks.length },
        { key: "in_progress", label: "En Curso", icon: "󰑮", count: inProgressTasks.length },
        { key: "done", label: "Hecho", icon: "󰄲", count: doneTasks.length }
    ]

    readonly property var simpleFilters: [
        { key: "all", label: "Todas", icon: "󰮯", count: tasksList.length },
        { key: "todo", label: "Pendientes", icon: "󰔛", count: todoTasks.length },
        { key: "done", label: "Completadas", icon: "󰄲", count: doneTasks.length }
    ]

    readonly property var currentFilters: {
        if (root.methodology === "kanban") return root.kanbanFilters;
        if (root.methodology === "simple") return root.simpleFilters;
        return root.scrumFilters;
    }

    readonly property var filteredTasksList: {
        if (activeFilter === "all") return tasksList;
        return tasksList.filter(t => t && getTaskEffectiveStatus(t) === activeFilter);
    }

    // Process storage: JSON read/write with backward compatibility
    Process {
        id: saveTasksProc
    }

    Process {
        id: loadTasksProc
        command: ["bash", "-c", "DIR='" + root.getStorageDir() + "'; if [ -f \"$DIR/tasks.json\" ]; then cat \"$DIR/tasks.json\"; elif [ -f \"$DIR/scrum.json\" ]; then cat \"$DIR/scrum.json\"; else echo '{}'; fi"]
        stdout: StdioCollector {
            id: loadTasksOut
            onStreamFinished: {
                root.restoreTasksState(loadTasksOut.text);
            }
        }
    }

    Component.onCompleted: {
        loadTasksProc.running = true;
    }

    function restoreTasksState(rawText) {
        let txt = (rawText || "").trim();
        if (txt !== "" && txt !== "{}") {
            try {
                let data = JSON.parse(txt);
                if (data.methodology) root.methodology = data.methodology;
                if (data.cycleName) root.cycleName = data.cycleName;
                else if (data.sprint && data.sprint.name) root.cycleName = data.sprint.name;

                if (data.cycleGoal) root.cycleGoal = data.cycleGoal;
                else if (data.sprint && data.sprint.goal) root.cycleGoal = data.sprint.goal;

                if (data.wipLimit !== undefined) root.wipLimit = Number(data.wipLimit) || 2;
                if (Array.isArray(data.tasks)) {
                    root.tasksList = data.tasks;
                }
            } catch (e) {
                console.warn("[Tasks.qml] Error parsing tasks data:", e);
            }
        } else {
            root.methodology = "simple";
            root.cycleName = "";
            root.cycleGoal = "";
            root.tasksList = [];
            root.saveTasksState();
        }
        root.stateLoaded = true;
    }

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

    function saveTasksState() {
        if (!root.stateLoaded) return;
        let dir = root.getStorageDir();
        let payload = {
            methodology: root.methodology,
            cycleName: root.cycleName || "",
            cycleGoal: root.cycleGoal || "",
            sprint: {
                name: root.cycleName || "",
                goal: root.cycleGoal || ""
            },
            wipLimit: root.wipLimit,
            tasks: root.tasksList
        };
        let jsonStr = JSON.stringify(payload, null, 2);
        let b64 = toBase64(jsonStr);
        saveTasksProc.running = false;
        saveTasksProc.command = ["bash", "-c", "mkdir -p '" + dir + "' && printf '%s' '" + b64 + "' | base64 -d > '" + dir + "/tasks.json.tmp' && mv -f '" + dir + "/tasks.json.tmp' '" + dir + "/tasks.json'"];
        saveTasksProc.running = true;
    }

    function addTask(title, points, priority, status) {
        let trimmed = (title || "").trim();
        if (trimmed === "") return;
        let targetStatus = status;
        if (!targetStatus) {
            if (root.methodology === "scrum") {
                targetStatus = root.activeFilter === "backlog" ? "backlog" : "sprint";
            } else {
                targetStatus = "todo";
            }
        }
        let newTask = {
            id: "task_" + Date.now() + "_" + Math.floor(Math.random() * 1000),
            title: trimmed,
            points: Number(points) || 0,
            priority: priority || "medium",
            status: targetStatus,
            createdAt: Date.now()
        };
        let updated = [newTask].concat(root.tasksList);
        root.tasksList = updated;
        if (typeof Sounds !== "undefined" && typeof Sounds.playSfx === "function") {
            Sounds.playSfx("reusables/clickbutton/click2.wav", 0.9);
        }
        root.saveTasksState();
    }

    function updateTaskStatus(taskId, nextStatus) {
        let isDoneTransition = false;
        let isRevertTransition = false;
        let updated = [];
        for (let i = 0; i < root.tasksList.length; i++) {
            let t = Object.assign({}, root.tasksList[i]);
            if (t.id === taskId) {
                if (nextStatus === "done" && t.status !== "done") isDoneTransition = true;
                if (t.status === "done" && nextStatus !== "done") isRevertTransition = true;
                t.status = nextStatus;
                if (nextStatus === "done") t.completedAt = Date.now();
                else delete t.completedAt;
            }
            updated.push(t);
        }
        root.tasksList = updated;
        if (typeof Sounds !== "undefined" && typeof Sounds.playSfx === "function") {
            if (isDoneTransition) {
                Sounds.playSfx("notifications/Progress.wav", 0.8);
            } else if (isRevertTransition) {
                Sounds.playSfx("reusables/switch/sfx.wav", 0.7);
            } else {
                Sounds.playSfx("reusables/draggable/tick.wav", 0.7);
            }
        }
        root.saveTasksState();
    }

    function deleteTask(taskId) {
        root.tasksList = root.tasksList.filter(t => t && t.id !== taskId);
        if (typeof Sounds !== "undefined" && typeof Sounds.playSfx === "function") {
            Sounds.playSfx("guide/barconfig/out.wav", 0.8);
        }
        root.saveTasksState();
    }

    function getNextStatus(curr) {
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

    function getPrevStatus(curr) {
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

    function getStatusLabel(st) {
        if (st === "backlog") return "Backlog";
        if (st === "sprint") return "Sprint";
        if (st === "todo") return "Por Hacer";
        if (st === "in_progress") return "En curso";
        if (st === "done") return "Hecho";
        return st;
    }

    function getStatusColor(st) {
        if (st === "backlog") return ThemeBackend.subtext0;
        if (st === "sprint") return ThemeBackend.blue;
        if (st === "todo") return ThemeBackend.blue;
        if (st === "in_progress") return ThemeBackend.peach;
        if (st === "done") return ThemeBackend.green;
        return ThemeBackend.surface2;
    }

    function getPriorityColor(pr) {
        if (pr === "urgent") return ThemeBackend.red;
        if (pr === "high") return ThemeBackend.peach;
        if (pr === "medium") return ThemeBackend.blue;
        return ThemeBackend.subtext0;
    }

    // UI Content Layout
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.s(12)
        spacing: root.s(10)

        // Header: Methodology Selector, Cycle/List Title, Goal, Progress Bar, WIP limit
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: headerCol.implicitHeight + root.s(20)
            color: ThemeBackend.surface0
            radius: ThemeBackend.borderRadius
            border.color: root.alpha(ThemeBackend.surface1, 0.8)
            border.width: 1

            ColumnLayout {
                id: headerCol
                anchors.fill: parent
                anchors.margins: root.s(10)
                spacing: root.s(8)

                RowLayout {
                    Layout.fillWidth: true
                    spacing: root.s(8)

                    // Interactive Methodology Selector Tag
                    Rectangle {
                        Layout.preferredHeight: root.s(24)
                        Layout.preferredWidth: methTagRow.implicitWidth + root.s(14)
                        radius: root.s(12)
                        color: methMa.containsMouse ? root.alpha(ThemeBackend.mauve, 0.3) : root.alpha(ThemeBackend.mauve, 0.15)
                        border.color: root.alpha(ThemeBackend.mauve, 0.5)
                        border.width: 1

                        RowLayout {
                            id: methTagRow
                            anchors.centerIn: parent
                            spacing: root.s(4)

                            Text {
                                text: root.getMethodologyInfo().icon
                                font.family: root.nerdFont
                                font.pixelSize: root.s(12)
                                color: ThemeBackend.mauve
                            }

                            Text {
                                text: root.getMethodologyInfo().name
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: root.s(11)
                                font.bold: true
                                color: ThemeBackend.mauve
                            }
                        }

                        MouseArea {
                            id: methMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.cycleMethodology()
                        }
                    }

                    Text {
                        text: root.cycleName
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: root.s(14)
                        font.bold: true
                        color: ThemeBackend.text
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    // Progress / Points Pill
                    Rectangle {
                        Layout.preferredHeight: root.s(20)
                        Layout.preferredWidth: ptsText.implicitWidth + root.s(12)
                        radius: root.s(10)
                        color: root.alpha(ThemeBackend.mauve, 0.2)

                        Text {
                            id: ptsText
                            anchors.centerIn: parent
                            text: root.totalScopePoints > 0 ? (root.completedScopePoints + "/" + root.totalScopePoints + " pts") : (root.doneTasks.length + "/" + root.activeScopeTasks.length + " tareas")
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: root.s(10)
                            font.bold: true
                            color: ThemeBackend.mauve
                        }
                    }

                    // WIP Warning Pill (only for Scrum and Kanban)
                    Rectangle {
                        visible: root.methodology === "scrum" || root.methodology === "kanban"
                        Layout.preferredHeight: root.s(20)
                        Layout.preferredWidth: wipText.implicitWidth + root.s(12)
                        radius: root.s(10)
                        color: root.isWipExceeded ? root.alpha(ThemeBackend.red, 0.25) : root.alpha(ThemeBackend.peach, 0.15)
                        border.color: root.isWipExceeded ? ThemeBackend.red : "transparent"
                        border.width: root.isWipExceeded ? 1 : 0

                        Text {
                            id: wipText
                            anchors.centerIn: parent
                            text: (root.isWipExceeded ? "󰓎 WIP Excedido: " : "WIP: ") + root.inProgressTasks.length + "/" + root.wipLimit
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: root.s(10)
                            font.bold: true
                            color: root.isWipExceeded ? ThemeBackend.red : ThemeBackend.peach
                        }
                    }

                    // Progress %
                    Text {
                        text: root.progressPercent + "%"
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: root.s(13)
                        font.bold: true
                        color: root.progressPercent >= 100 ? ThemeBackend.green : ThemeBackend.blue
                    }
                }

                // Cycle Goal subtitle
                Text {
                    text: root.cycleGoal
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: root.s(11)
                    color: ThemeBackend.subtext0
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                // Visual Progress Bar
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.s(6)
                    radius: root.s(3)
                    color: ThemeBackend.surface1
                    clip: true

                    Rectangle {
                        height: parent.height
                        width: parent.width * root.progressRatio
                        radius: root.s(3)
                        color: root.progressRatio >= 1.0 ? ThemeBackend.green : ThemeBackend.mauve

                        Behavior on width {
                            NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
                        }
                    }
                }
            }
        }

        // Navigation Tabs / Column Filter
        RowLayout {
            Layout.fillWidth: true
            spacing: root.s(4)

            Repeater {
                model: root.currentFilters

                delegate: Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.s(28)
                    radius: root.s(6)
                    color: root.activeFilter === modelData.key ? root.alpha(ThemeBackend.mauve, 0.25) : (tabMa.containsMouse ? root.alpha(ThemeBackend.surface1, 0.5) : ThemeBackend.surface0)
                    border.color: root.activeFilter === modelData.key ? ThemeBackend.mauve : "transparent"
                    border.width: 1

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: root.s(4)

                        Text {
                            text: modelData.icon
                            font.family: root.nerdFont
                            font.pixelSize: root.s(11)
                            color: root.activeFilter === modelData.key ? ThemeBackend.mauve : ThemeBackend.subtext0
                        }

                        Text {
                            text: modelData.label + " (" + modelData.count + ")"
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: root.s(10)
                            font.bold: root.activeFilter === modelData.key
                            color: root.activeFilter === modelData.key ? ThemeBackend.text : ThemeBackend.subtext0
                        }
                    }

                    MouseArea {
                        id: tabMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.activeFilter = modelData.key
                    }
                }
            }
        }

        // Quick Add Task Section
        RowLayout {
            Layout.fillWidth: true
            spacing: root.s(6)

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: root.s(32)
                radius: root.s(8)
                color: ThemeBackend.surface0
                border.color: taskTitleInput.activeFocus ? ThemeBackend.mauve : ThemeBackend.surface1
                border.width: 1

                TextInput {
                    id: taskTitleInput
                    anchors.fill: parent
                    anchors.leftMargin: root.s(10)
                    anchors.rightMargin: root.s(10)
                    verticalAlignment: TextInput.AlignVCenter
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: root.s(12)
                    color: ThemeBackend.text
                    clip: true

                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        text: root.methodology === "scrum" ? "Añadir nueva historia / tarea al sprint..." : (root.methodology === "kanban" ? "Añadir nueva tarjeta al tablero..." : "Añadir tarea a la lista...")
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: root.s(12)
                        color: ThemeBackend.subtext0
                        visible: !taskTitleInput.text && !taskTitleInput.activeFocus
                    }

                    onAccepted: {
                        if (taskTitleInput.text.trim() !== "") {
                            let targetCol = "";
                            if (root.methodology === "scrum") {
                                targetCol = root.activeFilter === "backlog" ? "backlog" : "sprint";
                            } else {
                                targetCol = "todo";
                            }
                            root.addTask(taskTitleInput.text, ptsSelector.currentPts, prioritySelector.currentPriority, targetCol);
                            taskTitleInput.text = "";
                        }
                    }
                }
            }

            // Story Points Quick Selector (optional)
            Rectangle {
                id: ptsSelector
                property int currentPts: root.methodology === "scrum" ? 3 : 0
                readonly property var ptsValues: [0, 1, 2, 3, 5, 8]
                property int index: root.methodology === "scrum" ? 3 : 0

                Layout.preferredWidth: root.s(45)
                Layout.preferredHeight: root.s(32)
                radius: root.s(8)
                color: ThemeBackend.surface0
                border.color: ThemeBackend.surface1
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: ptsSelector.currentPts > 0 ? (ptsSelector.currentPts + " pts") : "0 pts"
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: root.s(11)
                    font.bold: true
                    color: ptsSelector.currentPts > 0 ? ThemeBackend.mauve : ThemeBackend.subtext0
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        ptsSelector.index = (ptsSelector.index + 1) % ptsSelector.ptsValues.length;
                        ptsSelector.currentPts = ptsSelector.ptsValues[ptsSelector.index];
                    }
                }
            }

            // Priority Quick Selector
            Rectangle {
                id: prioritySelector
                property string currentPriority: "medium"
                readonly property var priorities: ["low", "medium", "high", "urgent"]
                readonly property var labels: ["Baja", "Media", "Alta", "Urg"]
                property int index: 1

                Layout.preferredWidth: root.s(55)
                Layout.preferredHeight: root.s(32)
                radius: root.s(8)
                color: ThemeBackend.surface0
                border.color: ThemeBackend.surface1
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: prioritySelector.labels[prioritySelector.index]
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: root.s(11)
                    font.bold: true
                    color: root.getPriorityColor(prioritySelector.currentPriority)
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        prioritySelector.index = (prioritySelector.index + 1) % prioritySelector.priorities.length;
                        prioritySelector.currentPriority = prioritySelector.priorities[prioritySelector.index];
                    }
                }
            }

            // Add Button
            Rectangle {
                Layout.preferredWidth: root.s(34)
                Layout.preferredHeight: root.s(32)
                radius: root.s(8)
                color: ThemeBackend.mauve

                Text {
                    anchors.centerIn: parent
                    text: "󰐕"
                    font.family: root.nerdFont
                    font.pixelSize: root.s(16)
                    color: ThemeBackend.crust
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (taskTitleInput.text.trim() !== "") {
                            let targetCol = "";
                            if (root.methodology === "scrum") {
                                targetCol = root.activeFilter === "backlog" ? "backlog" : "sprint";
                            } else {
                                targetCol = "todo";
                            }
                            root.addTask(taskTitleInput.text, ptsSelector.currentPts, prioritySelector.currentPriority, targetCol);
                            taskTitleInput.text = "";
                        }
                    }
                }
            }
        }

        // Task List View
        ListView {
            id: taskListView
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: root.s(6)
            clip: true
            model: root.filteredTasksList

            delegate: Rectangle {
                id: taskCard
                readonly property string effStatus: root.getTaskEffectiveStatus(modelData)
                width: taskListView.width
                height: taskCardLayout.implicitHeight + root.s(16)
                radius: root.s(8)
                color: effStatus === "in_progress" ? root.alpha(ThemeBackend.peach, 0.12) : ThemeBackend.surface0
                border.color: effStatus === "in_progress" ? root.alpha(ThemeBackend.peach, 0.5) : root.alpha(ThemeBackend.surface1, 0.6)
                border.width: 1

                RowLayout {
                    id: taskCardLayout
                    anchors.fill: parent
                    anchors.leftMargin: root.s(10)
                    anchors.rightMargin: root.s(10)
                    spacing: root.s(8)

                    // Priority Bar Indicator
                    Rectangle {
                        Layout.preferredWidth: root.s(4)
                        Layout.fillHeight: true
                        Layout.topMargin: root.s(4)
                        Layout.bottomMargin: root.s(4)
                        radius: root.s(2)
                        color: root.getPriorityColor(modelData.priority)
                    }

                    // Task Info
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: root.s(3)

                        Text {
                            text: modelData.title || ""
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: root.s(12)
                            font.strikeout: effStatus === "done"
                            color: effStatus === "done" ? ThemeBackend.subtext0 : ThemeBackend.text
                            wrapMode: Text.Wrap
                            Layout.fillWidth: true
                        }

                        Text {
                            visible: Boolean(modelData && modelData.description && modelData.description.trim() !== "")
                            text: (modelData && modelData.description) ? modelData.description : ""
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: root.s(10)
                            color: ThemeBackend.subtext0
                            wrapMode: Text.Wrap
                            Layout.fillWidth: true
                        }

                        RowLayout {
                            spacing: root.s(6)

                            // Status Pill
                            Rectangle {
                                Layout.preferredHeight: root.s(16)
                                Layout.preferredWidth: stText.implicitWidth + root.s(8)
                                radius: root.s(4)
                                color: root.alpha(root.getStatusColor(effStatus), 0.2)

                                Text {
                                    id: stText
                                    anchors.centerIn: parent
                                    text: root.getStatusLabel(effStatus)
                                    font.family: ThemeBackend.fontFamily
                                    font.pixelSize: root.s(9)
                                    font.bold: true
                                    color: root.getStatusColor(effStatus)
                                }
                            }

                            // Points Pill (visible if points > 0)
                            Rectangle {
                                visible: (Number(modelData.points) || 0) > 0
                                Layout.preferredHeight: root.s(16)
                                Layout.preferredWidth: ptText.implicitWidth + root.s(8)
                                radius: root.s(4)
                                color: root.alpha(ThemeBackend.mauve, 0.15)

                                Text {
                                    id: ptText
                                    anchors.centerIn: parent
                                    text: (modelData.points || 0) + " pts"
                                    font.family: ThemeBackend.fontFamily
                                    font.pixelSize: root.s(9)
                                    font.bold: true
                                    color: ThemeBackend.mauve
                                }
                            }
                        }
                    }

                    // Actions: Move Backwards, Move Forwards, Complete, Delete
                    RowLayout {
                        spacing: root.s(4)

                        // In Simple Mode: 1-click Checkbox / Done toggle
                        Rectangle {
                            visible: root.methodology === "simple"
                            width: root.s(24)
                            height: root.s(24)
                            radius: root.s(6)
                            color: simpleDoneMa.containsMouse ? root.alpha(ThemeBackend.green, 0.2) : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: effStatus === "done" ? "󰄲" : "󰄱"
                                font.family: root.nerdFont
                                font.pixelSize: root.s(14)
                                color: effStatus === "done" ? ThemeBackend.green : ThemeBackend.subtext0
                            }

                            MouseArea {
                                id: simpleDoneMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.updateTaskStatus(modelData.id, effStatus === "done" ? "todo" : "done")
                            }
                        }

                        // Backwards button (for Scrum / Kanban)
                        Rectangle {
                            visible: root.methodology !== "simple" && effStatus !== "backlog" && (root.methodology !== "kanban" || effStatus !== "todo")
                            width: root.s(24)
                            height: root.s(24)
                            radius: root.s(6)
                            color: prevMa.containsMouse ? ThemeBackend.surface1 : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "󰁍"
                                font.family: root.nerdFont
                                font.pixelSize: root.s(13)
                                color: ThemeBackend.subtext0
                            }

                            MouseArea {
                                id: prevMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.updateTaskStatus(modelData.id, root.getPrevStatus(effStatus))
                            }
                        }

                        // Forwards button (for Scrum / Kanban)
                        Rectangle {
                            visible: root.methodology !== "simple" && effStatus !== "done"
                            width: root.s(24)
                            height: root.s(24)
                            radius: root.s(6)
                            color: nextMa.containsMouse ? ThemeBackend.surface1 : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: effStatus === "in_progress" ? "󰄲" : "󰁔"
                                font.family: root.nerdFont
                                font.pixelSize: root.s(13)
                                color: effStatus === "in_progress" ? ThemeBackend.green : ThemeBackend.blue
                            }

                            MouseArea {
                                id: nextMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.updateTaskStatus(modelData.id, root.getNextStatus(effStatus))
                            }
                        }

                        // Delete button
                        Rectangle {
                            width: root.s(24)
                            height: root.s(24)
                            radius: root.s(6)
                            color: delMa.containsMouse ? root.alpha(ThemeBackend.red, 0.2) : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "󰆴"
                                font.family: root.nerdFont
                                font.pixelSize: root.s(12)
                                color: delMa.containsMouse ? ThemeBackend.red : ThemeBackend.subtext0
                            }

                            MouseArea {
                                id: delMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.deleteTask(modelData.id)
                            }
                        }
                    }
                }
            }

            // Empty state placeholder
            Text {
                anchors.centerIn: parent
                visible: root.filteredTasksList.length === 0
                text: "No hay tareas en esta vista del tablero"
                font.family: ThemeBackend.fontFamily
                font.pixelSize: root.s(12)
                color: ThemeBackend.subtext0
            }
        }
    }
}
