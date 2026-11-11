import QtQuick
import "../../"
import ".."
import "../../reusables"

Loader {
    id: imagePickerLoader
    required property var host
    required property var redactorMode
    required property var redactorWindow

    function s(val) { return Scaler.s(val); }

    anchors.fill: parent
    z: 300000
    active: false
    sourceComponent: ImagePicker {
        rootObj: redactorMode
        property int targetWidgetIndex: -1
        property string targetWidgetId: ""

        onImageSelected: (filePath, fileName) => {
            let model = redactorMode.activeWidgetsModel;
            if (targetWidgetIndex >= 0 && targetWidgetId !== "") {
                if (model) {
                    for (let i = 0; i < model.count; i++) {
                        if (String(model.get(i).wId) === targetWidgetId) {
                            model.setProperty(i, "wImagePath", filePath);
                            break;
                        }
                    }
                }
                WidgetSync.setImagePath(redactorWindow.safeMonitorName, targetWidgetId, filePath);
                targetWidgetIndex = -1;
                targetWidgetId = "";
            } else if (filePath !== "") {
                let def = WidgetRegistry.defaultSize("image");
                let defW = def.w;
                let defH = def.h;
                let spawnX = Math.max(0, (redactorMode.safeWidth - s(defW)) / 2);
                let spawnY = Math.max(0, (redactorMode.safeHeight - s(defH)) / 2);
                let newId = "w_" + Date.now() + "_" + Math.floor(Math.random() * 1000);

                if (redactorMode.gridEnabled) {
                    let snapped = redactorMode.snapBoxToGrid(null, spawnX, spawnY, defW, defH);
                    spawnX = snapped.x;
                    spawnY = snapped.y;
                    defW = snapped.w;
                    defH = snapped.h;
                }

                let defVar = WidgetRegistry.defaultVariant("image");

                if (model) {
                    model.append({
                        "wType": "image",
                        "wVariant": defVar,
                        "wX": spawnX,
                        "wY": spawnY,
                        "wWidth": defW,
                        "wHeight": defH,
                        "wOpacity": 1.0,
                        "wRotation": 0,
                        "wImagePath": filePath,
                        "wId": newId
                    });
                }

                redactorMode.topZ += 1;
                redactorMode.selectedId = newId;
                host.targetSelectedWidgetId = newId;
                WidgetSync.addWidget(redactorWindow.safeMonitorName, newId, "image", spawnX, spawnY, defW, defH, 1.0, filePath, 0, defVar);
                WidgetSync.bringToFront(redactorWindow.safeMonitorName, newId);
                redactorMode.updateToolbarObscured();
            }
        }
    }
}
