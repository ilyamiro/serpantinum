import QtQuick
import Quickshell
import "../"
import "PetArt.js" as Art

// Bar module: the pet's bed. Registered at runtime by Pet.qml (BarModuleRegistry.registerModule).
Item {
    id: root

    property var module: null

    readonly property bool isVertical: module ? !!module.isVertical : false
    function s(v) {
        return (module && typeof module.s === "function") ? module.s(v) : v;
    }

    readonly property var barWindow: module ? module.barWindow : null
    readonly property var barScreen: barWindow ? barWindow.screen : null
    readonly property string screenName: barScreen ? barScreen.name : ""
    readonly property bool isUsable: visible && width > 0 && height > 0 && barWindow !== null

    readonly property bool petOn: PetState.enabled
    readonly property bool home: PetState.loaded && !PetState.out
    readonly property bool showCat: petOn && home
    readonly property int treats: petOn ? PetState.treats : 0

    readonly property real thick: isVertical ? width : height
    readonly property int px: Math.max(1, Math.min(3, Math.floor((thick > 0 ? thick : s(40)) / Art.BED_H)))
    readonly property real pad: s(6)

    implicitWidth: isVertical ? thick : Math.round(pad + bed.width + (treats > 0 ? s(4) + badge.width : 0) + pad)
    implicitHeight: isVertical ? Math.round(pad + bed.height + (treats > 0 ? s(2) + badge.height : 0) + pad) : thick

    readonly property var fishSc: Art.fishScene()
    property var bedSc: Art.bedScene({ home: false })

    property int frame: 0
    property int ticks: 0
    property var parts: []
    property bool zAlt: false
    property real nextZ: 0
    property string faceOverride: ""
    property real faceUntil: 0
    property real plop: 1.0
    property real badgePop: 1.0

    function rebuild() {
        let now = Date.now();
        let face = (faceOverride !== "" && now < faceUntil) ? faceOverride : (ma.containsMouse ? "tired" : "sleep");
        let fx = [];
        for (let i = 0; i < parts.length; i++) fx.push({ g: parts[i].g, dx: Math.round(parts[i].dx), dy: Math.round(parts[i].dy) });
        bedSc = Art.bedScene({ home: root.showCat, frame: root.frame, face: face, fx: fx });
    }

    function step() {
        let now = Date.now();
        ticks++;
        if (ticks % 3 === 0) frame = (frame + 1) % 2;
        if (now >= nextZ && now >= faceUntil) {
            let list = parts.slice();
            list.push({ g: zAlt ? "z2" : "z1", dx: 8, dy: 5, vx: 0.8, vy: -0.9, born: now, life: 2300 });
            parts = list;
            zAlt = !zAlt;
            nextZ = now + 1700;
        }
        let keep = [];
        for (let i = 0; i < parts.length; i++) {
            let p = parts[i];
            if (now - p.born > p.life) continue;
            p.dx += p.vx;
            p.dy += p.vy;
            keep.push(p);
        }
        parts = keep;
        rebuild();
    }

    function addHeart() {
        let list = parts.slice();
        list.push({ g: "heart", dx: -5 + Math.random() * 10, dy: 4, vx: 0, vy: -1.2, born: Date.now(), life: 1300 });
        while (list.length > 6) list.shift();
        parts = list;
    }

    function petInBed() {
        if (!showCat) return;
        faceOverride = "love";
        faceUntil = Date.now() + 1200;
        addHeart();
        rebuild();
        PetState.sfx("purr", 0.6, 1500);
        PetState.nudgeHappiness(0.004);
    }

    function windowOrigin() {
        let w = barWindow;
        if (!w) return { x: 0, y: 0 };
        let sw = w.screen ? w.screen.width : 1920;
        let sh = w.screen ? w.screen.height : 1080;
        let a = w.anchors, m = w.margins;
        let x = (a && a.left) ? m.left : ((a && a.right) ? sw - w.width - m.right : (sw - w.width) / 2);
        let y = (a && a.top) ? m.top : ((a && a.bottom) ? sh - w.height - m.bottom : (sh - w.height) / 2);
        return { x: x, y: y };
    }

    function screenRect() {
        let p = root.mapToItem(null, 0, 0);
        let o = windowOrigin();
        return Qt.rect(p.x + o.x, p.y + o.y, root.width, root.height);
    }

    function openMenu() {
        menuLoader.active = true;
    }

    function toggleMenu() {
        menuLoader.active = !menuLoader.active;
    }

    LazyLoader {
        id: menuLoader
        active: false

        PetMenu {
            bed: root
            onClosed: Qt.callLater(() => { menuLoader.active = false; })
        }
    }

    function toScreen(x, y) {
        let p = ma.mapToItem(null, x, y);
        let o = windowOrigin();
        return Qt.point(p.x + o.x, p.y + o.y);
    }

    // where the cat sits in the bed, in screen coordinates (used to aim the jump)
    function seatPoint() {
        let p = bed.mapToItem(null, Art.BED_SEAT.x * px, Art.BED_SEAT.y * px);
        let o = windowOrigin();
        return Qt.point(p.x + o.x, p.y + o.y);
    }

    function onBadge(x, y) {
        if (!badge.visible) return false;
        let p = badge.mapToItem(root, 0, 0);
        let m = s(4);
        return x >= p.x - m && x <= p.x + badge.width + m && y >= p.y - m && y <= p.y + badge.height + m;
    }

    Timer {
        id: anim
        interval: 420
        repeat: true
        running: root.visible && root.showCat
        onTriggered: root.step()
    }

    onShowCatChanged: {
        parts = [];
        rebuild();
    }

    SequentialAnimation {
        id: plopAnim
        NumberAnimation { target: root; property: "plop"; to: 0.75; duration: 80; easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "plop"; to: 1.0; duration: 260; easing.type: Easing.OutBack }
    }

    SequentialAnimation {
        id: badgeAnim
        NumberAnimation { target: root; property: "badgePop"; to: 1.35; duration: 120; easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "badgePop"; to: 1.0; duration: 300; easing.type: Easing.OutBack }
    }

    Connections {
        target: PetState
        function onBedArrived() { plopAnim.restart(); }
        function onTreatsEarned(count, reason) {
            badgeAnim.restart();
            if (root.showCat) {
                root.faceOverride = "up";
                root.faceUntil = Date.now() + 1500;
                root.rebuild();
            }
        }
    }

    PetSprite {
        id: bed
        px: root.px
        colors: PetState.colors
        scene: root.bedSc
        opacity: root.petOn ? 1.0 : 0.45
        x: root.isVertical ? Math.round((root.width - width) / 2) : Math.round(root.pad)
        y: root.isVertical ? Math.round(root.pad) : Math.round((root.height - height) / 2)
        transform: Scale {
            origin.x: bed.width / 2
            origin.y: bed.height
            xScale: 2.0 - root.plop
            yScale: root.plop
        }
    }

    Row {
        id: badge
        visible: root.treats > 0
        spacing: root.s(3)
        x: root.isVertical ? Math.round((root.width - width) / 2) : Math.round(bed.x + bed.width + root.s(4))
        y: root.isVertical ? Math.round(bed.y + bed.height + root.s(2)) : Math.round((root.height - height) / 2)
        scale: root.badgePop

        PetSprite {
            px: Math.max(1, root.px)
            colors: PetState.colors
            scene: root.fishSc
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: root.treats
            color: ThemeBackend.text
            font.family: ThemeBackend.fontFamily
            font.pixelSize: root.s(12)
            font.bold: true
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        property bool fromBadge: false
        property bool dragging: false
        property real sx0: 0
        property real sy0: 0

        onContainsMouseChanged: root.rebuild()

        onPressed: (m) => {
            fromBadge = root.petOn && m.button === Qt.LeftButton && root.treats > 0 && root.onBadge(m.x, m.y);
            dragging = false;
            sx0 = m.x;
            sy0 = m.y;
        }

        onPositionChanged: (m) => {
            if (!pressed || !fromBadge) return;
            if (!dragging) {
                if (Math.hypot(m.x - sx0, m.y - sy0) < 5) return;
                dragging = true;
                let p0 = root.toScreen(m.x, m.y);
                PetState.treatDrag("start", p0.x, p0.y, root);
                return;
            }
            let p = root.toScreen(m.x, m.y);
            PetState.treatDrag("move", p.x, p.y, root);
        }

        onReleased: (m) => {
            if (dragging) {
                dragging = false;
                let p = root.toScreen(m.x, m.y);
                PetState.treatDrag("end", p.x, p.y, root);
                return;
            }
            if (m.button === Qt.RightButton) {
                root.openMenu();
                return;
            }
            if (!root.petOn) {
                PetState.powerRequested(true);
                return;
            }
            if (fromBadge) {
                PetState.requestTreatDrop(root);
                return;
            }
            PetState.toggleFromBed(root);
        }

        onCanceled: {
            if (dragging) {
                dragging = false;
                PetState.treatDrag("cancel", 0, 0, root);
            }
        }

        onWheel: (w) => root.petInBed()
    }

    Component.onCompleted: {
        PetState.registerBed(root);
        rebuild();
    }

    Component.onDestruction: PetState.unregisterBed(root)
}
