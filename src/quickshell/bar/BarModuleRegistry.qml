pragma Singleton
import QtQuick
import Quickshell
import "../"

QtObject {
    id: registry

    function normalizeId(id) {
        if (!id) return "";
        let s = String(id).toLowerCase().trim();
        if (types[s]) return s;
        let keys = Object.keys(types);
        for (let i = 0; i < keys.length; i++) {
            let k = keys[i];
            let aliases = types[k] && types[k].aliases;
            if (Array.isArray(aliases) && aliases.indexOf(s) !== -1) return k;
        }
        return s;
    }

    property var types: ({
        "left": {
            name: typeof I18n !== "undefined" ? I18n.t("guide.bar.modules.actions", "Menu") : "Menu",
            icon: "󰍜",
            defaultVariant: "button",
            styleKey: "menuStyle",
            z: 1,
            aliases: ["top"],
            groupable: true,
            defaultZone: "left",
            expandGroupCross: true,
            face: "faces/left/ActionsFace.qml",
            variants: {
                "button": {
                    id: "button",
                    name: typeof I18n !== "undefined" ? I18n.t("guide.bar.menu.style.name.button", "Button") : "Button",
                    desc: typeof I18n !== "undefined" ? I18n.t("guide.bar.menu.style.button", "Interactive icon buttons with background") : "Interactive icon buttons with background",
                    icon: "󰍜",
                    face: "faces/left/ActionsFace.qml"
                },
                "icon": {
                    id: "icon",
                    name: typeof I18n !== "undefined" ? I18n.t("guide.bar.menu.style.name.icon", "Icon") : "Icon",
                    desc: typeof I18n !== "undefined" ? I18n.t("guide.bar.menu.style.icon", "Clean icons without background") : "Clean icons without background",
                    icon: "󰍜",
                    face: "faces/left/ActionsFace.qml"
                }
            }
        },
        "workspaces": {
            name: typeof I18n !== "undefined" ? I18n.t("guide.bar.modules.workspaces.name", "Workspaces") : "Workspaces",
            icon: "󰮯",
            defaultVariant: "pills",
            styleKey: "workspacesStyle",
            z: 1,
            aliases: [],
            groupable: true,
            defaultZone: "left",
            expandGroupCross: true,
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
                },
                "morph": {
                    id: "morph",
                    name: typeof I18n !== "undefined" ? I18n.t("guide.bar.modules.workspaces.style.name.morph", "Morph") : "Morph",
                    desc: typeof I18n !== "undefined" ? I18n.t("guide.bar.modules.workspaces.style.morph", "Expressive morphing shapes") : "Expressive morphing shapes",
                    icon: "󰠱",
                    face: "faces/workspaces/MorphFace.qml"
                },
                "trace": {
                    id: "trace",
                    name: typeof I18n !== "undefined" ? I18n.t("guide.bar.modules.workspaces.style.name.trace", "Trace") : "Trace",
                    desc: typeof I18n !== "undefined" ? I18n.t("guide.bar.modules.workspaces.style.trace", "Connected nodes with traveling pulse") : "Connected nodes with traveling pulse",
                    icon: "󰌗",
                    face: "faces/workspaces/TraceFace.qml"
                }
            }
        },
        "focus": {
            name: typeof I18n !== "undefined" ? I18n.t("guide.bar.modules.focus", "Focus") : "Focus",
            icon: "󰈈",
            defaultVariant: "default",
            styleKey: "",
            z: 1,
            aliases: [],
            groupable: true,
            defaultZone: "left",
            expandGroupCross: true,
            face: "faces/focus/FocusFace.qml"
        },
        "media": {
            name: typeof I18n !== "undefined" ? I18n.t("guide.bar.modules.media", "Media") : "Media",
            icon: "󰎈",
            defaultVariant: "classic",
            styleKey: "mediaStyle",
            z: 1,
            aliases: [],
            groupable: true,
            defaultZone: "center",
            expandGroupCross: false,
            face: "faces/media/MediaFace.qml",
            variants: {
                "classic": {
                    id: "classic",
                    name: typeof I18n !== "undefined" ? I18n.t("guide.bar.media.style.name.classic", "Classic") : "Classic",
                    desc: typeof I18n !== "undefined" ? I18n.t("guide.bar.media.style.classic", "Album thumbnail on a plain background") : "Album thumbnail on a plain background",
                    icon: "󰎈",
                    face: "faces/media/MediaFace.qml"
                },
                "ambient": {
                    id: "ambient",
                    name: typeof I18n !== "undefined" ? I18n.t("guide.bar.media.style.name.ambient", "Ambient") : "Ambient",
                    desc: typeof I18n !== "undefined" ? I18n.t("guide.bar.media.style.ambient", "Blurred album art behind the controls") : "Blurred album art behind the controls",
                    icon: "󰝚",
                    face: "faces/media/MediaFace.qml"
                }
            }
        },
        "vis": {
            name: typeof I18n !== "undefined" ? I18n.t("guide.bar.modules.vis", "Visualizer") : "Visualizer",
            icon: "󰝚",
            defaultVariant: "default",
            styleKey: "",
            z: 1,
            aliases: ["visualizer", "viswidget"],
            groupable: true,
            defaultZone: "center",
            expandGroupCross: true,
            face: "faces/vis/VisFace.qml"
        },
        "tray": {
            name: typeof I18n !== "undefined" ? I18n.t("guide.bar.modules.tray", "System tray") : "System tray",
            icon: "󱊞",
            defaultVariant: "default",
            styleKey: "",
            z: 1,
            aliases: [],
            groupable: true,
            defaultZone: "right",
            expandGroupCross: true,
            face: "faces/tray/TrayFace.qml"
        },
        "timedate": {
            name: typeof I18n !== "undefined" ? I18n.t("guide.bar.modules.timedate.name", "Time & date") : "Time & date",
            icon: "󰃰",
            defaultVariant: "classic",
            styleKey: "timeStyle",
            z: 10,
            aliases: ["time", "clock"],
            groupable: true,
            defaultZone: "center",
            expandGroupCross: false,
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
                },
                "pill": {
                    id: "pill",
                    name: typeof I18n !== "undefined" ? I18n.t("guide.bar.modules.timedate.style.name.pill", "Pill") : "Pill",
                    desc: typeof I18n !== "undefined" ? I18n.t("guide.bar.modules.timedate.style.pill", "Compact colored time pill") : "Compact colored time pill",
                    icon: "󰔟",
                    face: "faces/timedate/PillFace.qml"
                }
            }
        },
        "info": {
            name: typeof I18n !== "undefined" ? I18n.t("guide.bar.modules.info", "Info") : "Info",
            icon: "󰋼",
            defaultVariant: "default",
            styleKey: "",
            z: 10,
            aliases: ["indicator", "indicators", "record"],
            groupable: true,
            defaultZone: "center",
            expandGroupCross: false,
            face: "faces/info/InfoFace.qml"
        },
        "weather": {
            name: typeof I18n !== "undefined" ? I18n.t("guide.bar.modules.weather", "Weather") : "Weather",
            icon: "󰖐",
            defaultVariant: "default",
            styleKey: "",
            z: 10,
            aliases: [],
            groupable: true,
            defaultZone: "center",
            expandGroupCross: false,
            face: "faces/weather/WeatherFace.qml"
        },
        "sysmon": {
            name: typeof I18n !== "undefined" ? I18n.t("guide.bar.modules.sysmon", "System monitor") : "System monitor",
            icon: "󰍛",
            defaultVariant: "wave",
            styleKey: "sysmonStyle",
            z: 1,
            aliases: [],
            groupable: true,
            defaultZone: "right",
            expandGroupCross: true,
            face: "faces/sysmon/SysMonFace.qml",
            variants: {
                "wave": {
                    id: "wave",
                    name: typeof I18n !== "undefined" ? I18n.t("guide.bar.sysmon.style.name.wave", "Wave") : "Wave",
                    desc: typeof I18n !== "undefined" ? I18n.t("guide.bar.sysmon.style.wave", "Rings filled with a liquid wave") : "Rings filled with a liquid wave",
                    icon: "󰍛",
                    face: "faces/sysmon/SysMonFace.qml"
                },
                "circle": {
                    id: "circle",
                    name: typeof I18n !== "undefined" ? I18n.t("guide.bar.sysmon.style.name.circle", "Circle") : "Circle",
                    desc: typeof I18n !== "undefined" ? I18n.t("guide.bar.sysmon.style.circle", "Clean progress rings") : "Clean progress rings",
                    icon: "󰍛",
                    face: "faces/sysmon/SysMonFace.qml"
                }
            }
        },
        "kb": {
            name: typeof I18n !== "undefined" ? I18n.t("guide.bar.modules.keyboard", "Keyboard") : "Keyboard",
            icon: "󰌌",
            defaultVariant: "button",
            styleKey: "kbStyle",
            z: 1,
            aliases: [],
            groupable: true,
            defaultZone: "right",
            expandGroupCross: true,
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
            styleKey: "wifiStyle",
            z: 1,
            aliases: [],
            groupable: true,
            defaultZone: "right",
            expandGroupCross: true,
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
            styleKey: "btStyle",
            z: 1,
            aliases: [],
            groupable: true,
            defaultZone: "right",
            expandGroupCross: true,
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
            styleKey: "volStyle",
            z: 1,
            aliases: ["volume"],
            groupable: true,
            defaultZone: "right",
            expandGroupCross: true,
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
            styleKey: "batStyle",
            z: 1,
            aliases: ["battery"],
            groupable: true,
            defaultZone: "right",
            expandGroupCross: true,
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

    function styleKeyFor(moduleId) {
        let norm = normalizeId(moduleId);
        let t = types[norm];
        return (t && t.styleKey) ? t.styleKey : "";
    }

    function getModuleVariant(moduleId) {
        let norm = normalizeId(moduleId);
        let t = types[norm];
        let sk = styleKeyFor(norm);
        let bs = (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar) ? Config.rawSettings.bar : {};
        if (sk && bs[sk]) return bs[sk];
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
        let t = types[norm];
        return (t && t.z !== undefined) ? t.z : 1;
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

    readonly property var menuItemIds: ["settings", "launcher", "nightlight", "caffeine", "shuffle", "colorpicker", "clipboard"]

    function menuItemIcon(id) {
        if (id === "settings") return "󰒓";
        if (id === "launcher") return "󰍉";
        if (id === "nightlight") return "󰖔";
        if (id === "caffeine") return "󰅶";
        if (id === "shuffle") return "󰒝";
        if (id === "colorpicker") return "󰈋";
        if (id === "clipboard") return "󰆒";
        return "";
    }

    function menuItemsFromSettings(bs) {
        let res = [];
        if (bs && Array.isArray(bs.menuItems)) {
            res = bs.menuItems.filter((id, i, arr) => menuItemIds.indexOf(id) !== -1 && arr.indexOf(id) === i);
        } else {
            if (!bs || bs.menuShowSettings !== false) res.push("settings");
            if (!bs || bs.menuShowLauncher !== false) res.push("launcher");
            if (bs && bs.menuShowNightLight === true) res.push("nightlight");
            if (bs && bs.menuShowCaffeine === true) res.push("caffeine");
        }
        return res.length > 0 ? res : ["settings"];
    }
}
