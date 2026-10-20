import QtQuick
import "../../"
import "../../widgets"

Item {
    id: view

    property string scope: "screen"
    property var ctx: null
    property var passwordItem: null
    property real reveal: 1
    property real coreLeft: 0
    property real coreRight: 1e9
    readonly property var passwordInput: view.passwordItem ? view.passwordItem.input : null
    readonly property var itemsModel: LockLayoutStore.modelFor(view.scope)

    Repeater {
        model: view.itemsModel

        delegate: Item {
            id: slot

            readonly property string sType: model.itype ?? ""
            readonly property string sVariant: model.ivariant ?? ""
            readonly property string sImage: model.iimage ?? ""
            readonly property bool sShowText: model.showText ?? true
            readonly property real sRotation: model.irotation ?? 0
            readonly property real sOpacity: model.iopacity ?? 1
            readonly property real gX: model.ix ?? 0
            readonly property real gY: model.iy ?? 0
            readonly property real gW: model.iw ?? 0
            readonly property real gH: model.ih ?? 0
            readonly property bool scaled: LockElementRegistry.isScaled(slot.sType)
            readonly property bool auto: slot.gW <= 0 || slot.gH <= 0
            readonly property bool rot90: Math.abs(Math.round(slot.sRotation)) % 180 !== 0
            readonly property real bw: slot.auto ? slot.refW : slot.gW
            readonly property real bh: slot.auto ? slot.refH : slot.gH
            readonly property real faceIW: faceLoader.item ? faceLoader.item.implicitWidth : 0
            readonly property real faceIH: faceLoader.item ? faceLoader.item.implicitHeight : 0
            readonly property bool inCore: slot.x + slot.width / 2 >= view.coreLeft && slot.x + slot.width / 2 <= view.coreRight
            property real refW: 0
            property real refH: 0

            opacity: slot.inCore ? 1.0 : view.reveal

            x: slot.auto ? slot.gX - slot.bw / 2 : slot.gX
            y: slot.auto ? slot.gY - slot.bh / 2 : slot.gY
            width: slot.rot90 ? slot.bh : slot.bw
            height: slot.rot90 ? slot.bw : slot.bh

            onFaceIWChanged: slot.captureRef()
            onFaceIHChanged: slot.captureRef()

            function captureRef() {
                if (!slot.scaled || slot.faceIW <= 0 || slot.faceIH <= 0) return;
                slot.refW = slot.faceIW;
                slot.refH = slot.faceIH;
            }

            Item {
                id: rotatable
                width: slot.bw
                height: slot.bh
                anchors.centerIn: parent
                rotation: slot.sRotation

                Loader {
                    id: faceLoader
                    width: slot.scaled && slot.refW > 0 ? slot.refW : rotatable.width
                    height: slot.scaled && slot.refH > 0 ? slot.refH : rotatable.height
                    scale: slot.scaled && slot.refW > 0 ? rotatable.width / slot.refW : 1
                    transformOrigin: Item.TopLeft
                    opacity: slot.sOpacity
                    source: LockElementRegistry.faceSource(slot.sType, slot.sVariant)

                    onLoaded: {
                        if (!item) return;
                        if (LockElementRegistry.isWidget(slot.sType)) {
                            try {
                                if (item.imagePath !== undefined) item.imagePath = Qt.binding(() => slot.sImage);
                                if (item.wImagePath !== undefined) item.wImagePath = Qt.binding(() => slot.sImage);
                                if (item.path !== undefined) item.path = Qt.binding(() => slot.sImage);
                                if (item.source !== undefined && typeof item.source === "string") item.source = Qt.binding(() => slot.sImage);
                            } catch (e) {}
                            let row = view.itemsModel.get(index);
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
                        } else {
                            if (item.variant !== undefined) item.variant = Qt.binding(() => slot.sVariant);
                            if (item.showText !== undefined) item.showText = Qt.binding(() => slot.sShowText);
                            if (item.ctx !== undefined) item.ctx = Qt.binding(() => view.ctx);
                            if (slot.sType === "password") view.passwordItem = item;
                        }
                        slot.captureRef();
                    }
                }
            }
        }
    }
}
