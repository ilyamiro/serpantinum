import QtQuick
import Quickshell
import "."

// Creative-inventory app launcher. Grid of app "items", a search box, a hotbar with the
// nine most used apps, and the purple item tooltip. Purely UI: the window, ranking data
// and launching live in launcher/McInventory.qml.
Item {
    id: inv

    property var ranks: ({ "focus": {}, "launch": {}, "context": {} })
    property bool open: false

    signal launch(string name, string desktopId)
    signal closeRequested()

    readonly property int k: Math.max(2, Math.min(6, Math.round(height / 260)))
    readonly property int slot: 18 * k
    readonly property int cols: 9
    readonly property int rows: 5

    property var allApps: []
    property var shown: []
    property var hotbar: []
    property int current: 0          // index into `shown`
    property int hotCurrent: -1      // hovered hotbar slot
    property string query: ""

    function score(e) {
        let cls = (e.startupClass || "").toLowerCase();
        let base = e.id.toLowerCase().replace(".desktop", "");
        let nm = (e.name || "").toLowerCase();
        let f = ranks.focus[cls] || ranks.focus[base] || ranks.focus[nm] || 0;
        let l = ranks.launch[e.name] || 0;
        let c = (ranks.context && (ranks.context[cls] || ranks.context[base] || ranks.context[nm])) || 0;
        return f + l + 0.5 * c;
    }

    function reload() {
        let arr = [];
        let seen = {};
        let entries = DesktopEntries.applications.values;
        for (let i = 0; i < entries.length; i++) {
            let e = entries[i];
            if (e.noDisplay || seen[e.name]) continue;
            seen[e.name] = true;
            arr.push({ name: e.name, desc: e.comment || e.genericName || "", id: e.id, icon: e.icon || "", score: score(e) });
        }
        arr.sort((a, b) => b.score - a.score || a.name.localeCompare(b.name));
        allApps = arr;
        hotbar = arr.slice(0, 9);
        filter();
    }

    function filter() {
        let q = query.trim().toLowerCase();
        if (q === "") {
            // Inventory order: alphabetical, like a creative tab.
            shown = allApps.slice().sort((a, b) => a.name.localeCompare(b.name));
        } else {
            let hits = [];
            for (let a of allApps) {
                let n = a.name.toLowerCase();
                let rank = n.startsWith(q) ? 0 : (n.indexOf(q) >= 0 ? 1
                    : (a.desc.toLowerCase().indexOf(q) >= 0 || a.id.toLowerCase().indexOf(q) >= 0 ? 2 : -1));
                if (rank >= 0) hits.push({ a: a, r: rank });
            }
            hits.sort((x, y) => x.r - y.r || y.a.score - x.a.score);
            shown = hits.map(h => h.a);
        }
        current = 0;
        hotCurrent = -1;
        grid.positionViewAtBeginning();
    }

    function iconSource(ic) {
        if (!ic) return "";
        if (ic.startsWith("/")) return "file://" + ic;
        if (ic.indexOf("://") >= 0) return ic;
        let base = ic.replace(/\.(png|svg|xpm|ico)$/i, "");
        let r = Quickshell.iconPath(ic, true) || Quickshell.iconPath(base, true);
        if (r) return r.startsWith("/") ? "file://" + r : r;
        return "image://icon/" + base;
    }

    function activate(app) {
        if (!app) return;
        inv.launch(app.name, app.id);
    }

    function move(dx, dy) {
        if (shown.length === 0) return;
        hotCurrent = -1;
        let n = current + dx + dy * cols;
        current = Math.max(0, Math.min(shown.length - 1, n));
        grid.positionViewAtIndex(current, GridView.Contain);
    }

    onOpenChanged: {
        if (open) {
            search.text = "";
            query = "";
            reload();
            search.forceActiveFocus();
            popIn.restart();
        }
    }
    onRanksChanged: if (open) reload()
    // Desktop entries load asynchronously: refresh when they arrive or change.
    Connections {
        target: DesktopEntries.applications
        function onValuesChanged() { if (inv.open) inv.reload(); }
    }

    readonly property var tipApp: hotCurrent >= 0 ? hotbar[hotCurrent] : shown[current]
    readonly property Item tipAnchor: hotCurrent >= 0 ? hotRow.children[hotCurrent] || null : grid.currentItem

    // Darkened world behind the GUI.
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.rgba(0.06, 0.06, 0.06, 0.75) }
            GradientStop { position: 1; color: Qt.rgba(0.06, 0.06, 0.06, 0.82) }
        }
        MouseArea { anchors.fill: parent; onPressed: inv.closeRequested() }
    }

    // A slot: dark top-left, white bottom-right, gray inside.
    component Slot: Item {
        id: sl
        property var app: null
        property bool highlighted: false
        property string count: ""
        width: inv.slot
        height: inv.slot
        Rectangle { anchors.fill: parent; color: "#373737" }
        Rectangle { x: inv.k; y: inv.k; width: parent.width - inv.k; height: parent.height - inv.k; color: "#ffffff" }
        Rectangle { x: inv.k; y: inv.k; width: parent.width - inv.k * 2; height: parent.height - inv.k * 2; color: "#8b8b8b" }
        Image {
            x: inv.k; y: inv.k
            width: parent.width - inv.k * 2
            height: width
            sourceSize: Qt.size(64, 64)
            source: sl.app ? inv.iconSource(sl.app.icon) : ""
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            smooth: true
            mipmap: true
            // a missing icon shows the first letter, like a placeholder item
            McText {
                anchors.centerIn: parent
                visible: sl.app !== null && parent.status !== Image.Ready
                text: sl.app ? sl.app.name.charAt(0).toUpperCase() : ""
                font.pixelSize: inv.k * 10
            }
        }
        Rectangle {
            x: inv.k; y: inv.k
            width: parent.width - inv.k * 2
            height: width
            color: "#ffffff"
            opacity: sl.highlighted ? 0.5 : 0
        }
        McText {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: inv.k
            text: sl.count
            font.pixelSize: inv.k * 6
            visible: sl.count !== ""
        }
    }

    Item {
        id: gui
        anchors.centerIn: parent
        width: 195 * inv.k
        height: guiCol.implicitHeight + 14 * inv.k
        transformOrigin: Item.Center

        ParallelAnimation {
            id: popIn
            NumberAnimation { target: gui; property: "scale"; from: 0.92; to: 1; duration: 140; easing.type: Easing.OutBack }
            NumberAnimation { target: gui; property: "opacity"; from: 0; to: 1; duration: 120 }
        }

        MouseArea { anchors.fill: parent }   // clicks on the GUI don't close it

        // Classic light-gray GUI with white/dark bevel and black outline.
        McPanel {
            anchors.fill: parent
            bevel: inv.k
            fill: "#c6c6c6"
            light: "#ffffff"
            dark: "#555555"
        }

        Column {
            id: guiCol
            x: 7 * inv.k
            y: 6 * inv.k
            width: parent.width - 14 * inv.k
            spacing: 3 * inv.k

            // Title + search box
            Item {
                width: parent.width
                height: 12 * inv.k
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: inv.query === "" ? "Інвентар" : "Пошук предметів"
                    font.family: "Monocraft"
                    font.pixelSize: inv.k * 7
                    color: "#404040"
                }
                Rectangle {
                    id: searchBox
                    anchors.right: parent.right
                    anchors.rightMargin: 14 * inv.k
                    width: 90 * inv.k
                    height: parent.height
                    color: "#000000"
                    border.width: inv.k / 2 > 1 ? Math.round(inv.k / 2) : 1
                    border.color: "#a0a0a0"
                    TextInput {
                        id: search
                        anchors.fill: parent
                        anchors.leftMargin: 2 * inv.k
                        anchors.rightMargin: 2 * inv.k
                        verticalAlignment: TextInput.AlignVCenter
                        font.family: "Monocraft"
                        font.pixelSize: inv.k * 6
                        color: "#ffffff"
                        clip: true
                        cursorDelegate: Item {}
                        onTextChanged: { inv.query = text; inv.filter(); }
                        Keys.onPressed: (e) => {
                            if (e.key === Qt.Key_Escape) { inv.closeRequested(); e.accepted = true; }
                            else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { inv.activate(inv.tipApp); e.accepted = true; }
                            else if (e.key === Qt.Key_Down) { inv.move(0, 1); e.accepted = true; }
                            else if (e.key === Qt.Key_Up) { inv.move(0, -1); e.accepted = true; }
                            else if (e.key === Qt.Key_Right && (search.text === "" || search.cursorPosition === search.text.length)) { inv.move(1, 0); e.accepted = true; }
                            else if (e.key === Qt.Key_Left && (search.text === "" || search.cursorPosition === 0)) { inv.move(-1, 0); e.accepted = true; }
                            else if (e.key === Qt.Key_Tab) { inv.move(1, 0); e.accepted = true; }
                            else if (search.text === "" && e.text >= "1" && e.text <= "9" && e.text.length === 1) {
                                inv.activate(inv.hotbar[parseInt(e.text) - 1]);
                                e.accepted = true;
                            }
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: search.text === ""
                            text: "Шукати..."
                            font: search.font
                            color: "#707070"
                        }
                        Text {
                            x: search.cursorRectangle.x
                            anchors.verticalCenter: parent.verticalCenter
                            text: "_"
                            font: search.font
                            color: "#ffffff"
                            visible: search.activeFocus && caretBlink.on
                        }
                        Timer { id: caretBlink; property bool on: true; interval: 500; repeat: true; running: inv.open; onTriggered: on = !on }
                    }
                }
            }

            // Item grid + scrollbar
            Row {
                spacing: 2 * inv.k
                GridView {
                    id: grid
                    width: inv.cols * inv.slot
                    height: inv.rows * inv.slot
                    cellWidth: inv.slot
                    cellHeight: inv.slot
                    clip: true
                    model: inv.shown
                    currentIndex: inv.current
                    boundsBehavior: Flickable.StopAtBounds
                    highlightFollowsCurrentItem: false
                    snapMode: GridView.SnapToRow
                    delegate: Slot {
                        required property var modelData
                        required property int index
                        app: modelData
                        highlighted: inv.hotCurrent < 0 && index === inv.current
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: { inv.hotCurrent = -1; inv.current = index; }
                            onClicked: inv.activate(modelData)
                        }
                    }
                    WheelHandler {
                        onWheel: (ev) => {
                            let rowsScrolled = ev.angleDelta.y > 0 ? -1 : 1;
                            grid.contentY = Math.max(0, Math.min(grid.contentHeight - grid.height, grid.contentY + rowsScrolled * inv.slot));
                        }
                    }
                }
                McText {
                    visible: inv.shown.length === 0
                    parent: grid
                    anchors.centerIn: parent
                    text: "Нічого не знайдено"
                    color: "#404040"
                    shadowColor: "transparent"
                    font.pixelSize: inv.k * 6
                }
                // Scrollbar: dark track, stone thumb
                Item {
                    width: 12 * inv.k
                    height: grid.height
                    Rectangle { anchors.fill: parent; color: "#8b8b8b"; border.width: inv.k / 2 > 1 ? Math.round(inv.k / 2) : 1; border.color: "#373737" }
                    McPanel {
                        readonly property real range: Math.max(1, grid.contentHeight - grid.height)
                        readonly property bool scrollable: grid.contentHeight > grid.height + 1
                        width: parent.width
                        height: 15 * inv.k
                        y: scrollable ? (parent.height - height) * Math.min(1, grid.contentY / range) : 0
                        bevel: inv.k
                        fill: scrollable ? "#c6c6c6" : "#a0a0a0"
                        light: "#ffffff"
                        dark: "#555555"
                    }
                }
            }

            // Hotbar: nine most used apps, keys 1-9
            Text {
                text: "Швидкий доступ"
                font.family: "Monocraft"
                font.pixelSize: inv.k * 5
                color: "#404040"
            }
            Row {
                id: hotRow
                Repeater {
                    model: inv.hotbar
                    delegate: Slot {
                        required property var modelData
                        required property int index
                        app: modelData
                        count: String(index + 1)
                        highlighted: index === inv.hotCurrent
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: inv.hotCurrent = index
                            onExited: if (inv.hotCurrent === index) inv.hotCurrent = -1
                            onClicked: inv.activate(modelData)
                        }
                    }
                }
            }
        }
    }

    // Hint line under the GUI
    McText {
        anchors.horizontalCenter: gui.horizontalCenter
        anchors.top: gui.bottom
        anchors.topMargin: 4 * inv.k
        text: "Enter — запустити · 1-9 — швидкий доступ · Esc — закрити"
        font.pixelSize: inv.k * 5
        color: "#e0e0e0"
    }

    // Item tooltip
    Item {
        id: tip
        visible: inv.tipApp !== undefined && inv.tipApp !== null && inv.tipAnchor !== null
        z: 100
        readonly property point at: inv.tipAnchor ? inv.tipAnchor.mapToItem(inv, inv.slot, 0) : Qt.point(0, 0)
        x: Math.min(at.x + 2 * inv.k, inv.width - width - 4)
        y: Math.max(4, at.y - 6 * inv.k)
        width: Math.max(tipName.implicitWidth, tipDesc.implicitWidth, tipId.implicitWidth) + 8 * inv.k
        height: tipCol.implicitHeight + 8 * inv.k

        Rectangle { anchors.fill: parent; color: Qt.rgba(0.06, 0, 0.06, 0.94) }
        Rectangle {
            anchors.fill: parent
            anchors.margins: inv.k
            color: "transparent"
            border.width: inv.k
            border.color: "#3a0f8f"
        }
        Column {
            id: tipCol
            x: 4 * inv.k
            y: 4 * inv.k
            spacing: 2 * inv.k
            McText {
                id: tipName
                text: tip.visible ? inv.tipApp.name : ""
                font.pixelSize: inv.k * 6
            }
            McText {
                id: tipDesc
                visible: text !== ""
                text: tip.visible ? inv.tipApp.desc.slice(0, 60) : ""
                font.pixelSize: inv.k * 5
                color: "#aaaaaa"
            }
            McText {
                id: tipId
                text: tip.visible ? "minecraft:" + inv.tipApp.id.replace(/\.desktop$/, "").toLowerCase() : ""
                font.pixelSize: inv.k * 4
                color: "#555555"
            }
        }
    }
}
