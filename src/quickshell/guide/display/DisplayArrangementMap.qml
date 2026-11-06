import QtQuick
import QtQuick.Layouts
import "../../"
import "../../reusables"
import "DisplayLayoutMath.js" as LM

// Arrangement map: enabled monitors drawn at their logical size. Dragging one shows
// where it will land (edges snap, overlaps are avoided, the layout stays connected);
// dropping applies the move through the confirm-or-revert transaction.
ColumnLayout {
    id: map
    required property var tab
    readonly property var rootObj: tab.rootObj

    Layout.fillWidth: true
    spacing: rootObj.s(8)

    property string draggingName: ""
    property var preview: null

    readonly property bool canDrag: tab.txnAvailable && !tab.txnPending && !tab.txnBusy && rects.length > 1

    // Enabled monitors in logical pixels.
    readonly property var rects: {
        let out = [];
        let list = tab.monitorsList || [];
        for (let i = 0; i < list.length; i++) {
            let m = list[i];
            if (!m.active || !m.width) continue;
            let sz = LM.logicalSize(m);
            out.push({
                "name": m.name, "idx": i + 1,
                "x": m.x || 0, "y": m.y || 0, "w": sz.w, "h": sz.h,
                "refresh": m.refresh, "focused": !!m.focused,
                "width": m.width, "height": m.height
            });
        }
        return out;
    }

    // Visible world: the monitors plus free room around them so there is space to drag.
    readonly property var bounds: {
        if (rects.length === 0) return { "x": 0, "y": 0, "w": 1920, "h": 1080 };
        let minX = rects[0].x, minY = rects[0].y, maxX = rects[0].x + rects[0].w, maxY = rects[0].y + rects[0].h;
        let big = 0;
        for (let i = 0; i < rects.length; i++) {
            minX = Math.min(minX, rects[i].x);
            minY = Math.min(minY, rects[i].y);
            maxX = Math.max(maxX, rects[i].x + rects[i].w);
            maxY = Math.max(maxY, rects[i].y + rects[i].h);
            big = Math.max(big, rects[i].w, rects[i].h);
        }
        let pad = big * 0.45;
        return { "x": minX - pad, "y": minY - pad, "w": (maxX - minX) + 2 * pad, "h": (maxY - minY) + 2 * pad };
    }
    readonly property real k: Math.max(0.0001, Math.min(frame.width / bounds.w, frame.height / bounds.h))
    readonly property real offX: (frame.width - bounds.w * k) / 2
    readonly property real offY: (frame.height - bounds.h * k) / 2
    readonly property real snapThreshold: rootObj.s(10) / k

    function findRect(name) {
        for (let i = 0; i < rects.length; i++) if (rects[i].name === name) return rects[i];
        return null;
    }

    function updatePreview(name, dx, dy) {
        let r = findRect(name);
        if (!r) { preview = null; return; }
        let res = LM.resolveDrop(rects, name, r.x + dx / k, r.y + dy / k, snapThreshold);
        preview = { "name": name, "ok": res.ok, "x": res.x, "y": res.y, "w": r.w, "h": r.h };
    }

    // Resolve a drop and send it through the transaction. Also used by tests.
    function dropMonitor(name, lx, ly) {
        let cur = findRect(name);
        let res = LM.resolveDrop(rects, name, lx, ly, snapThreshold);
        draggingName = "";
        preview = null;
        if (!cur) return false;
        if (!res.ok) {
            tab.showTxnNotice(res.reason === "overlap" ? "err_layout_overlap" : "err_layout_disconnected", true);
            return false;
        }
        if (res.x === cur.x && res.y === cur.y) return true;
        return tab.txnChange(name, { "x": res.x, "y": res.y });
    }

    Rectangle {
        id: frame
        Layout.fillWidth: true
        Layout.preferredHeight: rootObj.s(250)
        radius: ThemeBackend.borderRadius
        color: Qt.alpha(ThemeBackend.surface0, 0.4)
        border.width: 1
        border.color: Qt.alpha(ThemeBackend.surface2, 0.5)
        clip: true

        Canvas {
            anchors.fill: parent
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onPaint: {
                let ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                ctx.strokeStyle = Qt.alpha(ThemeBackend.surface2, 0.35);
                ctx.lineWidth = 1;
                let step = rootObj.s(22);
                ctx.beginPath();
                for (let x = step; x < width; x += step) { ctx.moveTo(x + 0.5, 0); ctx.lineTo(x + 0.5, height); }
                for (let y = step; y < height; y += step) { ctx.moveTo(0, y + 0.5); ctx.lineTo(width, y + 0.5); }
                ctx.stroke();
            }
        }

        // Where the dragged monitor will land.
        Rectangle {
            visible: map.preview !== null && map.draggingName !== ""
            x: map.preview ? map.offX + (map.preview.x - map.bounds.x) * map.k : 0
            y: map.preview ? map.offY + (map.preview.y - map.bounds.y) * map.k : 0
            width: map.preview ? map.preview.w * map.k : 0
            height: map.preview ? map.preview.h * map.k : 0
            radius: rootObj.s(6)
            color: Qt.alpha(map.preview && map.preview.ok ? ThemeBackend.mauve : ThemeBackend.red, 0.14)
            border.width: 2
            border.color: map.preview && map.preview.ok ? ThemeBackend.mauve : ThemeBackend.red
        }

        Repeater {
            model: map.rects

            delegate: Rectangle {
                id: mon
                required property var modelData
                readonly property bool isDragging: map.draggingName === modelData.name
                property real dragDX: 0
                property real dragDY: 0

                x: map.offX + (modelData.x - map.bounds.x) * map.k + (isDragging ? dragDX : 0)
                y: map.offY + (modelData.y - map.bounds.y) * map.k + (isDragging ? dragDY : 0)
                width: modelData.w * map.k
                height: modelData.h * map.k
                z: isDragging ? 10 : 1
                radius: rootObj.s(6)
                color: isDragging ? Qt.alpha(ThemeBackend.surface2, 0.95) : Qt.alpha(ThemeBackend.surface1, 0.9)
                border.width: modelData.focused ? 2 : 1
                border.color: modelData.focused ? ThemeBackend.mauve : Qt.alpha(ThemeBackend.surface2, 0.9)
                opacity: map.canDrag || map.rects.length < 2 ? 1.0 : 0.75

                Behavior on x { enabled: !mon.isDragging; NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                Behavior on y { enabled: !mon.isDragging; NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                Text {
                    anchors.top: parent.top
                    anchors.topMargin: rootObj.s(6)
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width - rootObj.s(8)
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: Math.round(modelData.refresh) + "Hz"
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: rootObj.s(11)
                    color: ThemeBackend.subtext0
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 0
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: modelData.idx
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: rootObj.s(26)
                        font.bold: true
                        color: ThemeBackend.text
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: modelData.focused
                        text: "★"
                        font.pixelSize: rootObj.s(12)
                        color: ThemeBackend.mauve
                    }
                }

                Text {
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: rootObj.s(6)
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width - rootObj.s(8)
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: modelData.name + "  " + modelData.width + "×" + modelData.height
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: rootObj.s(10)
                    color: ThemeBackend.subtext0
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: map.canDrag
                    hoverEnabled: true
                    cursorShape: !enabled ? Qt.ArrowCursor : (pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor)
                    property real startX: 0
                    property real startY: 0

                    onPressed: function(e) {
                        let p = mapToItem(frame, e.x, e.y);
                        startX = p.x;
                        startY = p.y;
                        mon.dragDX = 0;
                        mon.dragDY = 0;
                        map.draggingName = mon.modelData.name;
                        map.updatePreview(mon.modelData.name, 0, 0);
                    }
                    onPositionChanged: function(e) {
                        if (!pressed) return;
                        let p = mapToItem(frame, e.x, e.y);
                        mon.dragDX = p.x - startX;
                        mon.dragDY = p.y - startY;
                        map.updatePreview(mon.modelData.name, mon.dragDX, mon.dragDY);
                    }
                    onReleased: {
                        let r = map.findRect(mon.modelData.name);
                        if (r) map.dropMonitor(mon.modelData.name, r.x + mon.dragDX / map.k, r.y + mon.dragDY / map.k);
                        mon.dragDX = 0;
                        mon.dragDY = 0;
                    }
                    onCanceled: {
                        map.draggingName = "";
                        map.preview = null;
                    }
                }
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: rootObj.s(8)

        Text {
            Layout.fillWidth: true
            text: map.rects.length > 1 ? I18n.t("guide.display.map.hint") : ""
            wrapMode: Text.WordWrap
            font.family: ThemeBackend.fontFamily
            font.pixelSize: rootObj.s(11)
            color: ThemeBackend.subtext0
        }

        ClickButton {
            implicitHeight: rootObj.s(32)
            cornerRadius: ThemeBackend.borderRadius
            horizontalPadding: rootObj.s(14)
            buttonText: I18n.t("guide.display.map.refresh")
            buttonIcon: "󰑐"
            iconFontSize: rootObj.s(14)
            textFontSize: rootObj.s(12)
            accentColor: ThemeBackend.surface1
            onClicked: map.tab.reloadMonitors()
        }
    }
}
