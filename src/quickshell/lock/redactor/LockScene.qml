import QtQuick
import Quickshell
import "../../"
import "../../widgets"

Item {
    id: scene

    property string scope: "screen"
    property real k: 0.5
    property bool active: false
    property bool gridEnabled: false
    property string selectedId: ""
    property Item selectedProxy: null
    property real guideX: -1
    property real guideY: -1
    property bool dragging: false
    property bool handleBlank: true

    signal imagePickRequested(string itemId, string currentPath, bool rounded)
    signal blankClicked()

    readonly property var itemsModel: LockLayoutStore.modelFor(scene.scope)
    readonly property real gridStep: Scaler.s(20)
    readonly property real unit: 1 / Math.max(scene.k, 0.05)
    readonly property var selectedWidget: scene.selectedProxy ? scene.selectedProxy.faceItem : null
    readonly property var currentWidget: scene.selectedWidget
    readonly property var activeWidget: scene.selectedWidget

    function indexOfId(id) {
        let m = scene.itemsModel;
        for (let i = 0; i < m.count; i++) {
            if (m.get(i).iid === id) return i;
        }
        return -1;
    }

    function proxyAt(index) {
        return itemRepeater.itemAt(index);
    }

    function snapAllToGrid() {
        for (let i = 0; i < itemRepeater.count; i++) {
            let p = itemRepeater.itemAt(i);
            if (!p || p.rot90) continue;
            let g = scene.gridStep;
            let L = Math.max(0, Math.min(scene.width, Math.round(p.x / g) * g));
            let T = Math.max(0, Math.min(scene.height, Math.round(p.y / g) * g));
            let R = Math.max(0, Math.min(scene.width, Math.round((p.x + p.width) / g) * g));
            let B = Math.max(0, Math.min(scene.height, Math.round((p.y + p.height) / g) * g));
            if (R <= L) R = L + g;
            if (B <= T) B = T + g;
            let c = scene.clampResize(scene.constraints(p), R - L, B - T, 0, 0, true);
            scene.itemsModel.setProperty(i, "ix", Math.max(0, Math.min(Math.max(0, scene.width - c.w), L)));
            scene.itemsModel.setProperty(i, "iy", Math.max(0, Math.min(Math.max(0, scene.height - c.h), T)));
            scene.itemsModel.setProperty(i, "iw", c.w);
            scene.itemsModel.setProperty(i, "ih", c.h);
        }
        LockLayoutStore.touch();
    }

    function removeItem(id) {
        if (scene.selectedId === id) scene.selectedId = "";
        LockLayoutStore.removeItem(id);
    }

    function removeSelected() {
        if (scene.selectedId === "") return;
        let i = scene.indexOfId(scene.selectedId);
        if (i < 0 || !LockElementRegistry.isDeletable(scene.itemsModel.get(i).itype)) return;
        scene.removeItem(scene.selectedId);
    }

    function setWidgetProperty(propName, val, targetId) {
        let tid = targetId || scene.selectedId;
        let i = scene.indexOfId(tid);
        if (i < 0) return;
        scene.itemsModel.setProperty(i, propName, val);
        let proxy = itemRepeater.itemAt(i);
        if (proxy && proxy.faceItem) {
            try {
                if (proxy.faceItem[propName] !== undefined) proxy.faceItem[propName] = val;
            } catch (e) {}
        }
        LockLayoutStore.touch();
    }

    function updateWidgetProperty(target, propName, val) {
        scene.setWidgetProperty(propName, val, target && target.iid ? target.iid : scene.selectedId);
    }

    function handleAdditionalAction(action, proxy, extraArg) {
        if (action === "pickImage") {
            scene.imagePickRequested(proxy.pId, proxy.pImage, proxy.pVariant === "round");
        } else if (action === "stretchWidth") {
            let i = proxy.pIndex;
            if (proxy.rot90) {
                scene.itemsModel.setProperty(i, "iy", 0);
                scene.itemsModel.setProperty(i, "iw", scene.height);
            } else {
                scene.itemsModel.setProperty(i, "ix", 0);
                scene.itemsModel.setProperty(i, "iw", scene.width);
            }
            proxy.finalizeSync();
        } else if (extraArg !== undefined) {
            scene.setWidgetProperty(action, extraArg, proxy.pId);
        }
    }

    function resolveThemeColor(colorName) {
        if (colorName === "mauve") return ThemeBackend.mauve;
        if (colorName === "surface0") return ThemeBackend.surface0;
        if (colorName === "surface1") return ThemeBackend.surface1;
        if (colorName === "crust") return ThemeBackend.crust;
        if (colorName === "base") return ThemeBackend.base;
        if (colorName === "red") return ThemeBackend.red;
        return ThemeBackend.text;
    }

    function constraints(proxy) {
        let lim = LockElementRegistry.limits(proxy.pType);
        if (lim) {
            return {
                minW: lim.minW, minH: lim.minH, maxW: lim.maxW, maxH: lim.maxH,
                minA: lim.aspect > 0 ? lim.aspect : 0,
                maxA: lim.aspect > 0 ? lim.aspect : 9999
            };
        }
        if (proxy.scaled) {
            let a = proxy.refH > 0 ? proxy.refW / proxy.refH : 1;
            return { minW: proxy.refW * 0.3, minH: proxy.refH * 0.3, maxW: proxy.refW * 3, maxH: proxy.refH * 3, minA: a, maxA: a };
        }
        let f = proxy.faceItem;
        if (!f) return null;
        return {
            minW: f.minWidth !== undefined ? f.minWidth : 10,
            minH: f.minHeight !== undefined ? f.minHeight : 10,
            maxW: f.maxWidth !== undefined ? f.maxWidth : 9999,
            maxH: f.maxHeight !== undefined ? f.maxHeight : 9999,
            minA: f.minAspect !== undefined ? f.minAspect : 0,
            maxA: f.maxAspect !== undefined ? f.maxAspect : 9999
        };
    }

    function clampResize(c, rawW, rawH, dx, dy, isCorner) {
        if (!c) return { w: rawW, h: rawH };

        let w = Math.max(c.minW, Math.min(c.maxW, rawW));
        let h = Math.max(c.minH, Math.min(c.maxH, rawH));

        let hasMinA = c.minA !== undefined && c.minA > 0;
        let hasMaxA = c.maxA !== undefined && c.maxA > 0 && c.maxA < 9999;

        if (!isCorner) {
            if (dx !== 0) {
                let effMinW = Math.max(c.minW, hasMinA ? h * c.minA : c.minW);
                let effMaxW = Math.min(c.maxW, hasMaxA ? h * c.maxA : c.maxW);
                w = effMinW <= effMaxW ? Math.max(effMinW, Math.min(effMaxW, w)) : Math.max(c.minW, Math.min(c.maxW, w));
            } else {
                let effMinH = Math.max(c.minH, hasMaxA ? w / c.maxA : c.minH);
                let effMaxH = Math.min(c.maxH, hasMinA ? w / c.minA : c.maxH);
                h = effMinH <= effMaxH ? Math.max(effMinH, Math.min(effMaxH, h)) : Math.max(c.minH, Math.min(c.maxH, h));
            }
            return { w: w, h: h };
        }

        let ratio = w / h;
        let mA = 0;
        if (hasMinA && ratio < c.minA) mA = c.minA;
        else if (hasMaxA && ratio > c.maxA) mA = c.maxA;
        if (mA > 0) {
            let hProj = (w * mA + h) / (mA * mA + 1);
            let hMin = Math.max(c.minH, c.minW / mA);
            let hMax = Math.min(c.maxH, c.maxW / mA);
            h = Math.max(hMin, Math.min(hMax, hProj));
            w = h * mA;
        }

        return { w: Math.max(c.minW, Math.min(c.maxW, w)), h: Math.max(c.minH, Math.min(c.maxH, h)) };
    }

    function calculateSnap(dragged, rawX, rawY) {
        let threshold = 12 * scene.unit;
        let res = { x: rawX, y: rawY, guideX: -1, guideY: -1 };

        if (scene.gridEnabled) {
            res.x = Math.round(rawX / scene.gridStep) * scene.gridStep;
            res.y = Math.round(rawY / scene.gridStep) * scene.gridStep;
        } else {
            let bestDx = threshold;
            let bestDy = threshold;
            let dX = [rawX, rawX + dragged.width / 2.0, rawX + dragged.width];
            let dY = [rawY, rawY + dragged.height / 2.0, rawY + dragged.height];
            let targetsX = [scene.width / 2.0];
            let targetsY = [scene.height / 2.0];

            for (let i = 0; i < itemRepeater.count; i++) {
                let o = itemRepeater.itemAt(i);
                if (!o || o === dragged) continue;
                targetsX.push(o.x, o.x + o.width / 2.0, o.x + o.width);
                targetsY.push(o.y, o.y + o.height / 2.0, o.y + o.height);
            }

            for (let j = 0; j < dX.length; j++) {
                for (let t = 0; t < targetsX.length; t++) {
                    let diff = Math.abs(dX[j] - targetsX[t]);
                    if (diff < bestDx) {
                        bestDx = diff;
                        res.x = rawX + (targetsX[t] - dX[j]);
                        res.guideX = targetsX[t];
                    }
                }
                for (let t = 0; t < targetsY.length; t++) {
                    let diff = Math.abs(dY[j] - targetsY[t]);
                    if (diff < bestDy) {
                        bestDy = diff;
                        res.y = rawY + (targetsY[t] - dY[j]);
                        res.guideY = targetsY[t];
                    }
                }
            }
        }

        res.x = Math.max(0, Math.min(Math.max(0, scene.width - dragged.width), res.x));
        res.y = Math.max(0, Math.min(Math.max(0, scene.height - dragged.height), res.y));
        return res;
    }

    function calculateResize(c, startW, startH, dx, dy, edges, isCorner, rot) {
        let rawW = startW;
        let rawH = startH;

        if (edges.left) rawW = startW - dx;
        else if (edges.right) rawW = startW + dx;
        if (edges.top) rawH = startH - dy;
        else if (edges.bottom) rawH = startH + dy;

        if (scene.gridEnabled) {
            if (edges.left || edges.right) rawW = Math.round(rawW / scene.gridStep) * scene.gridStep;
            if (edges.top || edges.bottom) rawH = Math.round(rawH / scene.gridStep) * scene.gridStep;
        }

        let normRot = ((Math.round(rot || 0) % 360) + 360) % 360;
        let isRot90 = normRot % 180 !== 0;
        let maxW = isRot90 ? scene.height : scene.width;
        let maxH = isRot90 ? scene.width : scene.height;

        rawW = Math.max(10, Math.min(maxW, rawW));
        rawH = Math.max(10, Math.min(maxH, rawH));

        let clamped = scene.clampResize(c, rawW, rawH, dx, dy, isCorner);
        return { w: Math.max(10, Math.min(maxW, clamped.w)), h: Math.max(10, Math.min(maxH, clamped.h)) };
    }

    MouseArea {
        anchors.fill: parent
        z: -3
        enabled: scene.handleBlank
        onClicked: {
            scene.selectedId = "";
            scene.blankClicked();
        }
    }

    Item {
        anchors.fill: parent
        z: -2
        visible: scene.gridEnabled

        Repeater {
            model: scene.gridEnabled ? Math.ceil(scene.width / scene.gridStep) + 1 : 0

            Rectangle {
                x: index * scene.gridStep
                width: scene.unit
                height: scene.height
                color: Qt.rgba(ThemeBackend.text.r, ThemeBackend.text.g, ThemeBackend.text.b, 0.14)
            }
        }

        Repeater {
            model: scene.gridEnabled ? Math.ceil(scene.height / scene.gridStep) + 1 : 0

            Rectangle {
                y: index * scene.gridStep
                width: scene.width
                height: scene.unit
                color: Qt.rgba(ThemeBackend.text.r, ThemeBackend.text.g, ThemeBackend.text.b, 0.14)
            }
        }
    }

    Rectangle {
        x: scene.guideX
        width: scene.unit
        height: scene.height
        color: ThemeBackend.mauve
        visible: scene.guideX >= 0
        z: 100000
    }

    Rectangle {
        y: scene.guideY
        width: scene.width
        height: scene.unit
        color: ThemeBackend.mauve
        visible: scene.guideY >= 0
        z: 100000
    }

    Repeater {
        id: itemRepeater
        model: scene.itemsModel

        delegate: Item {
            id: proxy

            readonly property string pId: model.iid
            readonly property string pType: model.itype
            readonly property string pVariant: model.ivariant
            readonly property string pImage: model.iimage
            readonly property bool pShowText: model.showText ?? true
            readonly property real pRotation: model.irotation ?? 0
            readonly property real pOpacity: model.iopacity ?? 1
            readonly property real gX: model.ix ?? 0
            readonly property real gY: model.iy ?? 0
            readonly property real gW: model.iw ?? 0
            readonly property real gH: model.ih ?? 0
            readonly property int pIndex: index
            readonly property bool isSelected: scene.selectedId === proxy.pId
            readonly property bool rot90: Math.abs(Math.round(proxy.pRotation)) % 180 !== 0
            readonly property bool scaled: LockElementRegistry.isScaled(proxy.pType)
            readonly property bool deletable: LockElementRegistry.isDeletable(proxy.pType)
            readonly property Item faceItem: faceLoader.item
            readonly property real faceIW: faceLoader.item ? faceLoader.item.implicitWidth : 0
            readonly property real faceIH: faceLoader.item ? faceLoader.item.implicitHeight : 0
            readonly property bool aspectLocked: {
                let lim = LockElementRegistry.limits(proxy.pType);
                if (lim) return lim.aspect > 0;
                if (proxy.scaled) return true;
                let f = proxy.faceItem;
                return !!f && f.minAspect !== undefined && f.maxAspect !== undefined && f.minAspect === f.maxAspect && f.minAspect > 0;
            }
            property real refW: 0
            property real refH: 0
            property real scaleMem: 1
            property bool needsRef: true
            property bool variantSwitch: false
            property bool hasUnsynced: false
            property var savedAspects: ({})

            x: proxy.gX
            y: proxy.gY
            width: proxy.rot90 ? proxy.gH : proxy.gW
            height: proxy.rot90 ? proxy.gW : proxy.gH
            z: (proxy.isSelected ? 50000 : 0) + index
            opacity: (scene.selectedId === "" || proxy.isSelected) ? 1.0 : 0.6
            Behavior on opacity { NumberAnimation { duration: 150 } }

            onIsSelectedChanged: {
                if (proxy.isSelected) {
                    scene.selectedProxy = proxy;
                } else if (scene.selectedProxy === proxy) {
                    scene.selectedProxy = null;
                }
            }

            Component.onCompleted: {
                if (proxy.isSelected) scene.selectedProxy = proxy;
            }

            onFaceIWChanged: proxy.settleScaled()
            onFaceIHChanged: proxy.settleScaled()

            function settleScaled() {
                if (!proxy.scaled || !proxy.needsRef || proxy.faceIW <= 0 || proxy.faceIH <= 0) return;
                proxy.needsRef = false;
                proxy.refW = proxy.faceIW;
                proxy.refH = proxy.faceIH;
                if (model.iw <= 0 || model.ih <= 0) {
                    model.ix = model.ix - proxy.refW / 2;
                    model.iy = model.iy - proxy.refH / 2;
                    model.iw = proxy.refW;
                    model.ih = proxy.refH;
                    proxy.scaleMem = 1;
                    proxy.finalizeSync();
                } else if (proxy.variantSwitch) {
                    model.iw = proxy.refW * proxy.scaleMem;
                    model.ih = proxy.refH * proxy.scaleMem;
                    proxy.variantSwitch = false;
                    proxy.finalizeSync();
                } else {
                    proxy.scaleMem = model.iw / proxy.refW;
                }
            }

            function bringToFront() {
                let last = scene.itemsModel.count - 1;
                if (proxy.pIndex < last) scene.itemsModel.move(proxy.pIndex, last, 1);
            }

            function triggerSync() {
                proxy.hasUnsynced = true;
                if (!syncTimer.running) syncTimer.restart();
            }

            function finalizeSync() {
                syncTimer.stop();
                proxy.hasUnsynced = false;
                if (proxy.scaled && proxy.refW > 0) proxy.scaleMem = model.iw / proxy.refW;
                LockLayoutStore.touch();
            }

            Timer {
                id: syncTimer
                interval: 100
                repeat: true
                onTriggered: {
                    if (!proxy.hasUnsynced) {
                        running = false;
                        return;
                    }
                    proxy.hasUnsynced = false;
                    LockLayoutStore.touch();
                }
            }

            function getDefaultSize() {
                if (proxy.scaled) return { w: proxy.refW, h: proxy.refH };
                let def = LockElementRegistry.defaultSize(proxy.pType);
                let f = proxy.faceItem;
                if (f && f.minAspect !== undefined && f.maxAspect !== undefined && f.minAspect === f.maxAspect && f.minAspect > 0) {
                    if (f.minAspect === 1.0) return { w: 180, h: 180 };
                    return { w: Math.round(120 * f.minAspect), h: 120 };
                }
                return def;
            }

            function applyVariant(variantId) {
                if (proxy.pVariant === variantId) return;
                if (proxy.scaled) {
                    proxy.scaleMem = proxy.refW > 0 ? model.iw / proxy.refW : 1;
                    proxy.variantSwitch = true;
                    proxy.needsRef = true;
                } else {
                    proxy.savedAspects[proxy.pVariant] = model.iw / model.ih;
                    let target = proxy.savedAspects[variantId];
                    if (target) {
                        let area = model.iw * model.ih;
                        let newH = Math.max(10, Math.sqrt(area / target));
                        model.iw = Math.max(10, newH * target);
                        model.ih = newH;
                    }
                }
                model.ivariant = variantId;
                proxy.finalizeSync();
            }

            function setOpacity(value) {
                model.iopacity = value;
                proxy.triggerSync();
            }

            function rotateItem() {
                let curRot = Math.abs(Math.round(proxy.pRotation || 0)) % 360;
                let nextRot = curRot + 90;

                let curBW = (curRot % 180 === 0) ? model.iw : model.ih;
                let curBH = (curRot % 180 === 0) ? model.ih : model.iw;
                let cx = model.ix + curBW / 2.0;
                let cy = model.iy + curBH / 2.0;

                let nextBW = (nextRot % 180 === 0) ? model.iw : model.ih;
                let nextBH = (nextRot % 180 === 0) ? model.ih : model.iw;

                let maxBW = Math.max(20, 2.0 * Math.min(cx, scene.width - cx));
                let maxBH = Math.max(20, 2.0 * Math.min(cy, scene.height - cy));
                let factor = Math.min(1.0, nextBW > maxBW ? maxBW / nextBW : 1.0, nextBH > maxBH ? maxBH / nextBH : 1.0);

                let c = scene.constraints(proxy);
                let clamped = scene.clampResize(c, model.iw * factor, model.ih * factor, 0, 0, true);
                let outBW = (nextRot % 180 === 0) ? clamped.w : clamped.h;
                let outBH = (nextRot % 180 === 0) ? clamped.h : clamped.w;

                model.iw = clamped.w;
                model.ih = clamped.h;
                model.irotation = nextRot;
                model.ix = Math.max(0, Math.min(Math.max(0, scene.width - outBW), cx - outBW / 2.0));
                model.iy = Math.max(0, Math.min(Math.max(0, scene.height - outBH), cy - outBH / 2.0));
                proxy.finalizeSync();
            }

            function resetItemSize() {
                let curRot = Math.abs(Math.round(proxy.pRotation || 0)) % 360;
                let curBW = (curRot % 180 === 0) ? model.iw : model.ih;
                let curBH = (curRot % 180 === 0) ? model.ih : model.iw;
                let cx = model.ix + curBW / 2.0;
                let cy = model.iy + curBH / 2.0;

                let def = proxy.getDefaultSize();
                let clamped = scene.clampResize(scene.constraints(proxy), def.w, def.h, 0, 0, true);

                model.iopacity = 1.0;
                model.irotation = 0;
                model.iw = clamped.w;
                model.ih = clamped.h;
                model.ix = Math.max(0, Math.min(Math.max(0, scene.width - clamped.w), cx - clamped.w / 2.0));
                model.iy = Math.max(0, Math.min(Math.max(0, scene.height - clamped.h), cy - clamped.h / 2.0));
                proxy.finalizeSync();
            }

            function applyResize(mouse, startMX, startMY, startW, startH, startX, startY, area, edges, isCorner) {
                let local = area.mapToItem(scene, mouse.x, mouse.y);
                let dx = local.x - startMX;
                let dy = local.y - startMY;

                let rot = proxy.pRotation || 0;
                let rad = rot * Math.PI / 180.0;
                let cos = Math.cos(rad);
                let sin = Math.sin(rad);

                let ldx = dx * cos + dy * sin;
                let ldy = -dx * sin + dy * cos;

                let passDx = isCorner ? ldx : (edges.left || edges.right ? ldx : 0);
                let passDy = isCorner ? ldy : (edges.top || edges.bottom ? ldy : 0);

                let res = scene.calculateResize(scene.constraints(proxy), startW, startH, passDx, passDy, edges, isCorner, rot);

                let pxFixed = edges.left ? startW / 2.0 : (edges.right ? -startW / 2.0 : 0);
                let pyFixed = edges.top ? startH / 2.0 : (edges.bottom ? -startH / 2.0 : 0);
                let pxNew = edges.left ? res.w / 2.0 : (edges.right ? -res.w / 2.0 : 0);
                let pyNew = edges.top ? res.h / 2.0 : (edges.bottom ? -res.h / 2.0 : 0);

                let is180 = Math.abs(Math.round(rot)) % 180 === 0;
                let curBW = is180 ? startW : startH;
                let curBH = is180 ? startH : startW;
                let startCX = startX + curBW / 2.0;
                let startCY = startY + curBH / 2.0;

                let fixedX = startCX + pxFixed * cos - pyFixed * sin;
                let fixedY = startCY + pxFixed * sin + pyFixed * cos;
                let newCX = fixedX - (pxNew * cos - pyNew * sin);
                let newCY = fixedY - (pxNew * sin + pyNew * cos);

                let nextBW = is180 ? res.w : res.h;
                let nextBH = is180 ? res.h : res.w;
                let newX = Math.max(0, Math.min(Math.max(0, scene.width - nextBW), newCX - nextBW / 2.0));
                let newY = Math.max(0, Math.min(Math.max(0, scene.height - nextBH), newCY - nextBH / 2.0));

                if (scene.gridEnabled) {
                    newX = Math.max(0, Math.min(Math.max(0, scene.width - nextBW), Math.round(newX / scene.gridStep) * scene.gridStep));
                    newY = Math.max(0, Math.min(Math.max(0, scene.height - nextBH), Math.round(newY / scene.gridStep) * scene.gridStep));
                }

                model.iw = res.w;
                model.ih = res.h;
                model.ix = newX;
                model.iy = newY;
                proxy.triggerSync();
            }

            MouseArea {
                id: dragMa
                z: 2
                anchors.fill: parent
                hoverEnabled: true
                preventStealing: true
                cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor

                property real startX
                property real startY
                property real startItemX
                property real startItemY

                onPressed: (mouse) => {
                    scene.dragging = true;
                    scene.selectedId = proxy.pId;
                    proxy.bringToFront();
                    let p = mapToItem(scene, mouse.x, mouse.y);
                    startX = p.x;
                    startY = p.y;
                    startItemX = proxy.x;
                    startItemY = proxy.y;
                }

                onPositionChanged: (mouse) => {
                    if (!pressed) return;
                    let p = mapToItem(scene, mouse.x, mouse.y);
                    let snap = scene.calculateSnap(proxy, startItemX + p.x - startX, startItemY + p.y - startY);
                    model.ix = snap.x;
                    model.iy = snap.y;
                    scene.guideX = snap.guideX;
                    scene.guideY = snap.guideY;
                    proxy.triggerSync();
                }

                onReleased: {
                    scene.dragging = false;
                    scene.guideX = -1;
                    scene.guideY = -1;
                    proxy.finalizeSync();
                }

                onCanceled: {
                    scene.dragging = false;
                    scene.guideX = -1;
                    scene.guideY = -1;
                    proxy.finalizeSync();
                }
            }

            Item {
                id: rotatable
                z: 1
                width: proxy.gW
                height: proxy.gH
                anchors.centerIn: parent
                rotation: proxy.pRotation

                Loader {
                    id: faceLoader
                    readonly property real factor: proxy.scaled && proxy.refW > 0 ? rotatable.width / proxy.refW : 1
                    width: proxy.scaled && proxy.refW > 0 ? proxy.refW : rotatable.width
                    height: proxy.scaled && proxy.refH > 0 ? proxy.refH : rotatable.height
                    scale: faceLoader.factor
                    transformOrigin: Item.TopLeft
                    opacity: proxy.isSelected ? Math.max(0.35, proxy.pOpacity) : proxy.pOpacity
                    source: LockElementRegistry.faceSource(proxy.pType, proxy.pVariant)

                    onLoaded: {
                        if (!item) return;
                        proxy.needsRef = true;
                        if (LockElementRegistry.isWidget(proxy.pType)) {
                            try {
                                if (item.imagePath !== undefined) item.imagePath = Qt.binding(() => proxy.pImage);
                                if (item.wImagePath !== undefined) item.wImagePath = Qt.binding(() => proxy.pImage);
                                if (item.path !== undefined) item.path = Qt.binding(() => proxy.pImage);
                                if (item.source !== undefined && typeof item.source === "string") item.source = Qt.binding(() => proxy.pImage);
                            } catch (e) {}
                            let row = scene.itemsModel.get(proxy.pIndex);
                            if (row) {
                                let ignored = ["objectName", "destroyed", "deleteLater", "parent", "data", "resources", "children", "visible", "enabled", "x", "y", "z", "width", "height", "opacity", "rotation", "scale"];
                                for (let key in row) {
                                    if (!key || typeof key !== "string") continue;
                                    if (key.endsWith("Changed") || key.startsWith("on") || typeof row[key] === "function" || row[key] === undefined) continue;
                                    if (ignored.includes(key) || LockLayoutStore.standardKeys.includes(key)) continue;
                                    try {
                                        if (item[key] !== undefined && item[key] !== row[key]) item[key] = row[key];
                                    } catch (e) {}
                                }
                            }
                            if (model.iw > 0 && model.ih > 0) {
                                let res = scene.clampResize(scene.constraints(proxy), model.iw, model.ih, 0, 0, true);
                                if (res.w !== model.iw || res.h !== model.ih) {
                                    model.iw = res.w;
                                    model.ih = res.h;
                                    proxy.triggerSync();
                                }
                            }
                        } else {
                            if (item.variant !== undefined) item.variant = Qt.binding(() => proxy.pVariant);
                            if (item.showText !== undefined) item.showText = Qt.binding(() => proxy.pShowText);
                        }
                        proxy.settleScaled();
                    }
                }
            }

            Item {
                id: handleLayer
                z: 3
                width: proxy.gW
                height: proxy.gH
                anchors.centerIn: parent
                rotation: proxy.pRotation

                Item {
                    id: selectionUI
                    z: 30
                    anchors.fill: parent
                    anchors.margins: -Scaler.s(8)
                    opacity: proxy.isSelected && scene.active ? 1.0 : 0.0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: 150 } }

                    SelectionOutline {
                        anchors.fill: parent
                        running: selectionUI.visible
                        lineWidth: 2 * scene.unit
                    }

                    Repeater {
                        model: [
                            { ex: -1, ey: -1 }, { ex: 1, ey: -1 }, { ex: -1, ey: 1 }, { ex: 1, ey: 1 },
                            { ex: 0, ey: -1 }, { ex: 0, ey: 1 }, { ex: -1, ey: 0 }, { ex: 1, ey: 0 }
                        ]

                        delegate: MouseArea {
                            id: hit

                            readonly property int ex: modelData ? modelData.ex : 0
                            readonly property int ey: modelData ? modelData.ey : 0
                            readonly property bool corner: hit.ex !== 0 && hit.ey !== 0
                            readonly property real u: scene.unit
                            readonly property real insetX: Math.max(0, Math.min(18 * hit.u, (selectionUI.width - 8 * hit.u) / 2))
                            readonly property real insetY: Math.max(0, Math.min(18 * hit.u, (selectionUI.height - 8 * hit.u) / 2))

                            property real startMX
                            property real startMY
                            property real startW
                            property real startH
                            property real startItemX
                            property real startItemY

                            visible: hit.corner || !proxy.aspectLocked
                            enabled: hit.visible && proxy.isSelected && faceLoader.status === Loader.Ready
                            z: 20
                            width: hit.corner ? 24 * hit.u : (hit.ex === 0 ? selectionUI.width - 2 * hit.insetX : 16 * hit.u)
                            height: hit.corner ? 24 * hit.u : (hit.ey === 0 ? selectionUI.height - 2 * hit.insetY : 16 * hit.u)
                            x: hit.ex < 0 ? -hit.width / 2 : (hit.ex > 0 ? selectionUI.width - hit.width / 2 : hit.insetX)
                            y: hit.ey < 0 ? -hit.height / 2 : (hit.ey > 0 ? selectionUI.height - hit.height / 2 : hit.insetY)
                            hoverEnabled: true
                            preventStealing: true
                            cursorShape: {
                                if (hit.corner) {
                                    let diag = hit.ex === hit.ey;
                                    return (diag !== proxy.rot90) ? Qt.SizeFDiagCursor : Qt.SizeBDiagCursor;
                                }
                                let vertical = hit.ey !== 0;
                                return (vertical !== proxy.rot90) ? Qt.SizeVerCursor : Qt.SizeHorCursor;
                            }

                            onPressed: (mouse) => {
                                scene.dragging = true;
                                proxy.bringToFront();
                                let p = mapToItem(scene, mouse.x, mouse.y);
                                startMX = p.x;
                                startMY = p.y;
                                startW = proxy.gW;
                                startH = proxy.gH;
                                startItemX = proxy.gX;
                                startItemY = proxy.gY;
                            }

                            onPositionChanged: (mouse) => {
                                if (!pressed) return;
                                proxy.applyResize(mouse, startMX, startMY, startW, startH, startItemX, startItemY, hit,
                                    { left: hit.ex < 0, right: hit.ex > 0, top: hit.ey < 0, bottom: hit.ey > 0 }, hit.corner);
                            }

                            onReleased: {
                                scene.dragging = false;
                                proxy.finalizeSync();
                            }

                            onCanceled: {
                                scene.dragging = false;
                                proxy.finalizeSync();
                            }
                        }
                    }
                }
            }
        }
    }
}
