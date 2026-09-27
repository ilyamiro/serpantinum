import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import "../../"
import "../../reusables"
import "../../widgets"

Popup {
    id: savePresetPopup
    parent: rootObj ? rootObj : undefined
    x: parent && parent.width > 0 ? Math.max(0, Math.round((parent.width - width) / 2)) : 0
    y: parent && parent.height > 0 ? Math.max(0, Math.round((parent.height - height) / 2)) : 0
    modal: true
    dim: true
    width: rootObj ? Math.min(rootObj.width - rootObj.s(32), rootObj.s(720)) : 720
    padding: rootObj ? rootObj.s(20) : 20
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

    property var rootObj
    property string targetMonitor: ""
    property var targetWidgets: []

    signal saveRequested(string presetName, string monName, var widgetsList)

    function openForMonitor(monName, widgetsList) {
        targetMonitor = monName;
        targetWidgets = widgetsList ? widgetsList : [];
        presetNameInput.text = "";
        open();
        presetNameInput.forceInputFocus();
    }

    function commitSave() {
        let name = presetNameInput.text.trim();
        if (!name) {
            presetNameInput.triggerShake();
            return;
        }
        savePresetPopup.saveRequested(name, targetMonitor, targetWidgets);
        close();
    }

    function getScreen(monName) {
        if (Quickshell.screens && Quickshell.screens.length > 0) {
            let target = String(monName || "").trim().toLowerCase();
            for (let i = 0; i < Quickshell.screens.length; i++) {
                let scr = Quickshell.screens[i];
                if (scr && scr.name) {
                    let nm = String(scr.name).trim().toLowerCase();
                    let safe = nm.replace(/[^a-zA-Z0-9_-]/g, "_");
                    if (nm === target || safe === target) return scr;
                }
            }
            return Quickshell.screens[0];
        }
        return null;
    }

    function getScreenDimensions(monName) {
        let sw = 1920;
        let sh = 1080;
        let scr = getScreen(monName);
        if (scr) {
            if (scr.width > 0) sw = scr.width;
            if (scr.height > 0) sh = scr.height;
        }
        return { w: sw, h: sh };
    }

    function getWallpaperSource(monName) {
        let p = "";
        if (typeof Wallpaper !== "undefined" && Wallpaper.screenWallpaperPaths) {
            if (Wallpaper.screenWallpaperPaths[monName]) {
                p = Wallpaper.screenWallpaperPaths[monName];
            } else {
                let target = String(monName || "").toLowerCase();
                for (let k in Wallpaper.screenWallpaperPaths) {
                    if (String(k).toLowerCase() === target) {
                        p = Wallpaper.screenWallpaperPaths[k];
                        break;
                    }
                }
            }
        }
        let isVid = false;
        if (p) {
            let lp = p.toLowerCase();
            isVid = lp.endsWith(".mp4") || lp.endsWith(".mkv") || lp.endsWith(".mov") || lp.endsWith(".webm");
        }
        let cacheDir = (typeof Caching !== "undefined" && typeof Caching.getCacheDir === "function")
            ? Caching.getCacheDir("wallpaper") : "";
        if (isVid || !p) {
            let monSnap = (cacheDir && monName) ? (cacheDir + "/current_wallpaper_" + monName + ".png") : "";
            if (monSnap) return "file://" + monSnap;
            let genSnap = cacheDir ? (cacheDir + "/current_wallpaper.png") : "";
            if (genSnap) return "file://" + genSnap;
        }
        if (p) {
            return p.indexOf("://") !== -1 ? p : ("file://" + p);
        }
        return "";
    }

    function resolveDimension(val, screenDim, defVal) {
        if (typeof WidgetRegistry !== "undefined" && typeof WidgetRegistry.resolveDimension === "function") {
            return WidgetRegistry.resolveDimension(val, screenDim, defVal);
        }
        if (typeof val === "string" && val.indexOf("%") !== -1) {
            return (parseFloat(val) / 100) * screenDim;
        }
        let n = parseFloat(val);
        return !isNaN(n) ? n : defVal;
    }

    function resolvePosition(cfg, sw, sh, w, h) {
        if (typeof WidgetRegistry !== "undefined" && typeof WidgetRegistry.resolvePosition === "function") {
            return WidgetRegistry.resolvePosition(cfg, sw, sh, w, h);
        }
        let anchor = (cfg.anchor || "").toLowerCase();
        let rawX = cfg.x !== undefined ? cfg.x : (cfg.wX !== undefined ? cfg.wX : 0);
        let rawY = cfg.y !== undefined ? cfg.y : (cfg.wY !== undefined ? cfg.wY : 0);
        let x = resolveDimension(rawX, sw, 0);
        let y = resolveDimension(rawY, sh, 0);

        let resX = x;
        let resY = y;
        if (anchor.indexOf("right") !== -1) {
            resX = sw - w - x;
        } else if (anchor.indexOf("center") !== -1 && anchor.indexOf("left") === -1) {
            resX = (sw - w) / 2 + x;
        }
        if (anchor.indexOf("bottom") !== -1) {
            resY = sh - h - y;
        } else if (anchor.indexOf("vcenter") !== -1 || (anchor.indexOf("center") !== -1 && anchor.indexOf("top") === -1 && anchor.indexOf("bottom") === -1)) {
            resY = (sh - h) / 2 + y;
        }
        return { x: resX, y: resY };
    }

    function getFaceUrl(type, variant) {
        if (!type) return "";
        let vKey = variant || "";
        if (typeof WidgetRegistry !== "undefined") {
            if (typeof WidgetRegistry.faceFile === "function") {
                let f = WidgetRegistry.faceFile(type, vKey);
                if (f && f !== "") return f;
            }
            if (WidgetRegistry.types && WidgetRegistry.types[type]) {
                let t = WidgetRegistry.types[type];
                let v = (vKey && t.variants && t.variants[vKey]) ? t.variants[vKey] : (t.variants ? t.variants[t.defaultVariant] : null);
                if (v && v.file) {
                    return Qt.resolvedUrl("../../widgets/" + v.file);
                }
            }
        }
        let cap = type.charAt(0).toUpperCase() + type.slice(1);
        return Qt.resolvedUrl("../../widgets/faces/" + cap + "Face.qml");
    }

    Connections {
        target: savePresetPopup.rootObj ? savePresetPopup.rootObj : null
        function onVisibleChanged() {
            if (savePresetPopup.rootObj && !savePresetPopup.rootObj.visible) {
                savePresetPopup.close();
            }
        }
    }

    Connections {
        target: savePresetPopup.parent && savePresetPopup.parent !== savePresetPopup.rootObj ? savePresetPopup.parent : null
        function onVisibleChanged() {
            if (savePresetPopup.parent && !savePresetPopup.parent.visible) {
                savePresetPopup.close();
            }
        }
    }

    background: Rectangle {
        radius: ThemeBackend.clampedBorderRadius
        color: ThemeBackend.base
        border.color: ThemeBackend.surface0
        border.width: 1
    }

    contentItem: ColumnLayout {
        spacing: rootObj ? rootObj.s(16) : 16

        RowLayout {
            Layout.fillWidth: true

            Text {
                text: I18n.t("guide.display.widgets.save_preset.title", "Save Preset")
                color: ThemeBackend.text
                font.family: ThemeBackend.fontFamily
                font.pixelSize: rootObj ? rootObj.s(16) : 16
                font.bold: true
                Layout.fillWidth: true
            }

            IconButton {
                size: rootObj ? rootObj.s(30) : 30
                cornerRadius: rootObj ? rootObj.s(8) : 8
                buttonIcon: "󰅖"
                iconFontSize: rootObj ? rootObj.s(14) : 14
                accentColor: ThemeBackend.surface0
                textColor: ThemeBackend.text
                onClicked: savePresetPopup.close()
            }
        }

        Rectangle {
            id: currentPreviewBox
            Layout.fillWidth: true

            property var screenDims: savePresetPopup.getScreenDimensions(savePresetPopup.targetMonitor)
            property real sWidth: screenDims.w > 0 ? screenDims.w : 1920
            property real sHeight: screenDims.h > 0 ? screenDims.h : 1080
            property real sAspect: (sWidth > 0 && sHeight > 0) ? (sWidth / sHeight) : (16 / 9)

            Layout.preferredHeight: Math.round(width / sAspect)
            Layout.minimumHeight: Layout.preferredHeight
            Layout.maximumHeight: Layout.preferredHeight
            radius: ThemeBackend.borderRadius
            color: Qt.darker(ThemeBackend.surface0, 1.15)
            clip: true

            Item {
                anchors.fill: parent
                clip: true

                Item {
                    width: currentPreviewBox.sWidth
                    height: currentPreviewBox.sHeight
                    transformOrigin: Item.TopLeft
                    scale: (currentPreviewBox.width > 0 ? currentPreviewBox.width : 1) / currentPreviewBox.sWidth
                    enabled: false

                    Image {
                        anchors.fill: parent
                        source: (savePresetPopup.visible && savePresetPopup.targetMonitor) ? savePresetPopup.getWallpaperSource(savePresetPopup.targetMonitor) : ""
                        fillMode: Image.PreserveAspectCrop
                        smooth: true
                        cache: true
                        asynchronous: false
                        onStatusChanged: {
                            if (status === Image.Error) {
                                let snap = "file://" + Caching.getCacheDir("wallpaper") + "/current_wallpaper.png";
                                if (source.toString() !== snap) {
                                    source = snap;
                                }
                            }
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: "#000000"
                        opacity: 0.25
                    }

                    Item {
                        anchors.fill: parent

                        Repeater {
                            model: savePresetPopup.visible ? savePresetPopup.targetWidgets : []
                            delegate: Item {
                                id: curMiniContainer
                                required property var modelData
                                required property int index

                                readonly property string typeStr: modelData.type || modelData.wType || "time"
                                readonly property var defSize: (typeof WidgetRegistry !== "undefined" && typeof WidgetRegistry.defaultSize === "function")
                                    ? WidgetRegistry.defaultSize(typeStr)
                                    : ({ w: 250, h: 120 })
                                readonly property string defVariant: (typeof WidgetRegistry !== "undefined" && typeof WidgetRegistry.defaultVariant === "function")
                                    ? WidgetRegistry.defaultVariant(typeStr)
                                    : "default"
                                readonly property string variantStr: modelData.variant || modelData.wVariant || curMiniContainer.defVariant

                                readonly property real rawW: modelData.w !== undefined ? modelData.w : (modelData.width !== undefined ? modelData.width : (modelData.wWidth !== undefined ? modelData.wWidth : defSize.w))
                                readonly property real rawH: modelData.h !== undefined ? modelData.h : (modelData.height !== undefined ? modelData.height : (modelData.wHeight !== undefined ? modelData.wHeight : defSize.h))

                                readonly property real resolvedW: (modelData.stretchWidth || modelData.wStretchWidth) ? currentPreviewBox.sWidth : savePresetPopup.resolveDimension(rawW, currentPreviewBox.sWidth, defSize.w)
                                readonly property real resolvedH: (modelData.stretchHeight || modelData.wStretchHeight) ? currentPreviewBox.sHeight : savePresetPopup.resolveDimension(rawH, currentPreviewBox.sHeight, defSize.h)

                                readonly property var resolvedPos: savePresetPopup.resolvePosition(modelData, currentPreviewBox.sWidth, currentPreviewBox.sHeight, resolvedW, resolvedH)

                                x: resolvedPos.x
                                y: resolvedPos.y
                                width: resolvedW
                                height: resolvedH
                                opacity: modelData.opacity !== undefined ? modelData.opacity : 1.0
                                rotation: modelData.rotation !== undefined ? modelData.rotation : 0

                                Loader {
                                    anchors.fill: parent
                                    asynchronous: false
                                    source: savePresetPopup.getFaceUrl(curMiniContainer.typeStr, curMiniContainer.variantStr)
                                    onLoaded: {
                                        if (item) {
                                            if ("variant" in item) item.variant = curMiniContainer.variantStr;
                                            if ("wVariant" in item) item.wVariant = curMiniContainer.variantStr;
                                            if ("type" in item) item.type = curMiniContainer.typeStr;
                                            if ("wType" in item) item.wType = curMiniContainer.typeStr;
                                            if ("wWidth" in item) item.wWidth = curMiniContainer.width;
                                            if ("wHeight" in item) item.wHeight = curMiniContainer.height;
                                            if ("imagePath" in item) item.imagePath = modelData.imagePath || modelData.wImagePath || "";
                                            if ("wImagePath" in item) item.wImagePath = modelData.imagePath || modelData.wImagePath || "";
                                            if ("previewMode" in item) item.previewMode = true;
                                            if ("screen" in item) item.screen = savePresetPopup.getScreen(savePresetPopup.targetMonitor);
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                anchors.fill: parent
                color: "transparent"
                border.width: 1
                border.color: Qt.alpha(ThemeBackend.surface2, 0.4)
                radius: ThemeBackend.borderRadius
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: rootObj ? rootObj.s(10) : 10

            Input {
                id: presetNameInput
                Layout.fillWidth: true
                Layout.preferredHeight: rootObj ? rootObj.s(38) : 38
                placeholderText: I18n.t("guide.display.widgets.preset_name_placeholder", "Enter preset name...")
                baseColor: ThemeBackend.surface0
                accentColor: ThemeBackend.mauve
                textColor: ThemeBackend.text
                subTextColor: ThemeBackend.subtext0
                borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                cornerRadius: ThemeBackend.borderRadius
                fontPixelSize: rootObj ? rootObj.s(13) : 13
                onAccepted: savePresetPopup.commitSave()
            }

            IconButton {
                size: rootObj ? rootObj.s(38) : 38
                Layout.preferredWidth: rootObj ? rootObj.s(38) : 38
                Layout.preferredHeight: rootObj ? rootObj.s(38) : 38
                cornerRadius: ThemeBackend.borderRadius
                buttonIcon: "󰄬"
                iconFontSize: rootObj ? rootObj.s(18) : 18
                accentColor: ThemeBackend.mauve
                textColor: ThemeBackend.crust
                onClicked: savePresetPopup.commitSave()
            }
        }
    }
}
