import QtQuick
import "../../"
import "../../reusables/canvas"

Item {
    id: stage

    property real k: 0.5
    property bool active: false
    property bool gridEnabled: true
    property bool panelSelected: true
    property alias scene: scene
    property alias selectionItem: panelSelection
    readonly property real unit: 1 / Math.max(stage.k, 0.05)
    readonly property real gridStep: Scaler.s(20)
    readonly property real panelLeft: LockLayoutStore.panelX >= 0 ? LockLayoutStore.panelX : (stage.width - LockLayoutStore.panelW) / 2
    readonly property real panelTop: LockLayoutStore.panelY >= 0 ? LockLayoutStore.panelY : (stage.height - LockLayoutStore.panelH) / 2
    readonly property real minPanelW: Scaler.s(240)
    readonly property real minPanelH: Scaler.s(160)

    property real resizeStartL: 0
    property real resizeStartT: 0
    property real resizeStartW: 0
    property real resizeStartH: 0

    function snap(v) {
        return stage.gridEnabled ? Math.round(v / stage.gridStep) * stage.gridStep : v;
    }

    function shiftItems(dx, dy) {
        let m = LockLayoutStore.panelItems;
        for (let i = 0; i < m.count; i++) {
            m.setProperty(i, "ix", m.get(i).ix + dx);
            m.setProperty(i, "iy", m.get(i).iy + dy);
        }
    }

    function contentInsets() {
        let l = Infinity;
        let t = Infinity;
        let r = Infinity;
        let b = Infinity;
        for (let i = 0; i < scene.itemsModel.count; i++) {
            let p = scene.proxyAt(i);
            if (!p) continue;
            l = Math.min(l, p.x);
            t = Math.min(t, p.y);
            r = Math.min(r, panel.width - (p.x + p.width));
            b = Math.min(b, panel.height - (p.y + p.height));
        }
        return { l: Math.max(0, l), t: Math.max(0, t), r: Math.max(0, r), b: Math.max(0, b) };
    }

    function movePanel(left, top) {
        let nl = Math.max(0, Math.min(stage.width - panel.width, stage.snap(left)));
        let nt = Math.max(0, Math.min(stage.height - panel.height, stage.snap(top)));
        if (nl === stage.panelLeft && nt === stage.panelTop) return;
        LockLayoutStore.setPanelRect(nl, nt, panel.width, panel.height);
    }

    function resizePanel(ex, ey, dx, dy) {
        let ins = stage.contentInsets();
        let curL = stage.panelLeft;
        let curT = stage.panelTop;
        let curR = curL + panel.width;
        let curB = curT + panel.height;

        let l = curL;
        let t = curT;
        let r = curR;
        let b = curB;

        if (ex < 0) l = Math.max(0, Math.min(stage.snap(stage.resizeStartL + dx), curL + ins.l, curR - stage.minPanelW));
        if (ex > 0) r = Math.min(stage.width, Math.max(stage.snap(stage.resizeStartL + stage.resizeStartW + dx), curR - ins.r, curL + stage.minPanelW));
        if (ey < 0) t = Math.max(0, Math.min(stage.snap(stage.resizeStartT + dy), curT + ins.t, curB - stage.minPanelH));
        if (ey > 0) b = Math.min(stage.height, Math.max(stage.snap(stage.resizeStartT + stage.resizeStartH + dy), curB - ins.b, curT + stage.minPanelH));

        if (l === curL && t === curT && r === curR && b === curB) return;
        stage.shiftItems(curL - l, curT - t);
        LockLayoutStore.setPanelRect(l, t, r - l, b - t);
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: {
            scene.selectedId = "";
            stage.panelSelected = false;
        }
    }

    Rectangle {
        id: panel
        width: LockLayoutStore.panelW
        height: LockLayoutStore.panelH
        x: stage.panelLeft
        y: stage.panelTop
        radius: ThemeBackend.borderRadius * 1.5
        color: Qt.alpha(ThemeBackend.surface0, ThemeBackend.elementOpacity * LockLayoutStore.panelOpacity)

        MouseArea {
            id: moveMa
            anchors.fill: parent
            hoverEnabled: true
            preventStealing: true
            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor

            property real startMX
            property real startMY
            property real startLeft
            property real startTop

            onPressed: (mouse) => {
                scene.selectedId = "";
                stage.panelSelected = true;
                let p = mapToItem(stage, mouse.x, mouse.y);
                startMX = p.x;
                startMY = p.y;
                startLeft = stage.panelLeft;
                startTop = stage.panelTop;
            }

            onPositionChanged: (mouse) => {
                if (!pressed) return;
                let p = mapToItem(stage, mouse.x, mouse.y);
                stage.movePanel(startLeft + p.x - startMX, startTop + p.y - startMY);
            }
        }

        LockScene {
            id: scene
            anchors.fill: parent
            scope: "panel"
            handleBlank: false
            k: stage.k
            active: stage.active
            gridEnabled: stage.gridEnabled
            onSelectedIdChanged: {
                if (scene.selectedId !== "") stage.panelSelected = false;
            }
        }
    }

    SelectionFrame {
        id: panelSelection
        x: panel.x - Scaler.s(8)
        y: panel.y - Scaler.s(8)
        width: panel.width + Scaler.s(16)
        height: panel.height + Scaler.s(16)
        z: 200
        active: stage.panelSelected && stage.active
        handlesEnabled: true
        aspectLocked: false
        rot90: false
        unit: stage.unit
        coordinateItem: stage

        onResizeStarted: (ex, ey) => {
            stage.resizeStartL = stage.panelLeft;
            stage.resizeStartT = stage.panelTop;
            stage.resizeStartW = panel.width;
            stage.resizeStartH = panel.height;
        }

        onResizeMoved: (ex, ey, dx, dy, modifiers) => {
            stage.resizePanel(ex, ey, dx, dy);
        }
    }
}
