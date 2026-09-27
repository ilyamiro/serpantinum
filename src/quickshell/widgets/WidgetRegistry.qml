pragma Singleton
import QtQuick
import QtQuick.Layouts
import Quickshell
import "../"
import "../reusables"

QtObject {
    id: registry

    readonly property var standardKeys: [
        "id", "wId", "type", "wType", "variant", "wVariant",
        "x", "y", "wX", "wY", "w", "h", "width", "height", "wWidth", "wHeight",
        "opacity", "wOpacity", "rotation", "wRotation",
        "imagePath", "wImagePath", "path",
        "stretchWidth", "wStretchWidth", "stretchHeight", "wStretchHeight",
        "offsetX", "offsetY", "anchor", "anchors", "anchorH", "anchorX", "horizontalAnchor",
        "hAnchor", "anchorHorizontal", "anchorV", "anchorY", "verticalAnchor", "vAnchor",
        "anchorVertical", "isRemoving", "wProps"
    ]

    function extractProps(obj) {
        let out = {};
        if (!obj) return out;
        for (let k in obj) {
            if (!standardKeys.includes(k) && typeof obj[k] !== "function") {
                out[k] = obj[k];
            }
        }
        return out;
    }

    property var componentCache: ({})

    property Component defaultToolbarButtonComponent: Component {
        ColumnLayout {
            id: itemCol
            property var typeData: null
            property var redactor: null

            spacing: Scaler.s(6)
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: Scaler.s(52)

            IconButton {
                size: Scaler.s(48)
                iconOffsetX: (itemCol.typeData && itemCol.typeData.iconOffsetX !== undefined) ? Scaler.s(itemCol.typeData.iconOffsetX) : 0
                cornerRadius: ThemeBackend.borderRadius
                buttonIcon: (itemCol.typeData && itemCol.typeData.icon) ? itemCol.typeData.icon : ""
                iconFontSize: Scaler.s(22)
                accentColor: ThemeBackend.surface0
                textColor: ThemeBackend.text
                Layout.alignment: Qt.AlignHCenter

                onClicked: {
                    if (itemCol.redactor && itemCol.typeData) {
                        itemCol.redactor.addWidget(itemCol.typeData.id);
                    }
                }
            }

            Text {
                text: (itemCol.typeData && itemCol.typeData.name) ? itemCol.typeData.name : (itemCol.typeData ? itemCol.typeData.id : "")
                font.family: ThemeBackend.fontFamily
                font.pixelSize: Scaler.s(11)
                font.bold: true
                color: ThemeBackend.subtext0
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: Scaler.s(52)
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                maximumLineCount: 1
                Layout.bottomMargin: Scaler.s(2)
            }
        }
    }

    property Component lyricsLinesSelectorComponent: Component {
        Item {
            id: settingRoot
            property var typeData: null
            property var settingData: null
            property var redactor: null
            property var widget: null
            property var widgetData: null
            property var item: null

            readonly property var targetWidget: {
                if (settingRoot.widget) return settingRoot.widget;
                if (settingRoot.widgetData) return settingRoot.widgetData;
                if (settingRoot.item) return settingRoot.item;
                if (settingRoot.redactor) {
                    if (settingRoot.redactor.selectedWidget) return settingRoot.redactor.selectedWidget;
                    if (settingRoot.redactor.currentWidget) return settingRoot.redactor.currentWidget;
                    if (settingRoot.redactor.activeWidget) return settingRoot.redactor.activeWidget;
                    if (settingRoot.redactor.widget) return settingRoot.redactor.widget;
                }
                if (typeof Config !== "undefined" && Config.selectedWidget) return Config.selectedWidget;
                return null;
            }

            readonly property bool isApplicable: {
                let w = settingRoot.targetWidget;
                if (!w) return true;
                let v = w.variant || (settingRoot.typeData ? settingRoot.typeData.variant : "");
                return !v || v === "simpleLyrics";
            }

            visible: isApplicable
            implicitWidth: selector.implicitWidth
            implicitHeight: selector.implicitHeight

            function syncValue() {
                let w = settingRoot.targetWidget;
                if (!w) return;
                let cur = (w.lyricsLines !== undefined) ? w.lyricsLines : 1;
                if (selector.value !== cur) {
                    selector.setValue(cur);
                }
            }

            Component.onCompleted: syncValue()
            onTargetWidgetChanged: syncValue()

            Connections {
                target: settingRoot.targetWidget
                ignoreUnknownSignals: true
                function onLyricsLinesChanged() {
                    settingRoot.syncValue();
                }
            }

            NumberSelector {
                id: selector
                anchors.centerIn: parent
                implicitWidth: Scaler.s(120)
                implicitHeight: Scaler.s(32)
                from: 0
                to: 4
                stepSize: 1
                decimals: 0
                value: {
                    let w = settingRoot.targetWidget;
                    return (w && w.lyricsLines !== undefined) ? w.lyricsLines : 1;
                }
                specialZeroText: "0"
                fontFamily: (typeof ThemeBackend !== "undefined" && ThemeBackend.fontFamily) ? ThemeBackend.fontFamily : "JetBrains Mono"
                accentColor: (typeof ThemeBackend !== "undefined" && ThemeBackend.mauve) ? ThemeBackend.mauve : "#cba6f7"
                baseColor: (typeof ThemeBackend !== "undefined" && ThemeBackend.surface0) ? ThemeBackend.surface0 : "#313244"
                buttonColor: (typeof ThemeBackend !== "undefined" && ThemeBackend.surface1) ? ThemeBackend.surface1 : "#45475a"
                textColor: (typeof ThemeBackend !== "undefined" && ThemeBackend.text) ? ThemeBackend.text : "#cdd6f4"
                buttonTextColor: (typeof ThemeBackend !== "undefined" && ThemeBackend.subtext1) ? ThemeBackend.subtext1 : "#bac2de"
                cornerRadius: (typeof ThemeBackend !== "undefined" && ThemeBackend.borderRadius !== undefined) ? ThemeBackend.borderRadius : 10

                onTriggered: {
                    let w = settingRoot.targetWidget;
                    let val = Math.round(selector.value);
                    if (w) {
                        w.lyricsLines = val;
                        if (typeof w.linesBehind !== "undefined") w.linesBehind = val;
                        if (typeof w.linesAfter !== "undefined") w.linesAfter = val;
                    }
                    if (settingRoot.redactor) {
                        if (typeof settingRoot.redactor.setWidgetProperty === "function") {
                            settingRoot.redactor.setWidgetProperty("lyricsLines", val);
                        } else if (typeof settingRoot.redactor.updateWidgetProperty === "function") {
                            settingRoot.redactor.updateWidgetProperty(w, "lyricsLines", val);
                        } else if (typeof settingRoot.redactor.saveConfig === "function") {
                            settingRoot.redactor.saveConfig();
                        } else if (typeof settingRoot.redactor.save === "function") {
                            settingRoot.redactor.save();
                        }
                    }
                }
            }
        }
    }

    property Component lyricsAlignmentSelectorComponent: Component {
        Item {
            id: settingRoot
            property var typeData: null
            property var settingData: null
            property var redactor: null
            property var widget: null
            property var widgetData: null
            property var item: null

            readonly property var targetWidget: {
                if (settingRoot.widget) return settingRoot.widget;
                if (settingRoot.widgetData) return settingRoot.widgetData;
                if (settingRoot.item) return settingRoot.item;
                if (settingRoot.redactor) {
                    if (settingRoot.redactor.selectedWidget) return settingRoot.redactor.selectedWidget;
                    if (settingRoot.redactor.currentWidget) return settingRoot.redactor.currentWidget;
                    if (settingRoot.redactor.activeWidget) return settingRoot.redactor.activeWidget;
                    if (settingRoot.redactor.widget) return settingRoot.redactor.widget;
                }
                if (typeof Config !== "undefined" && Config.selectedWidget) return Config.selectedWidget;
                return null;
            }

            readonly property bool isApplicable: {
                let w = settingRoot.targetWidget;
                if (!w) return true;
                let v = w.variant || (settingRoot.typeData ? settingRoot.typeData.variant : "");
                return !v || v === "lyrics" || v === "simpleLyrics";
            }

            visible: isApplicable
            implicitWidth: alignSwitch.implicitWidth
            implicitHeight: alignSwitch.implicitHeight

            readonly property var alignOptions: [
                { id: "left", label: typeof I18n !== "undefined" ? I18n.t("widgets.align.left", "Left") : "Left" },
                { id: "center", label: typeof I18n !== "undefined" ? I18n.t("widgets.align.center", "Center") : "Center" },
                { id: "right", label: typeof I18n !== "undefined" ? I18n.t("widgets.align.right", "Right") : "Right" }
            ]

            function syncValue() {
                let w = settingRoot.targetWidget;
                if (!w) return;
                let cur = (w.lyricsAlignment !== undefined && w.lyricsAlignment !== "") ? w.lyricsAlignment : ((w.alignment !== undefined && w.alignment !== "") ? w.alignment : "left");
                for (let i = 0; i < alignOptions.length; i++) {
                    if (alignOptions[i].id === cur) {
                        if (alignSwitch.currentIndex !== i) {
                            alignSwitch.currentIndex = i;
                        }
                        break;
                    }
                }
            }

            Component.onCompleted: syncValue()
            onTargetWidgetChanged: syncValue()

            Connections {
                target: settingRoot.targetWidget
                ignoreUnknownSignals: true
                function onLyricsAlignmentChanged() {
                    settingRoot.syncValue();
                }
                function onAlignmentChanged() {
                    settingRoot.syncValue();
                }
            }

            Switch {
                id: alignSwitch
                anchors.centerIn: parent
                implicitHeight: Scaler.s(32)
                implicitWidth: Scaler.s(160)
                accentColor: (typeof ThemeBackend !== "undefined" && ThemeBackend.mauve) ? ThemeBackend.mauve : "#cba6f7"
                baseColor: (typeof ThemeBackend !== "undefined" && ThemeBackend.surface0) ? ThemeBackend.surface0 : "#313244"
                textColor: (typeof ThemeBackend !== "undefined" && ThemeBackend.text) ? ThemeBackend.text : "#cdd6f4"
                activeTextColor: (typeof ThemeBackend !== "undefined" && ThemeBackend.crust) ? ThemeBackend.crust : "#11111b"
                cornerRadius: (typeof ThemeBackend !== "undefined" && ThemeBackend.borderRadius !== undefined) ? ThemeBackend.borderRadius : 10
                fontPixelSize: Scaler.s(11)
                options: alignOptions.map(o => o.label || o.id)

                onToggled: (idx) => {
                    if (idx < 0 || idx >= alignOptions.length) return;
                    let val = alignOptions[idx].id;
                    let w = settingRoot.targetWidget;
                    if (w) {
                        w.lyricsAlignment = val;
                        if (typeof w.alignment !== "undefined") w.alignment = val;
                    }
                    if (settingRoot.redactor) {
                        if (typeof settingRoot.redactor.setWidgetProperty === "function") {
                            settingRoot.redactor.setWidgetProperty("lyricsAlignment", val);
                        } else if (typeof settingRoot.redactor.updateWidgetProperty === "function") {
                            settingRoot.redactor.updateWidgetProperty(w, "lyricsAlignment", val);
                        } else if (typeof settingRoot.redactor.saveConfig === "function") {
                            settingRoot.redactor.saveConfig();
                        } else if (typeof settingRoot.redactor.save === "function") {
                            settingRoot.redactor.save();
                        }
                    }
                }
            }
        }
    }

    property var types: ({
        "visualizer": {
            name: I18n.t("widgets.types.visualizer"),
            icon: String.fromCodePoint(0xF147D),
            iconOffsetX: -2,
            defaultWidth: Math.round((Quickshell.screens && Quickshell.screens.length > 0 ? Quickshell.screens[0].width : 1920) / 2),
            defaultHeight: 180,
            defaultVariant: "bars",
            variants: {
                "bars": { file: "faces/visualizer/VisualizerFace.qml", icon: "1", label: I18n.t("widgets.variants.bars") },
                "continuous": { file: "faces/visualizer/VisualizerFaceContinuous.qml", icon: "2", label: I18n.t("widgets.variants.continuous") }
            },
            additionalSettings: [
                {
                    id: "stretchWidth",
                    icon: String.fromCodePoint(0xF0293),
                    iconFontSize: 16,
                    action: "stretchWidth",
                    row: "top",
                    accentColor: "surface0",
                    textColor: "mauve"
                }
            ]
        },
        "time": {
            name: I18n.t("widgets.types.clock"),
            icon: String.fromCodePoint(0xF0954),
            defaultWidth: 250,
            iconOffsetX: 0,
            defaultHeight: 120,
            defaultVariant: "digital",
            variants: {
                "digital":        { file: "faces/clock/ClockFaceDigital.qml",        icon: "1", label: I18n.t("widgets.variants.digital") },
                "analog":         { file: "faces/clock/ClockFaceAnalog.qml",         icon: "2", label: I18n.t("widgets.variants.analog") },
                "minimal":        { file: "faces/clock/ClockFaceMinimal.qml",        icon: "3", label: I18n.t("widgets.variants.minimal") },
                "material":       { file: "faces/clock/ClockFaceMaterial.qml",       icon: "4", label: I18n.t("widgets.variants.material") },
                "materialAnalog": { file: "faces/clock/ClockFaceMaterialAnalog.qml", icon: "5", label: I18n.t("widgets.variants.materialAnalog") },
                "lumen":          { file: "faces/clock/ClockFaceMaterialLumen.qml",  icon: "6", label: I18n.t("widgets.variants.lumen") }
            }
        },
        "music": {
            name: I18n.t("widgets.types.music"),
            icon: String.fromCodePoint(0xF0388),
            defaultWidth: 340,
            defaultHeight: 120,
            defaultVariant: "full",
            variants: {
                "full":         { file: "faces/music/MusicFace.qml",             icon: "1", label: I18n.t("widgets.variants.full") },
                "round":        { file: "faces/music/MusicFaceRound.qml",        icon: "2", label: I18n.t("widgets.variants.round") },
                "lyrics":       { file: "faces/music/MusicFaceLyrics.qml",       icon: "3", label: I18n.t("widgets.variants.lyrics") },
                "simpleLyrics": { file: "faces/music/MusicFaceLyricsSimple.qml", icon: "4", label: typeof I18n !== "undefined" ? I18n.t("widgets.variants.simpleLyrics", "Simple Lyrics") : "Simple Lyrics" }
            },
            additionalSettings: [
                {
                    id: "lyricsLines",
                    name: typeof I18n !== "undefined" ? I18n.t("widgets.settings.lyricsLines", "Lines") : "Lines",
                    icon: String.fromCodePoint(0xF0388),
                    iconFontSize: 16,
                    action: "lyricsLines",
                    type: "custom",
                    row: "top",
                    variant: "simpleLyrics",
                    variants: ["simpleLyrics"],
                    property: "lyricsLines",
                    from: 0,
                    to: 4,
                    stepSize: 1,
                    accentColor: "surface0",
                    textColor: "mauve",
                    component: registry.lyricsLinesSelectorComponent
                },
                {
                    id: "lyricsAlignment",
                    name: typeof I18n !== "undefined" ? I18n.t("widgets.settings.lyricsAlignment", "Alignment") : "Alignment",
                    icon: String.fromCodePoint(0xF0765),
                    iconFontSize: 16,
                    action: "lyricsAlignment",
                    type: "custom",
                    row: "top",
                    variants: ["lyrics", "simpleLyrics"],
                    property: "lyricsAlignment",
                    accentColor: "surface0",
                    textColor: "mauve",
                    component: registry.lyricsAlignmentSelectorComponent
                }
            ]
        },
        "weather": {
            name: I18n.t("widgets.types.weather"),
            icon: String.fromCodePoint(0xF0590),
            iconOffsetX: 0,
            defaultWidth: 250,
            defaultHeight: 120,
            defaultVariant: "compact",
            variants: {
                "compact": { file: "faces/weather/WeatherFaceCompact.qml", icon: "1", label: I18n.t("widgets.variants.compact") },
                "full":    { file: "faces/weather/WeatherFaceFull.qml",    icon: "2", label: I18n.t("widgets.variants.full") },
                "round":   { file: "faces/weather/WeatherFaceRound.qml",   icon: "3", label: I18n.t("widgets.variants.round") }
            }
        },
        "image": {
            name: I18n.t("widgets.types.image"),
            icon: String.fromCodePoint(0xF02E9),
            iconOffsetX: -1,
            defaultWidth: 300,
            defaultHeight: 200,
            defaultVariant: "rect",
            requiresFilePicker: true,
            variants: {
                "rect":    { file: "faces/image/ImageFaceRect.qml",    icon: "1", label: I18n.t("widgets.variants.rect") },
                "rounded": { file: "faces/image/ImageFaceRounded.qml", icon: "2", label: I18n.t("widgets.variants.rounded") },
                "round":   { file: "faces/image/ImageFaceRound.qml",   icon: "3", label: I18n.t("widgets.variants.round") }
            },
            additionalSettings: [
                {
                    id: "pickImage",
                    icon: String.fromCodePoint(0xF02E9),
                    iconFontSize: 16,
                    action: "pickImage",
                    row: "top",
                    accentColor: "surface0",
                    textColor: "mauve"
                }
            ]
        },
        "user": {
            name: I18n.t("widgets.types.user"),
            icon: String.fromCodePoint(0xF0004),
            iconOffsetX: 0,
            defaultWidth: 260,
            defaultHeight: 140,
            defaultVariant: "default",
            variants: {
                "default": { file: "faces/user/UserFace.qml", icon: "1", label: I18n.t("widgets.variants.default") }
            }
        },
        "cpu": {
            name: I18n.t("quickactions.systemusage.cpu"),
            icon: String.fromCodePoint(0xF035B),
            iconOffsetX: 0,
            defaultWidth: 180,
            defaultHeight: 130,
            defaultVariant: "default",
            variants: {
                "default": { file: "faces/usage/CpuFace.qml", icon: "1", label: I18n.t("widgets.variants.default") }
            }
        },
        "ram": {
            name: I18n.t("quickactions.systemusage.ram"),
            icon: String.fromCodePoint(0xF035C),
            iconOffsetX: 0,
            defaultWidth: 180,
            defaultHeight: 130,
            defaultVariant: "default",
            variants: {
                "default": { file: "faces/usage/RamFace.qml", icon: "1", label: I18n.t("widgets.variants.default") }
            }
        },
        "temp": {
            name: I18n.t("quickactions.systemusage.temp"),
            icon: String.fromCodePoint(0xF050F),
            iconOffsetX: 0,
            defaultWidth: 180,
            defaultHeight: 130,
            defaultVariant: "default",
            variants: {
                "default": { file: "faces/usage/TempFace.qml", icon: "1", label: I18n.t("widgets.variants.default") }
            }
        },
        "disk": {
            name: I18n.t("quickactions.systemusage.disk"),
            icon: String.fromCodePoint(0xF02CA),
            iconOffsetX: 0,
            defaultWidth: 180,
            defaultHeight: 130,
            defaultVariant: "default",
            variants: {
                "default": { file: "faces/usage/DiskFace.qml", icon: "1", label: I18n.t("widgets.variants.default") }
            }
        },
        "battery": {
            name: I18n.t("widgets.types.battery"),
            icon: String.fromCodePoint(0xF0079),
            iconOffsetX: 1,
            defaultWidth: 260,
            defaultHeight: 90,
            defaultVariant: "default",
            variants: {
                "default": { file: "faces/battery/BatteryFace.qml", icon: "1", label: I18n.t("widgets.variants.default") }
            }
        },
        "github": {
            name: typeof I18n !== "undefined" ? I18n.t("widgets.types.github", "GitHub") : "GitHub",
            icon: String.fromCodePoint(0xF02A4),
            iconOffsetX: -1,
            defaultWidth: 540,
            defaultHeight: 180,
            defaultVariant: "default",
            variants: {
                "default": { file: "faces/github/GithubFace.qml", icon: "1", label: typeof I18n !== "undefined" ? I18n.t("widgets.variants.default", "Default") : "Default" }
            }
        },
        "quote": {
            name: I18n.t("widgets.types.quote"),
            icon: String.fromCodePoint(0xF0757),
            iconOffsetX: 0,
            defaultWidth: 340,
            defaultHeight: 70,
            defaultVariant: "card",
            variants: {
                "card":    { file: "faces/quote/QuoteFaceCard.qml",    icon: "1", label: I18n.t("widgets.variants.card") },
                "minimal": { file: "faces/quote/QuoteFaceMinimal.qml", icon: "2", label: I18n.t("widgets.variants.minimal") }
            }
        }
    })

    function parseAnchors(item) {
        let rawAnchor = item ? (item.anchor || item.anchors) : null;
        let h = null;
        let v = null;

        if (typeof rawAnchor === "string" && rawAnchor.trim() !== "") {
            let s = rawAnchor.toLowerCase().trim().replace(/[-_]/g, " ");
            let parts = s.split(/\s+/);

            if (parts.length === 1) {
                let single = parts[0];
                if (single === "top") {
                    v = "top";
                    h = "center";
                } else if (single === "bottom") {
                    v = "bottom";
                    h = "center";
                } else if (single === "left") {
                    h = "left";
                    v = "center";
                } else if (single === "right") {
                    h = "right";
                    v = "center";
                } else if (single === "center" || single === "middle") {
                    h = "center";
                    v = "center";
                }
            } else {
                for (let i = 0; i < parts.length; i++) {
                    let p = parts[i];
                    if (p === "top" || p === "bottom") {
                        v = p;
                    } else if (p === "left" || p === "right") {
                        h = p;
                    } else if (p === "center" || p === "middle") {
                        if (!h && !v) {
                            h = "center";
                            v = "center";
                        } else if (!h) {
                            h = "center";
                        } else if (!v) {
                            v = "center";
                        }
                    }
                }
            }
        }

        let rawH = item ? (item.anchorH || item.anchorX || item.horizontalAnchor || item.hAnchor || item.anchorHorizontal) : null;
        if (rawH && typeof rawH === "string" && rawH.trim() !== "") {
            let sh = rawH.toLowerCase().trim();
            if (sh === "middle") h = "center";
            else if (sh === "left" || sh === "center" || sh === "right") h = sh;
        }

        let rawV = item ? (item.anchorV || item.anchorY || item.verticalAnchor || item.vAnchor || item.anchorVertical) : null;
        if (rawV && typeof rawV === "string" && rawV.trim() !== "") {
            let sv = rawV.toLowerCase().trim();
            if (sv === "middle") v = "center";
            else if (sv === "top" || sv === "center" || sv === "bottom") v = sv;
        }

        if (!h && !v) return null;
        if (!h) h = "left";
        if (!v) v = "top";

        return { h: h, v: v };
    }

    function getBarOffsets() {
        let pos = "top";
        let autohide = false;
        let isFill = false;

        if (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar) {
            let b = Config.rawSettings.bar;
            if (b.position !== undefined) pos = String(b.position).toLowerCase().trim();
            if (b.autohide !== undefined) autohide = !!b.autohide;
            let s = b.style;
            if (typeof s === "string" && s === "fill") isFill = true;
            else if (s && typeof s === "object" && (s.fill || s.mode === "fill")) isFill = true;
        }

        if (autohide) {
            return { top: 0, bottom: 0, left: 0, right: 0 };
        }

        let margin = isFill ? 0 : Scaler.s(4);
        let barSize = Scaler.s(40) + margin;

        let offsets = { top: 0, bottom: 0, left: 0, right: 0 };
        if (pos === "top") offsets.top = barSize;
        else if (pos === "bottom") offsets.bottom = barSize;
        else if (pos === "left") offsets.left = barSize;
        else if (pos === "right") offsets.right = barSize;

        return offsets;
    }

    function resolveDimension(val, maxVal, defaultVal) {
        if (val === undefined || val === null) return defaultVal;
        if (typeof val === "string" && val.trim().endsWith("%")) {
            let pct = parseFloat(val);
            if (!isNaN(pct)) {
                return Math.round((pct / 100) * maxVal);
            }
        }
        let num = parseFloat(val);
        return (!isNaN(num) && num > 0) ? num : defaultVal;
    }

    function resolvePosition(item, screenWidth, screenHeight, widgetWidth, widgetHeight) {
        let sw = (screenWidth && screenWidth > 0) ? screenWidth : 1920;
        let sh = (screenHeight && screenHeight > 0) ? screenHeight : 1080;
        let w = (widgetWidth !== undefined && !isNaN(widgetWidth)) ? widgetWidth : 250;
        let h = (widgetHeight !== undefined && !isNaN(widgetHeight)) ? widgetHeight : 120;

        let isStretchW = !!(item && (item.stretchWidth || item.wStretchWidth));
        let isStretchH = !!(item && (item.stretchHeight || item.wStretchHeight));

        let rawX = 0;
        if (item) {
            if (item.offsetX !== undefined) rawX = item.offsetX;
            else if (item.x !== undefined) rawX = item.x;
            else if (item.wX !== undefined) rawX = item.wX;
        }

        let rawY = 0;
        if (item) {
            if (item.offsetY !== undefined) rawY = item.offsetY;
            else if (item.y !== undefined) rawY = item.y;
            else if (item.wY !== undefined) rawY = item.wY;
        }

        let ox = (typeof rawX === "string" && rawX.trim().endsWith("%")) ? Math.round((parseFloat(rawX) / 100) * sw) : parseFloat(rawX);
        let oy = (typeof rawY === "string" && rawY.trim().endsWith("%")) ? Math.round((parseFloat(rawY) / 100) * sh) : parseFloat(rawY);

        if (isNaN(ox)) ox = 0;
        if (isNaN(oy)) oy = 0;

        let anchors = parseAnchors(item || {});
        if (!anchors) {
            return {
                x: isStretchW ? 0 : Math.round(ox),
                y: isStretchH ? 0 : Math.round(oy)
            };
        }

        let offsets = getBarOffsets();

        let usableX = isStretchW ? 0 : offsets.left;
        let usableY = isStretchH ? 0 : offsets.top;
        let usableW = isStretchW ? sw : (sw - offsets.left - offsets.right);
        let usableH = isStretchH ? sh : (sh - offsets.top - offsets.bottom);

        let posX = 0;
        if (isStretchW) {
            posX = 0;
        } else if (anchors.h === "right") {
            posX = usableX + usableW - w - ox;
        } else if (anchors.h === "center") {
            posX = usableX + Math.round((usableW - w) / 2) + ox;
        } else {
            posX = usableX + ox;
        }

        let posY = 0;
        if (isStretchH) {
            posY = 0;
        } else if (anchors.v === "bottom") {
            posY = usableY + usableH - h - oy;
        } else if (anchors.v === "center") {
            posY = usableY + Math.round((usableH - h) / 2) + oy;
        } else {
            posY = usableY + oy;
        }

        return {
            x: Math.round(posX),
            y: Math.round(posY)
        };
    }

    function registerType(typeId, def) {
        if (!typeId || !def) return;
        let updated = Object.assign({}, types);
        updated[typeId] = def;
        types = updated;
    }

    function unregisterType(typeId) {
        if (!types[typeId]) return;
        let updated = Object.assign({}, types);
        delete updated[typeId];
        types = updated;
    }

    function toolbarComponent(type) {
        let t = types[type];
        if (t && t.toolbarComponent) {
            return t.toolbarComponent;
        }
        return defaultToolbarButtonComponent;
    }

    function faceFile(type, variant) {
        let t = types[type];
        if (!t) return "";
        let v = t.variants[variant] || t.variants[t.defaultVariant];
        return v ? Qt.resolvedUrl(v.file) : "";
    }

    function faceComponent(type, variant) {
        let t = types[type];
        if (!t) return null;
        let vKey = (variant && t.variants && t.variants[variant]) ? variant : t.defaultVariant;
        let cacheKey = type + "_" + vKey;
        if (componentCache[cacheKey]) {
            return componentCache[cacheKey];
        }
        let fileUrl = faceFile(type, vKey);
        if (!fileUrl) return null;
        let comp = Qt.createComponent(fileUrl);
        if (comp) {
            componentCache[cacheKey] = comp;
        }
        return comp;
    }

    function variantList(type) {
        let t = types[type];
        if (!t || !t.variants) return [];
        return Object.keys(t.variants).map(k => Object.assign({ id: k }, t.variants[k]));
    }

    function defaultVariant(type) {
        return types[type] ? types[type].defaultVariant : "";
    }

    function defaultSize(type) {
        let t = types[type];
        if (!t) return { w: 250, h: 120 };
        return {
            w: t.defaultWidth || 250,
            h: t.defaultHeight || 120
        };
    }

    function typeList() {
        return Object.keys(types).map(k => Object.assign({ id: k }, types[k]));
    }

    function additionalSettings(type, row, variant) {
        let t = types[type];
        if (!t || !t.additionalSettings) return [];
        let list = t.additionalSettings;
        if (variant !== undefined && variant !== null && variant !== "") {
            list = list.filter(s => {
                if (Array.isArray(s.variants)) return s.variants.includes(variant);
                if (s.variant) return s.variant === variant;
                return true;
            });
        }
        if (!row) return list;
        return list.filter(s => (s.row || "top") === row);
    }
}
