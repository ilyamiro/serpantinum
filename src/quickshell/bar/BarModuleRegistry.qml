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
            defaultVariant: "button",
            face: "faces/left/LeftFace.qml",
            variants: {
                "button": {
                    id: "button",
                    name: typeof I18n !== "undefined" ? I18n.t("guide.bar.menu.style.name.button", "Button") : "Button",
                    desc: typeof I18n !== "undefined" ? I18n.t("guide.bar.menu.style.button", "Interactive icon buttons with background") : "Interactive icon buttons with background",
                    icon: "󰍜",
                    face: "faces/left/LeftFace.qml"
                },
                "icon": {
                    id: "icon",
                    name: typeof I18n !== "undefined" ? I18n.t("guide.bar.menu.style.name.icon", "Icon") : "Icon",
                    desc: typeof I18n !== "undefined" ? I18n.t("guide.bar.menu.style.icon", "Clean icons without background") : "Clean icons without background",
                    icon: "󰍜",
                    face: "faces/left/LeftFace.qml"
                }
            }
        },
        "workspaces": {
            name: typeof I18n !== "undefined" ? I18n.t("guide.bar.modules.workspaces.name", "Workspaces") : "Workspaces",
            icon: "󰮯",
            defaultVariant: "pills",
            face: "faces/workspaces/WorkspacesFace.qml",
            variants: {
                "pills": {
                    id: "pills",
                    name: typeof I18n !== "undefined" ? I18n.t("guide.bar.modules.workspaces.style.name.pills", "Pills") : "Pills",
                    desc: typeof I18n !== "undefined" ? I18n.t("guide.bar.modules.workspaces.style.pills", "Minimal pill indicators") : "Minimal pill indicators",
                    icon: "󰮯",
                    face: "faces/workspaces/PillsFace.qml"
                },
                "numbers": {
                    id: "numbers",
                    name: typeof I18n !== "undefined" ? I18n.t("guide.bar.modules.workspaces.style.name.numbers", "Numbers") : "Numbers",
                    desc: typeof I18n !== "undefined" ? I18n.t("guide.bar.modules.workspaces.style.numbers", "Numbered indices") : "Numbered indices",
                    icon: "󰎦",
                    face: "faces/workspaces/NumbersFace.qml"
                },
                "pacman": {
                    id: "pacman",
                    name: typeof I18n !== "undefined" ? I18n.t("guide.bar.modules.workspaces.style.name.pacman", "Pacman") : "Pacman",
                    desc: typeof I18n !== "undefined" ? I18n.t("guide.bar.modules.workspaces.style.pacman", "Animated arcade dots") : "Animated arcade dots",
                    icon: "󰮯",
                    face: "faces/workspaces/PacmanFace.qml"
                }
            }
        },
        "focus": {
            name: typeof I18n !== "undefined" ? I18n.t("guide.bar.modules.focus", "Focus") : "Focus",
            icon: "󰈈",
            defaultVariant: "default",
            face: "faces/focus/FocusFace.qml"
        },
        "media": {
            name: typeof I18n !== "undefined" ? I18n.t("guide.bar.modules.media", "Media") : "Media",
            icon: "󰎈",
            defaultVariant: "default",
            face: "faces/media/MediaFace.qml"
        },
        "vis": {
            name: typeof I18n !== "undefined" ? I18n.t("guide.bar.modules.vis", "Visualizer") : "Visualizer",
            icon: "󰝚",
            defaultVariant: "default",
            face: "faces/vis/VisFace.qml"
        },
        "tray": {
            name: typeof I18n !== "undefined" ? I18n.t("guide.bar.modules.tray", "System Tray") : "System Tray",
            icon: "󱊞",
            defaultVariant: "default",
            face: "faces/tray/TrayFace.qml"
        },
        "timedate": {
            name: typeof I18n !== "undefined" ? I18n.t("guide.bar.modules.timedate.name", "Time & Date") : "Time & Date",
            icon: "󰃰",
            defaultVariant: "classic",
            face: "faces/timedate/TimeDateFace.qml",
            variants: {
                "classic": {
                    id: "classic",
                    name: typeof I18n !== "undefined" ? I18n.t("guide.bar.modules.timedate.style.name.classic", "Classic") : "Classic",
                    desc: typeof I18n !== "undefined" ? I18n.t("guide.bar.modules.timedate.style.classic", "Clean stacked time and date") : "Clean stacked time and date",
                    icon: "󰥔",
                    face: "faces/timedate/ClassicFace.qml"
                },
                "material": {
                    id: "material",
                    name: typeof I18n !== "undefined" ? I18n.t("guide.bar.modules.timedate.style.name.material", "Material") : "Material",
                    desc: typeof I18n !== "undefined" ? I18n.t("guide.bar.modules.timedate.style.material", "Diagonal bold accent numbers") : "Diagonal bold accent numbers",
                    icon: "󰸗",
                    face: "faces/timedate/MaterialFace.qml"
                },
                "badge": {
                    id: "badge",
                    name: typeof I18n !== "undefined" ? I18n.t("guide.bar.modules.timedate.style.name.badge", "Badge") : "Badge",
                    desc: typeof I18n !== "undefined" ? I18n.t("guide.bar.modules.timedate.style.badge", "Pill-capsule segmented cards") : "Pill-capsule segmented cards",
                    icon: "󰃰",
                    face: "faces/timedate/BadgeFace.qml"
                }
            }
        },
        "info": {
            name: typeof I18n !== "undefined" ? I18n.t("guide.bar.modules.info", "Info") : "Info",
            icon: "󰋼",
            defaultVariant: "default",
            face: "faces/info/InfoFace.qml"
        },
        "weather": {
            name: typeof I18n !== "undefined" ? I18n.t("guide.bar.modules.weather", "Weather") : "Weather",
            icon: "󰖐",
            defaultVariant: "default",
            face: "faces/weather/WeatherFace.qml"
        },
        "sysmon": {
            name: typeof I18n !== "undefined" ? I18n.t("guide.bar.modules.sysmon", "System Monitor") : "System Monitor",
            icon: "󰍛",
            defaultVariant: "default",
            face: "faces/sysmon/SysMonFace.qml"
        },
        "kb": {
            name: typeof I18n !== "undefined" ? I18n.t("guide.bar.modules.keyboard", "Keyboard") : "Keyboard",
            icon: "󰌌",
            defaultVariant: "button",
            face: "faces/kb/KbFace.qml",
            variants: {
                "button": {
                    id: "button",
                    name: typeof I18n !== "undefined" ? I18n.t("guide.bar.kb.style.name.button", "Button") : "Button",
                    desc: typeof I18n !== "undefined" ? I18n.t("guide.bar.kb.style.button", "Interactive button pill with background") : "Interactive button pill with background",
                    icon: "󰌌",
                    face: "faces/kb/KbFace.qml"
                },
                "text": {
                    id: "text",
                    name: typeof I18n !== "undefined" ? I18n.t("guide.bar.kb.style.name.text", "Text") : "Text",
                    desc: typeof I18n !== "undefined" ? I18n.t("guide.bar.kb.style.text", "Clean text and icon without background") : "Clean text and icon without background",
                    icon: "󰌌",
                    face: "faces/kb/KbFace.qml"
                }
            }
        },
        "wifi": {
            name: typeof I18n !== "undefined" ? I18n.t("guide.bar.modules.network", "Network") : "Network",
            icon: "󰤨",
            defaultVariant: "button",
            face: "faces/wifi/WifiFace.qml",
            variants: {
                "button": {
                    id: "button",
                    name: typeof I18n !== "undefined" ? I18n.t("guide.bar.wifi.style.name.button", "Button") : "Button",
                    desc: typeof I18n !== "undefined" ? I18n.t("guide.bar.wifi.style.button", "Interactive button pill with background") : "Interactive button pill with background",
                    icon: "󰤨",
                    face: "faces/wifi/WifiFace.qml"
                },
                "text": {
                    id: "text",
                    name: typeof I18n !== "undefined" ? I18n.t("guide.bar.wifi.style.name.text", "Text") : "Text",
                    desc: typeof I18n !== "undefined" ? I18n.t("guide.bar.wifi.style.text", "Clean text and icon without background") : "Clean text and icon without background",
                    icon: "󰤨",
                    face: "faces/wifi/WifiFace.qml"
                }
            }
        },
        "bt": {
            name: typeof I18n !== "undefined" ? I18n.t("guide.bar.modules.bluetooth", "Bluetooth") : "Bluetooth",
            icon: "󰂲",
            defaultVariant: "button",
            face: "faces/bt/BtFace.qml",
            variants: {
                "button": {
                    id: "button",
                    name: typeof I18n !== "undefined" ? I18n.t("guide.bar.bt.style.name.button", "Button") : "Button",
                    desc: typeof I18n !== "undefined" ? I18n.t("guide.bar.bt.style.button", "Interactive button pill with background") : "Interactive button pill with background",
                    icon: "󰂲",
                    face: "faces/bt/BtFace.qml"
                },
                "text": {
                    id: "text",
                    name: typeof I18n !== "undefined" ? I18n.t("guide.bar.bt.style.name.text", "Text") : "Text",
                    desc: typeof I18n !== "undefined" ? I18n.t("guide.bar.bt.style.text", "Clean text and icon without background") : "Clean text and icon without background",
                    icon: "󰂲",
                    face: "faces/bt/BtFace.qml"
                }
            }
        },
        "vol": {
            name: typeof I18n !== "undefined" ? I18n.t("guide.bar.modules.volume", "Volume") : "Volume",
            icon: "󰕾",
            defaultVariant: "button",
            face: "faces/vol/VolFace.qml",
            variants: {
                "button": {
                    id: "button",
                    name: typeof I18n !== "undefined" ? I18n.t("guide.bar.vol.style.name.button", "Button") : "Button",
                    desc: typeof I18n !== "undefined" ? I18n.t("guide.bar.vol.style.button", "Interactive button pill with background") : "Interactive button pill with background",
                    icon: "󰕾",
                    face: "faces/vol/VolFace.qml"
                },
                "text": {
                    id: "text",
                    name: typeof I18n !== "undefined" ? I18n.t("guide.bar.vol.style.name.text", "Text") : "Text",
                    desc: typeof I18n !== "undefined" ? I18n.t("guide.bar.vol.style.text", "Clean text and icon without background") : "Clean text and icon without background",
                    icon: "󰕾",
                    face: "faces/vol/VolFace.qml"
                }
            }
        },
        "bat": {
            name: typeof I18n !== "undefined" ? I18n.t("guide.bar.modules.battery", "Battery") : "Battery",
            icon: "󰁹",
            defaultVariant: "classic",
            face: "faces/bat/BatFace.qml",
            variants: {
                "classic": {
                    id: "classic",
                    name: typeof I18n !== "undefined" ? I18n.t("guide.bar.bat.style.name.classic", "Classic") : "Classic",
                    desc: typeof I18n !== "undefined" ? I18n.t("guide.bar.bat.style.classic", "Pill with gradient wave fill") : "Pill with gradient wave fill",
                    icon: "󰁹",
                    face: "faces/bat/BatFace.qml"
                },
                "minimal": {
                    id: "minimal",
                    name: typeof I18n !== "undefined" ? I18n.t("guide.bar.bat.style.name.minimal", "Minimal") : "Minimal",
                    desc: typeof I18n !== "undefined" ? I18n.t("guide.bar.bat.style.minimal", "iOS/Android capsule with cap") : "iOS/Android capsule with cap",
                    icon: "󰂄",
                    face: "faces/bat/BatFace.qml"
                },
                "text": {
                    id: "text",
                    name: typeof I18n !== "undefined" ? I18n.t("guide.bar.bat.style.name.text", "Text") : "Text",
                    desc: typeof I18n !== "undefined" ? I18n.t("guide.bar.bat.style.text", "Clean text and icon without background") : "Clean text and icon without background",
                    icon: "󰁹",
                    face: "faces/bat/BatFace.qml"
                },
                "button": {
                    id: "button",
                    name: typeof I18n !== "undefined" ? I18n.t("guide.bar.bat.style.name.button", "Button") : "Button",
                    desc: typeof I18n !== "undefined" ? I18n.t("guide.bar.bat.style.button", "Interactive button pill with background") : "Interactive button pill with background",
                    icon: "󰂄",
                    face: "faces/bat/BatFace.qml"
                }
            }
        }
    })

    function getModuleVariant(moduleId) {
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
        if (norm === "left") {
            if (bs.menuStyle) return bs.menuStyle;
            return "button";
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

    function faceFile(moduleId, variant) {
        let norm = normalizeId(moduleId);
        let t = types[norm];
        if (!t) return "";

        let vKey = (variant !== undefined && variant !== null && variant !== "") ? variant : getModuleVariant(norm);
        let v = (t.variants && t.variants[vKey]) ? t.variants[vKey] : null;

        let file = t.face || (v ? v.face : "");
        return file ? Qt.resolvedUrl(file) : "";
    }

    function variantFaceFile(moduleId, variant) {
        let norm = normalizeId(moduleId);
        let t = types[norm];
        if (!t || !t.variants) return faceFile(norm, variant);
        let vKey = variant || getModuleVariant(norm);
        let v = t.variants[vKey] || t.variants[t.defaultVariant];
        if (!v || !v.face) return "";
        return Qt.resolvedUrl(v.face);
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
