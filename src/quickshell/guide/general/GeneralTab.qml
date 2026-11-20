import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../"
import "../../"
import "../../reusables"
import "../../reusables/guide"

GuideTab {
    id: generalTabRoot
    subTabIndex: 0

    onVisibleChanged: {
        if (!visible) {
            if (langDropdown.isOpen) langDropdown.closePopup();
            if (keyboardLayoutDropdown.isOpen) keyboardLayoutDropdown.closePopup();
            if (avatarDropdown.isOpen) avatarDropdown.closePopup();
            if (locationPopupLoader.item) locationPopupLoader.item.close();
            isLocEditOpen = false;
        }
    }

    property var defaultGeneralSettings: {
        "language": "en",
        "openGuideAtStartup": false,
        "wallpaperDir": "",
        "workspaceCount": 8,
        "avatarPath": "",
        "muteSfx": false,
        "sfxVolume": 100,
        "quickactions": true
    }

    property var generalSettings: Config.getSetting("general", defaultGeneralSettings)
    property string currentLanguage: generalSettings.language !== undefined ? generalSettings.language : I18n.currentLang
    property bool muteSfx: generalSettings.muteSfx !== undefined ? generalSettings.muteSfx : false
    property real sfxVolume: generalSettings.sfxVolume !== undefined ? generalSettings.sfxVolume : 100
    property bool quickactions: generalSettings.quickactions !== undefined ? generalSettings.quickactions : true
    property bool isLocEditOpen: false

    property alias langDropdown: profileSection.langDropdown
    property alias keyboardLayoutDropdown: profileSection.keyboardLayoutDropdown
    property alias avatarDropdown: profileSection.avatarDropdown
    property alias latInput: locationSection.latInput
    property alias lonInput: locationSection.lonInput
    property alias sfxVolumeDebounceTimer: sfxVolumeDebounceTimer

    Timer {
        id: sfxVolumeDebounceTimer
        interval: 100
        repeat: false
        onTriggered: {
            generalTabRoot.updateGeneralSettings();
        }
    }

    property string currentAvatarSourcePath: {
        let saved = (generalSettings && generalSettings.avatarPath !== undefined) ? generalSettings.avatarPath : "";
        let path = saved !== "" ? saved : (SystemInfo.avatarPath || "");
        if (path.startsWith("file://")) {
            path = path.substring(7);
        }
        return path;
    }
    property var languageCodes: ["en", "fr", "ua", "ru", "de", "es", "it", "hy", "vi", "ko", "pt", "az", "ar", "ja", "zh", "zh_tw", "pl", "tr", "id", "nl", "fa", "hi", "bg", "hr", "sr"]
    property var languageNames: ["English", "Français", "Українська", "Русский", "Deutsch", "Español", "Italiano", "Հայերեն", "Tiếng Việt", "한국어", "Português", "Azərbaycanca", "العربية", "日本語", "简体中文", "繁體中文", "Polski", "Türkçe", "Bahasa Indonesia", "Nederlands", "فارسی", "हिन्दी", "Български", "Hrvatski", "Српски (ћирилица)"]

    // Keyboard layouts are separate from the interface language. The selector is
    // available on all supported compositors with compositor-specific application.
    property var keyboardLayouts: []
    property var keyboardLayoutCatalog: []
    property var keyboardLayoutNames: []
    property int selectedKeyboardLayoutIndex: 0
    property bool keyboardLayoutsInitialized: false
    readonly property bool keyboardLayoutManagerSupported: ["hyprland", "niri", "sway", "mango"].includes(Compositor.name)
    readonly property string keyboardLayoutReadScript: `import json, os, re, subprocess, sys
from pathlib import Path
comp = sys.argv[1] if len(sys.argv) > 1 else ""
layout_text, variant_text = "", ""
def split_layouts(layout, variant):
    layouts = [x.strip() for x in layout.split(",") if x.strip()]
    variants = [x.strip() for x in variant.split(",")] if variant else []
    return [{"layout": code, "variant": variants[i] if i < len(variants) else ""}
            for i, code in enumerate(layouts)]
def read_kdl_xkb(text):
    m = re.search(r"\\bxkb\\s*\\{([^{}]*)\\}", text, re.S)
    if not m: return None
    body = m.group(1)
    lm = re.search(r'(?m)^\\s*layout\\s+"([^"]*)"', body)
    if not lm: return None
    vm = re.search(r'(?m)^\\s*variant\\s+"([^"]*)"', body)
    return lm.group(1), vm.group(1) if vm else ""
def niri_files(root):
    seen, result = set(), []
    def visit(path):
        try: path = path.expanduser().resolve()
        except Exception: return
        if path in seen or not path.is_file(): return
        seen.add(path); result.append(path)
        try: text = path.read_text(encoding="utf-8")
        except Exception: return
        for m in re.finditer(r'(?m)^\\s*include\\s+"([^"]+)"', text):
            raw = m.group(1).replace("~", str(Path.home()), 1) if m.group(1).startswith("~/") else m.group(1)
            target = Path(raw)
            if not target.is_absolute(): target = path.parent / target
            matches = list(target.parent.glob(target.name)) if any(c in str(target) for c in "*?[") else [target]
            for item in matches: visit(item)
    visit(root)
    return result
try:
    if comp == "hyprland":
        data = {}
        for key in ("kb_layout", "kb_variant"):
            p = subprocess.run(["hyprctl", "getoption", f"input:{key}", "-j"], capture_output=True, text=True)
            if p.returncode == 0: data[key] = json.loads(p.stdout)
        layout_text = str(data.get("kb_layout", {}).get("str", "us"))
        variant_text = str(data.get("kb_variant", {}).get("str", ""))
        if variant_text == "[[EMPTY]]": variant_text = ""
    elif comp == "niri":
        root = Path(os.environ.get("NIRI_CONFIG", str(Path.home() / ".config/niri/config.kdl"))).expanduser()
        for path in niri_files(root):
            try: found = read_kdl_xkb(path.read_text(encoding="utf-8"))
            except Exception: found = None
            if found:
                layout_text, variant_text = found
                break
        if not layout_text:
            for path in (Path.home() / ".config/niri").rglob("*.kdl"):
                try: found = read_kdl_xkb(path.read_text(encoding="utf-8"))
                except Exception: found = None
                if found:
                    layout_text, variant_text = found
                    break
    elif comp == "sway":
        config_home = Path(os.environ.get("XDG_CONFIG_HOME", str(Path.home() / ".config")))
        root = Path(os.environ.get("SWAY_CONFIG", str(config_home / "sway" / "config"))).expanduser()
        found = {"layout": "", "variant": ""}
        seen = set()
        def read_sway_config(path):
            try: path = path.resolve()
            except Exception: return
            if path in seen or not path.is_file(): return
            seen.add(path)
            try: text = path.read_text(encoding="utf-8")
            except Exception: return
            for line in text.splitlines():
                include = re.match(r'\\s*include\\s+(?:--no-wildcard\\s+)?(?:"([^"]+)"|(\\S+))', line)
                if include:
                    raw = include.group(1) or include.group(2)
                    raw = os.path.expandvars(os.path.expanduser(raw))
                    target = Path(raw)
                    if not target.is_absolute(): target = path.parent / target
                    matches = sorted(target.parent.glob(target.name)) if any(c in str(target) for c in "*?[") else [target]
                    for child in matches: read_sway_config(child)
                    continue
                lm = re.match(r'\\s*xkb_layout\\s+"?([^"\\s#]+)', line)
                if lm: found["layout"] = lm.group(1)
                vm = re.match(r'\\s*xkb_variant\\s+"?([^"#]*)', line)
                if vm: found["variant"] = vm.group(1).strip().strip('"')
        read_sway_config(root)
        layout_text, variant_text = found["layout"], found["variant"]
    elif comp == "mango":
        root = Path.home() / ".config/mango"
        for path in sorted(root.rglob("*")) if root.exists() else []:
            if not path.is_file(): continue
            try: text = path.read_text(encoding="utf-8")
            except Exception: continue
            lm = re.search(r'(?m)^\\s*xkb_rules_layout\\s*=\\s*([^\\s#]+)', text)
            if lm:
                vm = re.search(r'(?m)^\\s*xkb_rules_variant\\s*=\\s*([^\\s#]*)', text)
                layout_text, variant_text = lm.group(1), vm.group(1) if vm else ""
                break
except Exception:
    pass
if not layout_text: layout_text = "us"
print(json.dumps({"layouts": split_layouts(layout_text, variant_text)}))
`

    function keyboardLayoutLabel(item) {
        let layout = typeof item === "string" ? item : String(item.layout || "");
        let variant = typeof item === "string" ? "" : String(item.variant || "");
        let found = keyboardLayoutCatalog.find(entry => entry.layout === layout && entry.variant === variant);
        if (found) return found.label;
        if (layout === "rs" && variant === "") return "Serbian (Cyrillic) (rs)";
        if (layout === "rs" && variant === "latin") return "Serbian (Latin) (rs, latin)";
        return layout + (variant ? " (" + variant + ")" : "");
    }

    function loadKeyboardLayouts(settings) {
        let saved = settings && settings.keyboardLayouts;
        if (Array.isArray(saved) && saved.length > 0) {
            generalTabRoot.keyboardLayouts = saved.map(item => typeof item === "string"
                ? ({ layout: item, variant: "" })
                : ({ layout: String(item.layout || ""), variant: String(item.variant || "") }));
            generalTabRoot.keyboardLayoutsInitialized = true;
            KeyboardLayout.applyLayouts(generalTabRoot.keyboardLayouts);
        } else if (generalTabRoot.keyboardLayoutManagerSupported) {
            keyboardLayoutReadProcess.running = false;
            keyboardLayoutReadProcess.running = true;
        }
    }

    function saveKeyboardLayouts() {
        generalTabRoot.keyboardLayoutsInitialized = true;
        generalTabRoot.updateGeneralSettings();
        KeyboardLayout.applyLayouts(generalTabRoot.keyboardLayouts);
    }

    function addKeyboardLayout(index) {
        if (!keyboardLayoutManagerSupported || index < 0 || index >= keyboardLayoutCatalog.length) return;
        let entry = keyboardLayoutCatalog[index];
        let key = entry.layout + "|" + entry.variant;
        if (keyboardLayouts.some(item => item.layout + "|" + (item.variant || "") === key)) return;
        let next = keyboardLayouts.slice();
        next.push({ layout: entry.layout, variant: entry.variant || "" });
        keyboardLayouts = next;
        saveKeyboardLayouts();
    }

    function removeKeyboardLayout(index) {
        if (index < 0 || index >= keyboardLayouts.length || keyboardLayouts.length <= 1) return;
        let next = keyboardLayouts.slice();
        next.splice(index, 1);
        keyboardLayouts = next;
        saveKeyboardLayouts();
    }

    Process {
        id: keyboardLayoutCatalogProcess
        command: ["python3", "-c",
            "import json\nfrom pathlib import Path\np=Path('/usr/share/X11/xkb/rules/base.lst')\nsection=''\nitems=[]\nfor raw in p.read_text(encoding='utf-8').splitlines():\n    line=raw.strip()\n    if line.startswith('!'):\n        section=line[1:].strip()\n        continue\n    parts=line.split(None, 2)\n    if section == 'layout' and len(parts) >= 2:\n        items.append({'layout':parts[0], 'variant':'', 'name':' '.join(parts[1:])})\n    elif section == 'variant' and len(parts) >= 3:\n        items.append({'layout':parts[0], 'variant':parts[1], 'name':parts[2]})\nprint(json.dumps(items, ensure_ascii=False))"]
        stdout: StdioCollector {
            onStreamFinished: {
                let entries = [];
                try { entries = JSON.parse(this.text) || []; } catch (e) { entries = []; }
                let labels = [];
                let normalized = [];
                for (let i = 0; i < entries.length; i++) {
                    let entry = entries[i];
                    if (!entry.layout) continue;
                    let name = String(entry.name || entry.layout);
                    if (entry.layout === "rs" && !entry.variant) name = "Serbian (Cyrillic)";
                    else if (entry.layout === "rs" && entry.variant === "latin") name = "Serbian (Latin)";
                    let suffix = entry.layout + (entry.variant ? ", " + entry.variant : "");
                    let label = name + " (" + suffix + ")";
                    normalized.push({ layout: String(entry.layout), variant: String(entry.variant || ""), label: label, name: name });
                    labels.push(label);
                }
                generalTabRoot.keyboardLayoutCatalog = normalized;
                generalTabRoot.keyboardLayoutNames = labels;
            }
        }
    }

    Process {
        id: keyboardLayoutReadProcess
        command: ["python3", "-c", generalTabRoot.keyboardLayoutReadScript, Compositor.name]
        stdout: StdioCollector {
            onStreamFinished: {
                if (generalTabRoot.keyboardLayoutsInitialized) return;
                try {
                    let data = JSON.parse(this.text);
                    let result = Array.isArray(data.layouts) ? data.layouts : [];
                    if (result.length > 0) generalTabRoot.keyboardLayouts = result;
                    else generalTabRoot.keyboardLayouts = [{ layout: "us", variant: "" }];
                    generalTabRoot.keyboardLayoutsInitialized = true;
                } catch (e) {
                    generalTabRoot.keyboardLayouts = [{ layout: "us", variant: "" }];
                    generalTabRoot.keyboardLayoutsInitialized = true;
                }
            }
        }
    }

    Component.onCompleted: {
        if (keyboardLayoutManagerSupported) {
            keyboardLayoutCatalogProcess.running = true;
            loadKeyboardLayouts(generalSettings);
        }
    }

    Connections {
        target: Config
        function onSettingsLoaded() {
            let gs = Config.getSetting("general", generalTabRoot.defaultGeneralSettings);
            generalTabRoot.currentLanguage = gs.language !== undefined ? gs.language : I18n.currentLang;
            generalTabRoot.loadKeyboardLayouts(gs);
            generalTabRoot.muteSfx = gs.muteSfx !== undefined ? gs.muteSfx : false;
            generalTabRoot.sfxVolume = gs.sfxVolume !== undefined ? gs.sfxVolume : 100;
            generalTabRoot.quickactions = gs.quickactions !== undefined ? gs.quickactions : true;
            generalTabRoot.generalSettings = gs;
        }
    }

    Connections {
        target: Location
        function onLocationUpdated() {
            if (Location.locationData && Location.locationData.latitude !== undefined) {
                latInput.text = Location.locationData.latitude.toString();
            }
            if (Location.locationData && Location.locationData.longitude !== undefined) {
                lonInput.text = Location.locationData.longitude.toString();
            }
        }
    }

    function updateGeneralSettings() {
        if (typeof Config !== "undefined" && !Config.dataReady) return;
        let current = Object.assign({}, Config.getSetting("general", generalTabRoot.defaultGeneralSettings));
        current.language = generalTabRoot.currentLanguage;
        current.avatarPath = generalTabRoot.currentAvatarSourcePath;
        current.muteSfx = generalTabRoot.muteSfx;
        current.sfxVolume = generalTabRoot.sfxVolume;
        current.quickactions = generalTabRoot.quickactions;
        if (generalTabRoot.keyboardLayoutsInitialized) current.keyboardLayouts = generalTabRoot.keyboardLayouts;
        Config.setSetting("general", current);
    }

    function openImagePicker(initialPath) {
        imagePickerLoader.active = true;
        imagePickerLoader.item.openPicker(initialPath);
    }

    function openLocationPopup() {
        locationPopupLoader.active = true;
        locationPopupLoader.item.open();
    }

    Loader {
        id: imagePickerLoader
        active: false
        sourceComponent: ImagePicker {
            rootObj: generalTabRoot.rootObj
            onImageSelected: function(filePath, fileName) {
                let gs = Object.assign({}, generalTabRoot.generalSettings);
                gs.avatarPath = filePath;
                generalTabRoot.generalSettings = gs;
                generalTabRoot.updateGeneralSettings();
            }
        }
    }

    Loader {
        id: locationPopupLoader
        active: false
        sourceComponent: LocationInfo {
            rootObj: generalTabRoot.rootObj
        }
    }

    Flickable {
        anchors.fill: parent
        anchors.topMargin: rootObj.s(8)
        anchors.leftMargin: rootObj.s(8)
        anchors.rightMargin: rootObj.s(8)
        anchors.bottomMargin: rootObj.s(8)
        contentHeight: settingsCol.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: settingsCol
            width: parent.width
            spacing: rootObj.s(6)

            GeneralProfileSection { id: profileSection; tab: generalTabRoot }

            GeneralAudioSection { tab: generalTabRoot }

            GeneralBehaviorSection { tab: generalTabRoot }

            GeneralTimeSection { tab: generalTabRoot }

            GeneralLocationSection { id: locationSection; tab: generalTabRoot }
        }
    }
}
