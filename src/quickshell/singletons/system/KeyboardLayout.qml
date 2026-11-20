pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../../"

Singleton {
    id: root

    property string layout: "US"
    property bool ready: false
    property int subscribers: 0
    readonly property bool active: subscribers > 0

    property string mainKeyboard: ""

    function subscribe() {
        subscribers++;
        if (subscribers === 1) start();
    }

    function unsubscribe() {
        if (subscribers <= 0) return;
        subscribers--;
        if (subscribers === 0) stop();
    }

    function start() {
        if (Compositor.name === "niri") {
            NiriState.subscribe();
            applyNiriLayout();
            return;
        }
        if (Compositor.name === "sway") {
            SwayState.subscribeKeyboard();
            applySwayLayout();
            return;
        }
        if (Compositor.name === "mango") {
            MangoState.subscribeKeyboard();
            applyMangoLayout();
            return;
        }
        if (!root.supportsKeyboardLayouts) return;
        devicesPoller.running = false;
        devicesPoller.running = true;
    }

    function stop() {
        if (Compositor.name === "niri") {
            NiriState.unsubscribe();
            return;
        }
        if (Compositor.name === "sway") {
            SwayState.unsubscribeKeyboard();
            return;
        }
        if (Compositor.name === "mango") {
            MangoState.unsubscribeKeyboard();
            return;
        }
        devicesPoller.running = false;
    }

    function refresh() {
        if (!active || Compositor.name !== "hyprland") return;
        devicesPoller.running = false;
        devicesPoller.running = true;
    }

    function switchNext() {
        if (Compositor.name === "niri") {
            Quickshell.execDetached(["niri", "msg", "action", "switch-layout", "next"]);
        } else if (Compositor.name === "sway") {
            Quickshell.execDetached(["swaymsg", "input", "type:keyboard", "xkb_switch_layout", "next"]);
        } else if (Compositor.name === "mango") {
            Quickshell.execDetached(["mmsg", "dispatch", "switch_keyboard_layout"]);
        } else {
            Quickshell.execDetached(["hyprctl", "switchxkblayout", "main", "next"]);
        }
    }

    readonly property bool supportsKeyboardLayouts: ["hyprland", "niri", "sway", "mango"].includes(Compositor.name)

    readonly property string niriLayoutWriterScript: `import json, os, re, shutil, subprocess, sys
from pathlib import Path
items = json.loads(sys.argv[1])
allowed = re.compile(r"^[A-Za-z0-9_+/-]+$")
layouts, variants = [], []
for item in items:
    code = str(item.get("layout", "")); variant = str(item.get("variant", ""))
    if not allowed.fullmatch(code) or (variant and not allowed.fullmatch(variant)): continue
    layouts.append(code); variants.append(variant)
if not layouts: raise SystemExit("No valid XKB layouts supplied")
root = Path(os.environ.get("NIRI_CONFIG", str(Path.home()/".config/niri/config.kdl"))).expanduser()
seen, paths = set(), []
def visit(path):
    try: path = path.resolve()
    except Exception: return
    if path in seen or not path.is_file(): return
    seen.add(path); paths.append(path)
    try: source = path.read_text(encoding="utf-8")
    except Exception: return
    for match in re.finditer(r'(?m)^\\s*include\\s+"([^"]+)"', source):
        target = Path(match.group(1)).expanduser()
        if not target.is_absolute(): target = path.parent / target
        matches = list(target.parent.glob(target.name)) if any(ch in str(target) for ch in "*?[") else [target]
        for child in matches: visit(child)
visit(root)
def block(text, node):
    match = re.search(r"\\b" + re.escape(node) + r"\\s*\\{", text)
    if not match: return None
    opening = text.find("{", match.start()); depth = 0; quoted = False; escaped = False; line_comment = False
    for pos in range(opening, len(text)):
        ch = text[pos]; nxt = text[pos+1] if pos+1 < len(text) else ""
        if line_comment:
            if ch == "\\n": line_comment = False
            continue
        if quoted:
            if escaped: escaped = False
            elif ch == "\\\\": escaped = True
            elif ch == '"': quoted = False
            continue
        if ch == "/" and nxt == "/": line_comment = True; continue
        if ch == '"': quoted = True; continue
        if ch == "{": depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0: return opening + 1, pos
    return None
def set_prop(body, key, value):
    pattern = re.compile(r'(?m)^([ \\t]*)' + re.escape(key) + r'\\s+"(?:\\\\.|[^"\\\\])*"')
    replacement = lambda m: m.group(1) + key + " " + json.dumps(value, ensure_ascii=False)
    if pattern.search(body): return pattern.sub(replacement, body, count=1)
    indent_match = re.search(r'(?m)^([ \\t]+)\\S', body)
    indent = indent_match.group(1) if indent_match else "        "
    trailing = body[len(body.rstrip()):]
    return body.rstrip() + "\\n" + indent + key + " " + json.dumps(value, ensure_ascii=False) + trailing
target = None
for path in paths:
    try: text = path.read_text(encoding="utf-8")
    except Exception: continue
    span = block(text, "xkb")
    if span:
        start, end = span; body = text[start:end]
        body = set_prop(body, "layout", ",".join(layouts))
        body = set_prop(body, "variant", ",".join(variants))
        updated = text[:start] + body + text[end:]
        target = (path, updated)
        break
if not target: raise SystemExit("Could not find an included Niri xkb { } block; no config changed")
path, updated = target
if updated != path.read_text(encoding="utf-8"):
    backup = path.with_suffix(path.suffix + ".serpantinum.bak")
    if not backup.exists(): shutil.copy2(path, backup)
    temp = path.with_suffix(path.suffix + ".serpantinum.tmp")
    temp.write_text(updated, encoding="utf-8"); temp.replace(path)
result = subprocess.run(["niri", "msg", "action", "load-config-file", "--path", str(root)], capture_output=True, text=True)
if result.returncode: raise SystemExit(result.stderr or "Niri config reload failed")
`
    readonly property string mangoLayoutWriterScript: `import json, re, shutil, subprocess, sys
from pathlib import Path
items = json.loads(sys.argv[1])
allowed = re.compile(r"^[A-Za-z0-9_+/-]+$")
layouts, variants = [], []
for item in items:
    code = str(item.get("layout", "")); variant = str(item.get("variant", ""))
    if not allowed.fullmatch(code) or (variant and not allowed.fullmatch(variant)): continue
    layouts.append(code); variants.append(variant)
if not layouts: raise SystemExit("No valid XKB layouts supplied")
root = Path.home() / ".config/mango/config.conf"
seen, paths = set(), []
def visit(path):
    try: path = path.resolve()
    except Exception: return
    if path in seen or not path.is_file(): return
    seen.add(path); paths.append(path)
    try: text = path.read_text(encoding="utf-8")
    except Exception: return
    for match in re.finditer(r"(?m)^\\s*source\\s*=\\s*([^#\\n]+)", text):
        raw = match.group(1).strip().strip('"\\'')
        child = Path(raw).expanduser()
        if not child.is_absolute(): child = path.parent / child
        visit(child)
visit(root)
def set_value(text, key, value):
    pattern = re.compile(r"(?m)^([ \\t]*" + re.escape(key) + r"\\s*=\\s*)[^#\\n]*")
    line = key + "=" + value
    if pattern.search(text): return pattern.sub(lambda m: m.group(1) + value, text, count=1)
    return text.rstrip() + "\\n" + line + "\\n"
target = None
for path in paths:
    try: text = path.read_text(encoding="utf-8")
    except Exception: continue
    if re.search(r"(?m)^\\s*xkb_rules_layout\\s*=", text):
        updated = set_value(text, "xkb_rules_layout", ",".join(layouts))
        updated = set_value(updated, "xkb_rules_variant", ",".join(variants))
        target = (path, updated); break
if not target: raise SystemExit("Could not find sourced Mango xkb_rules_layout; no config changed")
path, updated = target
if updated != path.read_text(encoding="utf-8"):
    backup = path.with_suffix(path.suffix + ".serpantinum.bak")
    if not backup.exists(): shutil.copy2(path, backup)
    temp = path.with_suffix(path.suffix + ".serpantinum.tmp")
    temp.write_text(updated, encoding="utf-8"); temp.replace(path)
result = subprocess.run(["mmsg", "dispatch", "reload_config"], capture_output=True, text=True)
if result.returncode: raise SystemExit(result.stderr or "Mango config reload failed")
`

    function applyLayouts(layouts) {
        if (!root.supportsKeyboardLayouts || !Array.isArray(layouts) || layouts.length === 0) return false;
        let codes = [];
        let variants = [];
        const allowed = new RegExp("^[A-Za-z0-9_+/-]+$");
        for (let i = 0; i < layouts.length; i++) {
            let item = layouts[i];
            let code = typeof item === "string" ? item : String(item.layout || "");
            let variant = typeof item === "string" ? "" : String(item.variant || "");
            if (!allowed.test(code) || (variant !== "" && !allowed.test(variant))) continue;
            codes.push(code);
            variants.push(variant);
        }
        if (codes.length === 0) return false;
        let normalized = codes.map((code, index) => ({ layout: code, variant: variants[index] }));
        if (Compositor.name === "hyprland") return root.applyHyprlandLayouts(normalized);
        if (Compositor.name === "sway") {
            let swayCommand = "input type:keyboard xkb_layout " + codes.join(",")
                + "; input type:keyboard xkb_variant \"" + variants.join(",") + "\"";
            Quickshell.execDetached(["swaymsg", swayCommand]);
            return true;
        }
        if (Compositor.name === "niri") {
            Quickshell.execDetached(["python3", "-c", root.niriLayoutWriterScript, JSON.stringify(normalized)]);
            return true;
        }
        if (Compositor.name === "mango") {
            Quickshell.execDetached(["python3", "-c", root.mangoLayoutWriterScript, JSON.stringify(normalized)]);
            return true;
        }
        return false;
    }

    // Apply the selected XKB layout/variant list to Hyprland at runtime.
    // Keyboard layout configuration is persisted separately in General settings.
    function applyHyprlandLayouts(layouts) {
        if (Compositor.name !== "hyprland" || !Array.isArray(layouts) || layouts.length === 0) return false;

        let layoutCodes = [];
        let variants = [];
        for (let i = 0; i < layouts.length; i++) {
            let item = layouts[i];
            let layout = typeof item === "string" ? item : String(item.layout || "");
            let variant = typeof item === "string" ? "" : String(item.variant || "");
            let allowed = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_+-/";
            if (layout.length === 0 || layout.split("").some(ch => allowed.indexOf(ch) < 0)) continue;
            if (variant.split("").some(ch => allowed.indexOf(ch) < 0)) continue;
            layoutCodes.push(layout);
            variants.push(variant);
        }
        if (layoutCodes.length === 0) return false;

        // This Serpantinum Hyprland setup uses the Lua configuration API.
        // `hyprctl keyword` is not supported by that provider; use `hyprctl eval`.
        // Layout and variant values are validated above before embedding them in Lua.
        let lua = "hl.config({ input = { kb_layout = \"" + layoutCodes.join(",")
            + "\", kb_variant = \"" + variants.join(",") + "\" } })";
        Quickshell.execDetached(["hyprctl", "eval", lua]);
        return true;
    }


    Component.onCompleted: {
        if (!root.supportsKeyboardLayouts || !Config.dataReady) return;
        let settings = Config.getSetting("general", {});
        if (settings && Array.isArray(settings.keyboardLayouts) && settings.keyboardLayouts.length > 0)
            root.applyLayouts(settings.keyboardLayouts);
    }


    Connections {
        target: Config
        function onSettingsLoaded() {
            if (!root.supportsKeyboardLayouts) return;
            let settings = Config.getSetting("general", {});
            if (settings && Array.isArray(settings.keyboardLayouts) && settings.keyboardLayouts.length > 0)
                root.applyLayouts(settings.keyboardLayouts);
        }
    }

    function applyNiriLayout() {
        if (!NiriState.keyboardReady) return;
        let txt = NiriState.shortKeyboardLayout;
        if (txt !== "") root.layout = txt;
        root.ready = true;
    }

    Connections {
        target: NiriState
        enabled: Compositor.name === "niri" && root.active
        function onShortKeyboardLayoutChanged() { root.applyNiriLayout(); }
        function onKeyboardReadyChanged() { root.applyNiriLayout(); }
    }

    function applySwayLayout() {
        if (!SwayState.keyboardReady) return;
        root.layout = SwayState.shortKeyboardLayout;
        root.ready = true;
    }

    Connections {
        target: SwayState
        enabled: Compositor.name === "sway" && root.active
        function onShortKeyboardLayoutChanged() { root.applySwayLayout(); }
        function onKeyboardReadyChanged() { root.applySwayLayout(); }
    }

    function applyMangoLayout() {
        if (!MangoState.keyboardReady) return;
        root.applyLayoutName(MangoState.keyboardLayout);
    }

    Connections {
        target: MangoState
        enabled: Compositor.name === "mango" && root.active
        function onKeyboardLayoutChanged() { root.applyMangoLayout(); }
        function onKeyboardReadyChanged() { root.applyMangoLayout(); }
    }

    function applyLayoutName(name) {
        let txt = (name && name !== "null") ? String(name) : "US";
        root.layout = txt.substring(0, 2).toUpperCase();
        root.ready = true;
    }

    Connections {
        target: Compositor.name === "hyprland" ? Hyprland : null
        enabled: Compositor.name === "hyprland" && root.active
        function onRawEvent(event) {
            if (!event) return;
            if (event.name === "configreloaded") {
                let settings = Config.getSetting("general", {});
                if (settings && Array.isArray(settings.keyboardLayouts) && settings.keyboardLayouts.length > 0)
                    root.applyLayouts(settings.keyboardLayouts);
                return;
            }
            if (event.name !== "activelayout") return;
            let args = event.parse(2);
            if (args.length === 2 && root.mainKeyboard !== "" && args[0] === root.mainKeyboard) {
                root.applyLayoutName(args[1]);
            } else if (!devicesPoller.running) {
                devicesPoller.running = true;
            }
        }
    }

    Process {
        id: devicesPoller
        command: ["hyprctl", "devices", "-j"]
        environment: ({ "LC_ALL": "C" })
        stdout: StdioCollector {
            onStreamFinished: {
                let keyboards = [];
                try {
                    keyboards = JSON.parse(this.text).keyboards || [];
                } catch (e) {}
                let kb = keyboards.find(k => k.main === true) || keyboards[0] || null;
                root.mainKeyboard = kb ? String(kb.name || "") : "";
                root.applyLayoutName(kb ? kb.active_keymap : "");
            }
        }
    }
}
