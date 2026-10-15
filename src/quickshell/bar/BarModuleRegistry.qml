pragma Singleton
import QtQuick
import Quickshell
import "../"

QtObject {
    id: registry

    function normalizeId(id) {
        if (!id) return "";
        let s = String(id).toLowerCase().trim();
        if (s === "timedate" || s === "time" || s === "clock") return "timedate";
        if (s === "info" || s === "indicator" || s === "indicators" || s === "record") return "info";
        if (s === "volume" || s === "vol") return "vol";
        if (s === "battery" || s === "bat") return "bat";
        if (s === "visualizer" || s === "viswidget" || s === "vis") return "vis";
        if (s === "top" || s === "left") return "left";
        return s;
    }

    property var types: ({
        "left": {
            name: typeof I18n !== "undefined" ? I18n.t("guide.bar.modules.actions", "Menu") : "Menu",
            icon: "󰍜",
            defaultVariant: "default",
            horizontalFace: "faces/left/LeftFace.qml",
            verticalFace: "faces/left/SideLeftFace.qml"
        },
        "workspaces": {
            name: typeof I18n !== "undefined" ? I18n.t("guide.bar.modules.workspaces.name", "Workspaces") : "Workspaces",
            icon: "󰮯",
            defaultVariant: "pills",
            horizontalFace: "faces/workspaces/WorkspacesFace.qml",
            verticalFace: "faces/workspaces/SideWorkspacesFace.qml",
            variants: {
                "pills": {
                    id: "pills",
                    name: typeof I18n !== "undefined" ? I18n.t("guide.bar.modules.workspaces.style.name.pills", "Pills") : "Pills",
                    desc: typeof I18n !== "undefined" ? I18n.t("guide.bar.modules.workspaces.style.pills", "Minimal pill indicators") : "Minimal pill indicators",
                    icon: "󰮯",
                    horizontalFace: "faces/workspaces/PillsFace.qml",
                    verticalFace: "faces/workspaces/SidePillsFace.qml",
                    faceFile: "faces/workspaces/PillsFace.qml"
                },
                "numbers": {
                    id: "numbers",
                    name: typeof I18n !== "undefined" ? I18n.t("guide.bar.modules.workspaces.style.name.numbers", "Numbers") : "Numbers",
                    desc: typeof I18n !== "undefined" ? I18n.t("guide.bar.modules.workspaces.style.numbers", "Numbered indices") : "Numbered indices",
                    icon: "󰎦",
                    horizontalFace: "faces/workspaces/NumbersFace.qml",
                    verticalFace: "faces/workspaces/SideNumbersFace.qml",
                    faceFile: "faces/workspaces/NumbersFace.qml"
                },
                "pacman": {
                    id: "pacman",
                    name: typeof I18n !== "undefined" ? I18n.t("guide.bar.modules.workspaces.style.name.pacman", "Pacman") : "Pacman",
                    desc: typeof I18n !== "undefined" ? I18n.t("guide.bar.modules.workspaces.style.pacman", "Animated arcade dots") : "Animated arcade dots",
                    icon: "󰮯",
                    horizontalFace: "faces/workspaces/PacmanFace.qml",
                    verticalFace: "faces/workspaces/SidePacmanFace.qml",
                    faceFile: "faces/workspaces/PacmanFace.qml"
                }
            }
        },
        "focus": {
            name: typeof I18n !== "undefined" ? I18n.t("guide.bar.modules.focus", "Focus") : "Focus",
            icon: "󰈈",
            defaultVariant: "default",
            horizontalFace: "faces/focus/FocusFace.qml",
            verticalFace: "faces/focus/SideFocusFace.qml"
        },
        "media": {
            name: typeof I18n !== "undefined" ? I18n.t("guide.bar.modules.media", "Media") : "Media",
            icon: "󰎈",
            defaultVariant: "default",
            horizontalFace: "faces/media/MediaFace.qml",
            verticalFace: "faces/media/SideMediaFace.qml"
        },
        "vis": {
            name: typeof I18n !== "undefined" ? I18n.t("guide.bar.modules.vis", "Visualizer") : "Visualizer",
            icon: "󰝚",
            defaultVariant: "default",
            horizontalFace: "faces/vis/VisFace.qml",
            verticalFace: "faces/vis/SideVisFace.qml"
        },
        "tray": {
            name: typeof I18n !== "undefined" ? I18n.t("guide.bar.modules.tray", "System Tray") : "System Tray",
            icon: "󱊞",
            defaultVariant: "default",
            horizontalFace: "faces/tray/TrayFace.qml",
            verticalFace: "faces/tray/SideTrayFace.qml"
        },
        "timedate": {
            name: typeof I18n !== "undefined" ? I18n.t("guide.bar.modules.timedate.name", "Time & Date") : "Time & Date",
            icon: "󰃰",
            defaultVariant: "classic",
            horizontalFace: "faces/timedate/TimeDateFace.qml",
            verticalFace: "faces/timedate/SideTimeDateFace.qml",
            variants: {
                "classic": {
                    id: "classic",
                    name: typeof I18n !== "undefined" ? I18n.t("guide.bar.modules.timedate.style.name.classic", "Classic") : "Classic",
                    desc: typeof I18n !== "undefined" ? I18n.t("guide.bar.modules.timedate.style.classic", "Clean stacked time and date") : "Clean stacked time and date",
                    icon: "󰥔",
                    horizontalFace: "faces/timedate/ClassicFace.qml",
                    verticalFace: "faces/timedate/SideClassicFace.qml",
                    faceFile: "faces/timedate/ClassicFace.qml"
                },
                "material": {
                    id: "material",
                    name: typeof I18n !== "undefined" ? I18n.t("guide.bar.modules.timedate.style.name.material", "Material") : "Material",
                    desc: typeof I18n !== "undefined" ? I18n.t("guide.bar.modules.timedate.style.material", "Diagonal bold accent numbers") : "Diagonal bold accent numbers",
                    icon: "󰸗",
                    horizontalFace: "faces/timedate/MaterialFace.qml",
                    verticalFace: "faces/timedate/SideMaterialFace.qml",
                    faceFile: "faces/timedate/MaterialFace.qml"
                },
                "badge": {
                    id: "badge",
                    name: typeof I18n !== "undefined" ? I18n.t("guide.bar.modules.timedate.style.name.badge", "Badge") : "Badge",
                    desc: typeof I18n !== "undefined" ? I18n.t("guide.bar.modules.timedate.style.badge", "Pill-capsule segmented cards") : "Pill-capsule segmented cards",
                    icon: "󰃰",
                    horizontalFace: "faces/timedate/BadgeFace.qml",
                    verticalFace: "faces/timedate/SideBadgeFace.qml",
                    faceFile: "faces/timedate/BadgeFace.qml"
                }
            }
        },
        "info": {
            name: typeof I18n !== "undefined" ? I18n.t("guide.bar.modules.info", "Info") : "Info",
            icon: "󰋼",
            defaultVariant: "default",
            horizontalFace: "faces/info/InfoFace.qml",
            verticalFace: "faces/info/SideInfoFace.qml"
        },
        "weather": {
            name: typeof I18n !== "undefined" ? I18n.t("guide.bar.modules.weather", "Weather") : "Weather",
            icon: "󰖐",
            defaultVariant: "default",
            horizontalFace: "faces/weather/WeatherFace.qml",
            verticalFace: "faces/weather/SideWeatherFace.qml"
        },
        "sysmon": {
            name: typeof I18n !== "undefined" ? I18n.t("guide.bar.modules.sysmon", "System Monitor") : "System Monitor",
            icon: "󰍛",
            defaultVariant: "default",
            horizontalFace: "faces/sysmon/SysMonFace.qml",
            verticalFace: "faces/sysmon/SideSysMonFace.qml"
        },
        "kb": {
            name: typeof I18n !== "undefined" ? I18n.t("guide.bar.modules.keyboard", "Keyboard") : "Keyboard",
            icon: "󰌌",
            defaultVariant: "button",
            horizontalFace: "faces/kb/KbFace.qml",
            verticalFace: "faces/kb/SideKbFace.qml",
            variants: {
                "button": {
                    id: "button",
                    name: typeof I18n !== "undefined" ? I18n.t("guide.bar.kb.style.name.button", "Button") : "Button",
                    desc: typeof I18n !== "undefined" ? I18n.t("guide.bar.kb.style.button", "Interactive button pill with background") : "Interactive button pill with background",
                    icon: "󰌌",
                    horizontalFace: "faces/kb/KbFace.qml",
                    verticalFace: "faces/kb/SideKbFace.qml"
                },
                "text": {
                    id: "text",
                    name: typeof I18n !== "undefined" ? I18n.t("guide.bar.kb.style.name.text", "Text") : "Text",
                    desc: typeof I18n !== "undefined" ? I18n.t("guide.bar.kb.style.text", "Clean text and icon without background") : "Clean text and icon without background",
                    icon: "󰌌",
                    horizontalFace: "faces/kb/KbFace.qml",
                    verticalFace: "faces/kb/SideKbFace.qml"
                }
            }
        },
        "wifi": {
            name: typeof I18n !== "undefined" ? I18n.t("guide.bar.modules.network", "Network") : "Network",
            icon: "󰤨",
            defaultVariant: "button",
            horizontalFace: "faces/wifi/WifiFace.qml",
            verticalFace: "faces/wifi/SideWifiFace.qml",
            variants: {
                "button": {
                    id: "button",
                    name: typeof I18n !== "undefined" ? I18n.t("guide.bar.wifi.style.name.button", "Button") : "Button",
                    desc: typeof I18n !== "undefined" ? I18n.t("guide.bar.wifi.style.button", "Interactive button pill with background") : "Interactive button pill with background",
                    icon: "󰤨",
                    horizontalFace: "faces/wifi/WifiFace.qml",
                    verticalFace: "faces/wifi/SideWifiFace.qml"
                },
                "text": {
                    id: "text",
                    name: typeof I18n !== "undefined" ? I18n.t("guide.bar.wifi.style.name.text", "Text") : "Text",
                    desc: typeof I18n !== "undefined" ? I18n.t("guide.bar.wifi.style.text", "Clean text and icon without background") : "Clean text and icon without background",
                    icon: "󰤨",
                    horizontalFace: "faces/wifi/WifiFace.qml",
                    verticalFace: "faces/wifi/SideWifiFace.qml"
                }
            }
        },
        "bt": {
            name: typeof I18n !== "undefined" ? I18n.t("guide.bar.modules.bluetooth", "Bluetooth") : "Bluetooth",
            icon: "󰂲",
            defaultVariant: "button",
            horizontalFace: "faces/bt/BtFace.qml",
            verticalFace: "faces/bt/SideBtFace.qml",
            variants: {
                "button": {
                    id: "button",
                    name: typeof I18n !== "undefined" ? I18n.t("guide.bar.bt.style.name.button", "Button") : "Button",
                    desc: typeof I18n !== "undefined" ? I18n.t("guide.bar.bt.style.button", "Interactive button pill with background") : "Interactive button pill with background",
                    icon: "󰂲",
                    horizontalFace: "faces/bt/BtFace.qml",
                    verticalFace: "faces/bt/SideBtFace.qml"
                },
                "text": {
                    id: "text",
                    name: typeof I18n !== "undefined" ? I18n.t("guide.bar.bt.style.name.text", "Text") : "Text",
                    desc: typeof I18n !== "undefined" ? I18n.t("guide.bar.bt.style.text", "Clean text and icon without background") : "Clean text and icon without background",
                    icon: "󰂲",
                    horizontalFace: "faces/bt/BtFace.qml",
                    verticalFace: "faces/bt/SideBtFace.qml"
                }
            }
        },
        "vol": {
            name: typeof I18n !== "undefined" ? I18n.t("guide.bar.modules.volume", "Volume") : "Volume",
            icon: "󰕾",
            defaultVariant: "button",
            horizontalFace: "faces/vol/VolFace.qml",
            verticalFace: "faces/vol/SideVolFace.qml",
            variants: {
                "button": {
                    id: "button",
                    name: typeof I18n !== "undefined" ? I18n.t("guide.bar.vol.style.name.button", "Button") : "Button",
                    desc: typeof I18n !== "undefined" ? I18n.t("guide.bar.vol.style.button", "Interactive button pill with background") : "Interactive button pill with background",
                    icon: "󰕾",
                    horizontalFace: "faces/vol/VolFace.qml",
                    verticalFace: "faces/vol/SideVolFace.qml"
                },
                "text": {
                    id: "text",
                    name: typeof I18n !== "undefined" ? I18n.t("guide.bar.vol.style.name.text", "Text") : "Text",
                    desc: typeof I18n !== "undefined" ? I18n.t("guide.bar.vol.style.text", "Clean text and icon without background") : "Clean text and icon without background",
                    icon: "󰕾",
                    horizontalFace: "faces/vol/VolFace.qml",
                    verticalFace: "faces/vol/SideVolFace.qml"
                }
            }
        },
        "bat": {
            name: typeof I18n !== "undefined" ? I18n.t("guide.bar.modules.battery", "Battery") : "Battery",
            icon: "󰁹",
            defaultVariant: "classic",
            horizontalFace: "faces/bat/BatFace.qml",
            verticalFace: "faces/bat/SideBatFace.qml",
            variants: {
                "classic": {
                    id: "classic",
                    name: typeof I18n !== "undefined" ? I18n.t("guide.bar.bat.style.name.classic", "Classic") : "Classic",
                    desc: typeof I18n !== "undefined" ? I18n.t("guide.bar.bat.style.classic", "Pill with gradient wave fill") : "Pill with gradient wave fill",
                    icon: "󰁹",
                    horizontalFace: "faces/bat/BatFace.qml",
                    verticalFace: "faces/bat/SideBatFace.qml"
                },
                "minimal": {
                    id: "minimal",
                    name: typeof I18n !== "undefined" ? I18n.t("guide.bar.bat.style.name.minimal", "Minimal") : "Minimal",
                    desc: typeof I18n !== "undefined" ? I18n.t("guide.bar.bat.style.minimal", "iOS/Android capsule with cap") : "iOS/Android capsule with cap",
                    icon: "󰂄",
                    horizontalFace: "faces/bat/BatFace.qml",
                    verticalFace: "faces/bat/SideBatFace.qml"
                },
                "text": {
                    id: "text",
                    name: typeof I18n !== "undefined" ? I18n.t("guide.bar.bat.style.name.text", "Text") : "Text",
                    desc: typeof I18n !== "undefined" ? I18n.t("guide.bar.bat.style.text", "Clean text and icon without background") : "Clean text and icon without background",
                    icon: "󰁹",
                    horizontalFace: "faces/bat/BatFace.qml",
                    verticalFace: "faces/bat/SideBatFace.qml"
                }
            }
        }
    })

    function getModuleVariant(moduleId, isSide) {
        let norm = normalizeId(moduleId);
        let bs = (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar) ? Config.rawSettings.bar : {};

        if (norm === "workspaces") {
            if (bs.workspacesStyle) return bs.workspacesStyle;
            return "pills";
        }
        if (norm === "timedate") {
            if (bs.timeStyle) return bs.timeStyle;
            return "classic";
        }
        if (norm === "wifi") {
            if (bs.wifiStyle) return bs.wifiStyle;
            return "button";
        }
        if (norm === "bt") {
            if (bs.btStyle) return bs.btStyle;
            return "button";
        }
        if (norm === "vol") {
            if (bs.volStyle) return bs.volStyle;
            return "button";
        }
        if (norm === "kb") {
            if (bs.kbStyle) return bs.kbStyle;
            return "button";
        }
        if (norm === "bat") {
            if (bs.batStyle) return bs.batStyle;
            return "classic";
        }

        let t = types[norm];
        return t ? (t.defaultVariant || "default") : "default";
    }

    function faceFile(moduleId, variant, isSide) {
        let norm = normalizeId(moduleId);
        let t = types[norm];
        if (!t) return "";

        let vKey = (variant !== undefined && variant !== null && variant !== "") ? variant : getModuleVariant(norm, isSide);
        let v = (t.variants && t.variants[vKey]) ? t.variants[vKey] : null;

        let file = "";
        if (isSide) {
            file = t.verticalFace || (v ? v.verticalFace : "");
        } else {
            file = t.horizontalFace || (v ? v.horizontalFace : "");
        }
        return file ? Qt.resolvedUrl(file) : "";
    }

    function variantFaceFile(moduleId, variant, isSide) {
        let norm = normalizeId(moduleId);
        let t = types[norm];
        if (!t || !t.variants) return faceFile(norm, variant, isSide);
        let vKey = variant || getModuleVariant(norm, isSide);
        let v = t.variants[vKey] || t.variants[t.defaultVariant];
        if (!v) return "";
        let file = isSide ? (v.verticalFace || v.faceFile || v.horizontalFace) : (v.horizontalFace || v.faceFile);
        return file ? Qt.resolvedUrl(file) : "";
    }

    function moduleIds() {
        return Object.keys(types);
    }

    function moduleList() {
        return Object.keys(types).map(k => Object.assign({ id: k }, types[k]));
    }

    function variantList(moduleId) {
        let norm = normalizeId(moduleId);
        let t = types[norm];
        if (!t || !t.variants) return [];
        return Object.keys(t.variants).map(k => Object.assign({ id: k }, t.variants[k]));
    }

    function defaultVariant(moduleId) {
        let norm = normalizeId(moduleId);
        let t = types[norm];
        return t ? (t.defaultVariant || "default") : "default";
    }

    function moduleZ(moduleId) {
        let norm = normalizeId(moduleId);
        if (norm === "timedate" || norm === "info" || norm === "weather") return 10;
        return 1;
    }

    function registerModule(moduleId, def) {
        if (!moduleId || !def) return;
        let updated = Object.assign({}, types);
        updated[moduleId] = def;
        types = updated;
    }

    function unregisterModule(moduleId) {
        if (!types[moduleId]) return;
        let updated = Object.assign({}, types);
        delete updated[moduleId];
        types = updated;
    }
}
