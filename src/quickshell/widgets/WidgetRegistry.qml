pragma Singleton
import QtQuick
import Quickshell
import "../"

QtObject {
    id: registry

    readonly property string defaultType: "time"

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

    readonly property var usageCircleSettings: [
        {
            id: "sineWave",
            type: "segmented",
            property: "sineWave",
            row: "top",
            variants: ["circle"],
            defaultValue: true,
            width: 140,
            height: 34,
            options: [
                { value: true, label: I18n.t("widgets.style.wave", "Wave") },
                { value: false, label: I18n.t("widgets.style.circle", "Circle") }
            ]
        },
        {
            id: "lineThickness",
            type: "number",
            property: "lineThickness",
            row: "bottom",
            variants: ["circle"],
            defaultValue: 8,
            min: 3,
            max: 16,
            step: 0.5,
            decimals: 1
        }
    ]

    readonly property var usageGraphSettings: registry.usageCircleSettings.concat([
        {
            id: "updatesPerMinute",
            type: "dropdown",
            property: "updatesPerMinute",
            row: "bottom",
            variants: ["graph"],
            defaultValue: 30,
            width: 110,
            matchNearest: true,
            suffix: I18n.t("widgets.settings.perMinute", "/min"),
            options: [6, 10, 12, 15, 20, 30, 60]
        }
    ])

    readonly property var categories: [
        { id: "time", icon: String.fromCodePoint(0xF0150), name: I18n.t("widgets.redactor.category.time", "Time and text") },
        { id: "media", icon: String.fromCodePoint(0xF075A), name: I18n.t("widgets.redactor.category.media", "Media") },
        { id: "system", icon: String.fromCodePoint(0xF061A), name: I18n.t("widgets.redactor.category.system", "System") },
        { id: "info", icon: String.fromCodePoint(0xF02FD), name: I18n.t("widgets.redactor.category.info", "Info") }
    ]

    readonly property var types: ({
        "visualizer": {
            name: I18n.t("widgets.types.visualizer"),
            icon: String.fromCodePoint(0xF147D),
            category: "media",
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
        "snake": {
            name: I18n.t("widgets.types.snake", "Snake"),
            icon: String.fromCodePoint(0xF150E),
            category: "media",
            defaultWidth: Math.round((Quickshell.screens && Quickshell.screens.length > 0 ? Quickshell.screens[0].width : 1920) / 2),
            defaultHeight: Math.round((Quickshell.screens && Quickshell.screens.length > 0 ? Quickshell.screens[0].height : 1080) / 2),
            defaultVariant: "default",
            variants: {
                "default": { file: "faces/snake/SnakeFace.qml", icon: "1", label: I18n.t("widgets.variants.default", "Default") }
            },
            additionalSettings: [
                {
                    id: "fillScreen",
                    icon: String.fromCodePoint(0xF004C),
                    iconFontSize: 16,
                    action: "fillScreen",
                    row: "top",
                    accentColor: "surface0",
                    textColor: "mauve"
                },
                {
                    id: "snakeLength",
                    type: "number",
                    property: "snakeLength",
                    row: "bottom",
                    defaultValue: 48,
                    min: 16,
                    max: 96,
                    step: 4,
                    decimals: 0
                },
                {
                    id: "snakeSpeed",
                    type: "number",
                    property: "snakeSpeed",
                    row: "bottom",
                    defaultValue: 1,
                    min: 0.25,
                    max: 3,
                    step: 0.25,
                    decimals: 2,
                    suffix: "×"
                }
            ]
        },
        "time": {
            name: I18n.t("widgets.types.clock"),
            icon: String.fromCodePoint(0xF0954),
            category: "time",
            defaultWidth: 250,
            defaultHeight: 120,
            defaultVariant: "digital",
            variants: {
                "digital":        { file: "faces/clock/ClockFaceDigital.qml",        icon: "1", label: I18n.t("widgets.variants.digital") },
                "analog":         { file: "faces/clock/ClockFaceAnalog.qml",         icon: "2", label: I18n.t("widgets.variants.analog") },
                "minimal":        { file: "faces/clock/ClockFaceMinimal.qml",        icon: "3", label: I18n.t("widgets.variants.minimal") },
                "material":       { file: "faces/clock/ClockFaceMaterial.qml",       icon: "4", label: I18n.t("widgets.variants.material") },
                "materialAnalog": { file: "faces/clock/ClockFaceMaterialAnalog.qml", icon: "5", label: I18n.t("widgets.variants.materialAnalog") },
                "lumen":          { file: "faces/clock/ClockFaceMaterialLumen.qml",  icon: "6", label: I18n.t("widgets.variants.lumen") },
                "lockscreen":     { file: "faces/clock/ClockFaceLockscreen.qml",     icon: "7", label: I18n.t("widgets.variants.lockscreen", "Lockscreen") },
                "stretched":      { file: "faces/clock/ClockFaceStretched.qml",      icon: "8", label: I18n.t("widgets.variants.stretched", "Stretched") }
            }
        },
        "music": {
            name: I18n.t("widgets.types.music"),
            icon: String.fromCodePoint(0xF0388),
            category: "media",
            defaultWidth: 340,
            defaultHeight: 120,
            defaultVariant: "full",
            variants: {
                "full":         { file: "faces/music/MusicFace.qml",             icon: "1", label: I18n.t("widgets.variants.full") },
                "round":        { file: "faces/music/MusicFaceRound.qml",        icon: "2", label: I18n.t("widgets.variants.round") },
                "lyrics":       { file: "faces/music/MusicFaceLyrics.qml",       icon: "3", label: I18n.t("widgets.variants.lyrics") },
                "simpleLyrics": { file: "faces/music/MusicFaceLyricsSimple.qml", icon: "4", label: I18n.t("widgets.variants.simpleLyrics", "Simple lyrics") }
            },
            additionalSettings: [
                {
                    id: "lyricsLines",
                    type: "number",
                    property: "lyricsLines",
                    row: "top",
                    variants: ["simpleLyrics"],
                    defaultValue: 1,
                    min: 0,
                    max: 4,
                    step: 1,
                    decimals: 0,
                    specialZeroText: "0",
                    mirrorProperties: ["linesBehind", "linesAfter"]
                },
                {
                    id: "lyricsAlignment",
                    type: "segmented",
                    property: "lyricsAlignment",
                    row: "top",
                    variants: ["lyrics", "simpleLyrics"],
                    defaultValue: "left",
                    width: 160,
                    height: 32,
                    mirrorProperties: ["alignment"],
                    options: [
                        { value: "left", label: I18n.t("widgets.align.left", "Left") },
                        { value: "center", label: I18n.t("widgets.align.center", "Center") },
                        { value: "right", label: I18n.t("widgets.align.right", "Right") }
                    ]
                },
                {
                    id: "hideText",
                    type: "toggle",
                    property: "hideText",
                    label: I18n.t("widgets.settings.hideText", "Hide text"),
                    row: "bottom",
                    variants: ["simpleLyrics"],
                    defaultValue: false
                },
                {
                    id: "continuous",
                    type: "segmented",
                    property: "continuous",
                    row: "top",
                    variants: ["round"],
                    defaultValue: false,
                    width: 190,
                    height: 34,
                    options: [
                        { value: false, label: I18n.t("widgets.variants.bars", "Bars") },
                        { value: true, label: I18n.t("widgets.variants.continuous", "Continuous") }
                    ]
                }
            ]
        },
        "weather": {
            name: I18n.t("widgets.types.weather"),
            icon: String.fromCodePoint(0xF0590),
            category: "info",
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
            category: "media",
            defaultWidth: 300,
            defaultHeight: 200,
            defaultVariant: "rect",
            requiresFilePicker: true,
            picker: { kind: "image", property: "imagePath" },
            variants: {
                "rect":    { file: "faces/image/ImageFaceRect.qml",    icon: "1", label: I18n.t("widgets.variants.rect") },
                "rounded": { file: "faces/image/ImageFaceRounded.qml", icon: "2", label: I18n.t("widgets.variants.rounded") },
                "round":   { file: "faces/image/ImageFaceRound.qml",   icon: "3", label: I18n.t("widgets.variants.round"), circleMask: true }
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
            category: "system",
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
            category: "system",
            defaultWidth: 180,
            defaultHeight: 130,
            defaultVariant: "default",
            variants: {
                "default": { file: "faces/usage/UsageFaceBase.qml",       props: { metric: "cpu" }, icon: "1", label: I18n.t("widgets.variants.default") },
                "circle":  { file: "faces/usage/UsageFaceCircleBase.qml", props: { metric: "cpu" }, icon: "2", label: I18n.t("widgets.variants.circle", "Circle") },
                "graph":   { file: "faces/usage/UsageFaceGraphBase.qml",  props: { metric: "cpu" }, icon: "3", label: I18n.t("widgets.variants.graph", "Graph") }
            },
            additionalSettings: registry.usageGraphSettings
        },
        "ram": {
            name: I18n.t("quickactions.systemusage.ram"),
            icon: String.fromCodePoint(0xF035C),
            category: "system",
            defaultWidth: 180,
            defaultHeight: 130,
            defaultVariant: "default",
            variants: {
                "default": { file: "faces/usage/UsageFaceBase.qml",       props: { metric: "ram" }, icon: "1", label: I18n.t("widgets.variants.default") },
                "circle":  { file: "faces/usage/UsageFaceCircleBase.qml", props: { metric: "ram" }, icon: "2", label: I18n.t("widgets.variants.circle", "Circle") },
                "graph":   { file: "faces/usage/UsageFaceGraphBase.qml",  props: { metric: "ram" }, icon: "3", label: I18n.t("widgets.variants.graph", "Graph") }
            },
            additionalSettings: registry.usageGraphSettings
        },
        "temp": {
            name: I18n.t("quickactions.systemusage.temp"),
            icon: String.fromCodePoint(0xF050F),
            category: "system",
            defaultWidth: 180,
            defaultHeight: 130,
            defaultVariant: "default",
            variants: {
                "default": { file: "faces/usage/UsageFaceBase.qml",       props: { metric: "temp" }, icon: "1", label: I18n.t("widgets.variants.default") },
                "circle":  { file: "faces/usage/UsageFaceCircleBase.qml", props: { metric: "temp" }, icon: "2", label: I18n.t("widgets.variants.circle", "Circle") },
                "graph":   { file: "faces/usage/UsageFaceGraphBase.qml",  props: { metric: "temp" }, icon: "3", label: I18n.t("widgets.variants.graph", "Graph") }
            },
            additionalSettings: registry.usageGraphSettings
        },
        "disk": {
            name: I18n.t("quickactions.systemusage.disk"),
            icon: String.fromCodePoint(0xF02CA),
            category: "system",
            defaultWidth: 180,
            defaultHeight: 130,
            defaultVariant: "default",
            variants: {
                "default": { file: "faces/usage/UsageFaceBase.qml",       props: { metric: "disk" }, icon: "1", label: I18n.t("widgets.variants.default") },
                "circle":  { file: "faces/usage/UsageFaceCircleBase.qml", props: { metric: "disk" }, icon: "2", label: I18n.t("widgets.variants.circle", "Circle") }
            },
            additionalSettings: registry.usageCircleSettings
        },
        "battery": {
            name: I18n.t("widgets.types.battery"),
            icon: String.fromCodePoint(0xF0079),
            category: "system",
            defaultWidth: 260,
            defaultHeight: 90,
            defaultVariant: "default",
            variants: {
                "default": { file: "faces/battery/BatteryFace.qml", icon: "1", label: I18n.t("widgets.variants.default") },
                "circle":  { file: "faces/battery/BatteryFaceCircle.qml", icon: "2", label: I18n.t("widgets.variants.circle", "Circle") }
            },
            additionalSettings: registry.usageCircleSettings
        },
        "github": {
            name: I18n.t("widgets.types.github", "GitHub"),
            icon: String.fromCodePoint(0xF02A4),
            category: "info",
            defaultWidth: 540,
            defaultHeight: 180,
            defaultVariant: "default",
            variants: {
                "default": { file: "faces/github/GithubFace.qml", icon: "1", label: I18n.t("widgets.variants.default", "Default") }
            }
        },
        "notes": {
            name: I18n.t("widgets.types.notes", "Notes"),
            icon: String.fromCodePoint(0xF039E),
            category: "time",
            defaultWidth: 300,
            defaultHeight: 280,
            defaultVariant: "default",
            variants: {
                "default": { file: "faces/notes/NotesFace.qml", icon: "1", label: I18n.t("widgets.variants.default", "Default") }
            }
        },
        "timer": {
            name: I18n.t("quickactions.tabs.timer", "Timer"),
            icon: String.fromCodePoint(0xF051B),
            category: "time",
            defaultWidth: 360,
            defaultHeight: 280,
            defaultVariant: "timer",
            variants: {
                "timer":     { file: "faces/timer/TimerFace.qml", props: { fixedMode: 0 }, icon: "1", label: I18n.t("quickactions.timer.tabs.timer", "Timer") },
                "stopwatch": { file: "faces/timer/TimerFace.qml", props: { fixedMode: 1 }, icon: "2", label: I18n.t("quickactions.timer.tabs.stopwatch", "Stopwatch") },
                "pomodoro":  { file: "faces/timer/TimerFace.qml", props: { fixedMode: 2 }, icon: "3", label: I18n.t("quickactions.timer.tabs.pomodoro", "Pomodoro") }
            }
        },
        "text": {
            name: I18n.t("widgets.types.text", "Text"),
            icon: String.fromCodePoint(0xF0284),
            category: "time",
            defaultWidth: 320,
            defaultHeight: 90,
            defaultVariant: "default",
            variants: {
                "default": { file: "faces/text/TextFace.qml", icon: "1", label: I18n.t("widgets.variants.default", "Default") }
            },
            additionalSettings: [
                {
                    id: "textContent",
                    type: "text",
                    property: "textContent",
                    placeholder: I18n.t("widgets.text.placeholder", "Enter text"),
                    row: "bottom",
                    defaultValue: "",
                    width: 240
                },
                {
                    id: "fontFamily",
                    type: "font",
                    property: "fontFamily",
                    placeholder: I18n.t("guide.theme.font.select"),
                    defaultLabel: I18n.t("widgets.variants.default", "Default"),
                    row: "top",
                    defaultValue: "",
                    width: 200
                }
            ]
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

    function _variantEntry(type, variant) {
        let t = types[type];
        if (!t || !t.variants) return null;
        return t.variants[variant] || t.variants[t.defaultVariant] || null;
    }

    function faceFile(type, variant) {
        let v = _variantEntry(type, variant);
        return v ? Qt.resolvedUrl(v.file) : "";
    }

    function variantProps(type, variant) {
        let v = _variantEntry(type, variant);
        return (v && v.props) ? v.props : null;
    }

    function variantCircleMask(type, variant) {
        let v = _variantEntry(type, variant);
        return !!(v && v.circleMask);
    }

    function pickerFor(type) {
        let t = types[type];
        return (t && t.picker) ? t.picker : null;
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
