import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import "../"
import "../mc"

// Small launcher in the bar's Minecraft look (dark McPanel capsules, stone buttons): one centered box,
// search on top, 7 rows of icon + name. Shown while LauncherController.minimal is true.
PanelWindow {
    id: win

    readonly property bool shown: LauncherController.isVisible && LauncherController.minimal
    readonly property int rowH: 40
    readonly property int lines: 7

    screen: LauncherController.screen
    visible: shown
    focusable: shown
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "qs-applauncher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    implicitWidth: 620
    implicitHeight: box.height

    // click outside closes
    HyprlandFocusGrab {
        windows: [win]
        active: win.shown
        onCleared: LauncherController.hide()
    }

    property var ranks: ({ "focus": {}, "launch": {}, "context": {} })
    property var allApps: []
    property var shownApps: []
    property int current: 0

    Process {
        id: rankFetcher
        command: Caching.qsDir ? ["python3", Caching.qsDir + "/launcher/app_rank.py", "--rank"] : []
        stdout: StdioCollector {
            onStreamFinished: {
                try { if (this.text && this.text.trim().length > 0) { win.ranks = JSON.parse(this.text); win.reload(); } } catch (e) {}
            }
        }
    }

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
        let arr = [], seen = {};
        let entries = DesktopEntries.applications.values;
        for (let i = 0; i < entries.length; i++) {
            let e = entries[i];
            if (e.noDisplay || seen[e.name]) continue;
            seen[e.name] = true;
            arr.push({ name: e.name, desc: e.comment || "", id: e.id, icon: e.icon || "", score: score(e) });
        }
        arr.sort((a, b) => b.score - a.score || a.name.localeCompare(b.name));
        allApps = arr;
        filter();
    }
    // fuzzy: every query char in order; prefix and substring hits rank first
    function filter() {
        let q = search.text.trim().toLowerCase();
        if (q === "") { shownApps = allApps; current = 0; list.positionViewAtBeginning(); return; }
        let hits = [];
        for (let a of allApps) {
            let n = a.name.toLowerCase();
            let r = n.startsWith(q) ? 0 : n.indexOf(q) >= 0 ? 1 : -1;
            if (r < 0) {
                let i = 0;
                for (let ch of n) if (ch === q[i]) i++;
                if (i === q.length) r = 2;
                else if (a.desc.toLowerCase().indexOf(q) >= 0 || a.id.toLowerCase().indexOf(q) >= 0) r = 3;
            }
            if (r >= 0) hits.push({ a: a, r: r });
        }
        hits.sort((x, y) => x.r - y.r || y.a.score - x.a.score);
        shownApps = hits.map(h => h.a);
        current = 0;
        list.positionViewAtBeginning();
    }
    function iconSource(ic) {
        if (!ic) return "";
        if (ic.startsWith("/")) return "file://" + ic;
        if (ic.indexOf("://") >= 0) return ic;
        let base = ic.replace(/\.(png|svg|xpm|ico)$/i, "");
        let r = Quickshell.iconPath(ic, true) || Quickshell.iconPath(base, true);
        return r ? (r.startsWith("/") ? "file://" + r : r) : "";
    }
    function launch(app) {
        if (!app) return;
        let entry = DesktopEntries.byId(app.id);
        if (entry) entry.execute();
        if (Caching.qsDir)
            Quickshell.execDetached(["python3", Caching.qsDir + "/launcher/app_rank.py", "--log-launch", "--name", app.name]);
        LauncherController.hide();
    }
    function move(d) {
        if (shownApps.length === 0) return;
        current = (current + d + shownApps.length) % shownApps.length;
        list.positionViewAtIndex(current, ListView.Contain);
    }

    onShownChanged: {
        if (!shown) return;
        search.text = "";
        reload();
        if (Caching.qsDir) rankFetcher.running = true;
        search.forceActiveFocus();
        box.opacity = 0; box.scale = 0.97; popIn.restart();
    }
    Connections {
        target: DesktopEntries.applications
        function onValuesChanged() { if (win.shown) win.reload(); }
    }

    Item {
        id: box
        width: parent.width
        height: col.implicitHeight + 20
        transformOrigin: Item.Top

        // same capsule as the bar modules
        McPanel {
            anchors.fill: parent
            bevel: 2
            fill: "#1d1d1d"
            light: "#4a4a4a"
            dark: "#0a0a0a"
        }

        ParallelAnimation {
            id: popIn
            NumberAnimation { target: box; property: "opacity"; to: 1; duration: 110 }
            NumberAnimation { target: box; property: "scale"; to: 1; duration: 140; easing.type: Easing.OutCubic }
        }

        Column {
            id: col
            x: 10; y: 10
            width: parent.width - 20
            spacing: 6

            Item {
                width: parent.width
                height: 38
                McPanel {
                    anchors.fill: parent
                    inset: true
                    bevel: 2
                    fill: "#0c0c0c"
                    light: "#050505"
                    dark: "#3a3a3a"
                }
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    x: 13
                    spacing: 9
                    McText {
                        text: "Програми"
                        color: "#a0a0a0"
                        font.family: "Monocraft"
                        font.pixelSize: 14
                    }
                    TextInput {
                        id: search
                        width: col.width - 130
                        color: "#eeeeee"
                        font.family: "Monocraft"
                        font.pixelSize: 14
                        selectionColor: "#444444"
                        clip: true
                        onTextChanged: win.filter()
                        Keys.onPressed: (e) => {
                            if (e.key === Qt.Key_Escape) { LauncherController.hide(); e.accepted = true; }
                            else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { win.launch(win.shownApps[win.current]); e.accepted = true; }
                            else if (e.key === Qt.Key_Down || e.key === Qt.Key_Tab || (e.key === Qt.Key_J && (e.modifiers & Qt.ControlModifier))) { win.move(1); e.accepted = true; }
                            else if (e.key === Qt.Key_Up || e.key === Qt.Key_Backtab || (e.key === Qt.Key_K && (e.modifiers & Qt.ControlModifier))) { win.move(-1); e.accepted = true; }
                        }
                        Text {
                            visible: search.text === ""
                            text: "Пошук..."
                            color: "#777777"
                            font: search.font
                        }
                    }
                }
            }

            ListView {
                id: list
                width: parent.width
                height: Math.min(win.lines, Math.max(1, win.shownApps.length)) * (win.rowH + spacing) - spacing
                spacing: 2
                clip: true
                model: win.shownApps
                currentIndex: win.current
                boundsBehavior: Flickable.StopAtBounds
                highlightMoveDuration: 0
                Behavior on height { NumberAnimation { duration: 90 } }
                delegate: Item {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool sel: index === win.current
                    width: list.width
                    height: win.rowH
                    // selected row = stone button like the bar's, hovered = faint
                    McPanel {
                        anchors.fill: parent
                        visible: row.sel
                        bevel: 2
                        fill: "#5e5e5e"
                        light: "#a0a0a0"
                        dark: "#2e2e2e"
                    }
                    Rectangle {
                        anchors.fill: parent
                        visible: row.sel
                        color: "transparent"
                        border.width: 2
                        border.color: "#ffffff"
                    }
                    Rectangle {
                        anchors.fill: parent
                        visible: !row.sel && rowMa.containsMouse
                        color: Qt.rgba(1, 1, 1, 0.06)
                    }
                    Image {
                        id: ic
                        x: 11
                        anchors.verticalCenter: parent.verticalCenter
                        width: 24; height: 24
                        sourceSize: Qt.size(56, 56)
                        source: win.iconSource(modelData.icon)
                        asynchronous: true
                        smooth: true
                        mipmap: true
                    }
                    Text {
                        visible: ic.status !== Image.Ready
                        anchors.centerIn: ic
                        text: modelData.name.charAt(0).toUpperCase()
                        color: "#666666"
                        font.family: "Monocraft"
                        font.pixelSize: 14
                    }
                    McText {
                        anchors.left: ic.right
                        anchors.leftMargin: 12
                        anchors.right: parent.right
                        anchors.rightMargin: 11
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.name
                        elide: Text.ElideRight
                        color: row.sel ? "#ffffff" : "#d0d0d0"
                        font.family: "Monocraft"
                        font.pixelSize: 14
                    }
                    MouseArea {
                        id: rowMa
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: win.current = index
                        onClicked: win.launch(modelData)
                    }
                }
                McText {
                    visible: win.shownApps.length === 0
                    anchors.centerIn: parent
                    text: "Нічого не знайдено"
                    color: "#a0a0a0"
                    font.family: "Monocraft"
                    font.pixelSize: 14
                }
            }
        }
    }
}
