import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../../reusables"
import "../../../"

Item {
    id: root

    property var module: null
    property var widget: module

    property string orientation: module ? module.orientation : "horizontal"
    readonly property bool isVertical: orientation === "vertical"

    readonly property bool isCompact: module ? module.isCompact : false
    readonly property var barWindow: module ? module.barWindow : null
    readonly property bool moduleActive: module ? module.moduleActive : true
    readonly property bool isSolid: module ? module.isSolid : false
    readonly property bool distinctPills: module ? module.distinctPills : false
    readonly property real barOpacity: ThemeBackend.elementOpacity

    property string nerdFont: ThemeBackend.iconFont

    // Data from tasks.json / scrum.json
    property string methodology: "scrum"
    property string cycleName: "Sprint"
    property var tasksList: []

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

    readonly property var inProgressTasks: tasksList.filter(t => t && getTaskEffectiveStatus(t) === "in_progress")
    readonly property var todoTasks: tasksList.filter(t => t && getTaskEffectiveStatus(t) === "todo")
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

    readonly property int totalPoints: {
        let pts = 0;
        for (let i = 0; i < activeScopeTasks.length; i++) pts += (Number(activeScopeTasks[i].points) || 0);
        return pts;
    }

    readonly property int donePoints: {
        let pts = 0;
        for (let i = 0; i < doneTasks.length; i++) pts += (Number(doneTasks[i].points) || 0);
        return pts;
    }

    readonly property real progressRatio: {
        if (totalPoints > 0) return Math.min(1.0, donePoints / totalPoints);
        if (activeScopeTasks.length > 0) return Math.min(1.0, doneTasks.length / activeScopeTasks.length);
        return 0.0;
    }

    readonly property int progressPercent: Math.round(progressRatio * 100)

    readonly property string activeTaskTitle: {
        if (inProgressTasks.length > 0) return inProgressTasks[0].title || "";
        if (root.methodology === "simple" && todoTasks.length > 0) return todoTasks[0].title || "";
        return "";
    }

    function parseTasks(rawText) {
        let txt = (rawText || "").trim();
        if (txt === "" || txt === "{}") return;
        try {
            let data = JSON.parse(txt);
            if (data.methodology) root.methodology = data.methodology;
            if (data.cycleName) root.cycleName = data.cycleName;
            else if (data.sprint && data.sprint.name) root.cycleName = data.sprint.name;
            if (Array.isArray(data.tasks)) root.tasksList = data.tasks;
        } catch (e) {}
    }

    function handleFileLoaded() {
        let tasksTxt = "";
        let scrumTxt = "";
        try {
            tasksTxt = (typeof tasksWatch.text === "function" ? tasksWatch.text() : tasksWatch.text) || "";
        } catch (e) {}
        try {
            scrumTxt = (typeof scrumWatch.text === "function" ? scrumWatch.text() : scrumWatch.text) || "";
        } catch (e) {}

        if (tasksTxt && tasksTxt.trim() !== "" && tasksTxt.trim() !== "{}") {
            root.parseTasks(tasksTxt);
        } else if (scrumTxt && scrumTxt.trim() !== "" && scrumTxt.trim() !== "{}") {
            root.parseTasks(scrumTxt);
        }
    }

    FileView {
        id: tasksWatch
        path: (typeof Caching !== "undefined" && Caching.stateDir ? Caching.stateDir : ((Quickshell.env("HOME") || "") + "/.local/state/serpantinum")) + "/quickactions/tasks.json"
        watchChanges: true
        onLoaded: root.handleFileLoaded()
        onFileChanged: root.handleFileLoaded()
    }

    FileView {
        id: scrumWatch
        path: (typeof Caching !== "undefined" && Caching.stateDir ? Caching.stateDir : ((Quickshell.env("HOME") || "") + "/.local/state/serpantinum")) + "/quickactions/scrum.json"
        watchChanges: true
        onLoaded: root.handleFileLoaded()
        onFileChanged: root.handleFileLoaded()
    }

    function alpha(color, a) { return Qt.rgba(color.r, color.g, color.b, a); }

    function openTasks() {
        if (typeof FloatingController !== "undefined" && typeof FloatingController.showTasks === "function") {
            FloatingController.showTasks(root.barWindow ? root.barWindow.screen : null);
        } else if (typeof FloatingController !== "undefined" && typeof FloatingController.showScrum === "function") {
            FloatingController.showScrum(root.barWindow ? root.barWindow.screen : null);
        } else if (typeof FloatingController !== "undefined" && typeof FloatingController.setIndex === "function") {
            FloatingController.setIndex(3, root.barWindow ? root.barWindow.screen : null);
        }
    }

    // Dynamic sizing
    property real startPadding: (isSolid && !distinctPills) ? 0 : (barWindow ? barWindow.cs(4) : 4)
    property real endPadding: (isSolid && !distinctPills) ? 0 : (barWindow ? barWindow.cs(8) : 8)
    property real contentWidth: root.isVertical ? 32 : (tasksRow.implicitWidth + startPadding + endPadding)

    implicitWidth: root.isVertical ? (parent ? parent.width : 32) : contentWidth
    implicitHeight: root.isVertical ? (tasksCol.implicitHeight + startPadding + endPadding) : (parent ? parent.height : 32)

    // Horizontal Bar Presentation
    Rectangle {
        visible: !root.isVertical
        anchors.fill: parent
        anchors.topMargin: barWindow ? barWindow.cs(2) : 2
        anchors.bottomMargin: barWindow ? barWindow.cs(2) : 2
        radius: ThemeBackend.borderRadius
        color: barMa.containsMouse ? root.alpha(ThemeBackend.surface1, 0.6) : (root.isSolid ? "transparent" : root.alpha(ThemeBackend.surface0, root.barOpacity))
        border.color: root.alpha(ThemeBackend.surface1, 0.4)
        border.width: root.isSolid ? 0 : 1

        RowLayout {
            id: tasksRow
            anchors.fill: parent
            anchors.leftMargin: root.startPadding
            anchors.rightMargin: root.endPadding
            spacing: barWindow ? barWindow.cs(6) : 6

            Text {
                text: "󰄲"
                font.family: root.nerdFont
                font.pixelSize: barWindow ? barWindow.cs(14) : 14
                color: root.progressPercent >= 100 ? ThemeBackend.green : ThemeBackend.mauve
            }

            Text {
                text: root.totalPoints > 0 ? (root.progressPercent + "%") : (root.doneTasks.length + "/" + root.activeScopeTasks.length)
                font.family: ThemeBackend.fontFamily
                font.pixelSize: barWindow ? barWindow.cs(11) : 11
                font.bold: true
                color: ThemeBackend.text
            }

            Rectangle {
                visible: root.activeTaskTitle !== "" && !root.isCompact
                Layout.preferredHeight: barWindow ? barWindow.cs(14) : 14
                Layout.preferredWidth: 1
                color: ThemeBackend.surface2
            }

            Text {
                visible: root.activeTaskTitle !== "" && !root.isCompact
                text: root.activeTaskTitle
                font.family: ThemeBackend.fontFamily
                font.pixelSize: barWindow ? barWindow.cs(11) : 11
                color: ThemeBackend.peach
                elide: Text.ElideRight
                Layout.maximumWidth: barWindow ? barWindow.cs(160) : 160
            }
        }

        MouseArea {
            id: barMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.openTasks()
        }
    }

    // Vertical Bar Presentation
    ColumnLayout {
        id: tasksCol
        visible: root.isVertical
        anchors.centerIn: parent
        spacing: 2

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "󰄲"
            font.family: root.nerdFont
            font.pixelSize: 14
            color: root.progressPercent >= 100 ? ThemeBackend.green : ThemeBackend.mauve
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: root.totalPoints > 0 ? (root.progressPercent + "%") : (root.doneTasks.length + "/" + root.activeScopeTasks.length)
            font.family: ThemeBackend.fontFamily
            font.pixelSize: 9
            font.bold: true
            color: ThemeBackend.text
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.openTasks()
        }
    }
}
