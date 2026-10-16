.pragma library

// Turns the JSON from `hyprctl binds -j` into sections for KeybindsWindow.qml.
// Binds from compositors/hyprland/config/keybinds.lua carry a "keybinds.<section>.<name>"
// description that is translated; other descriptions are shown as written.

var SECTION_ORDER = ["shell", "apps", "windows", "workspaces", "screenshot", "media", "system", "other"];

// Hyprland modmask bits, listed in the order they are shown.
var MODIFIERS = [
    { bit: 64, name: "SUPER" },
    { bit: 4, name: "CTRL" },
    { bit: 8, name: "ALT" },
    { bit: 1, name: "SHIFT" }
];

var KEY_NAMES = {
    "mouse:272": "LMB",
    "mouse:273": "RMB",
    "mouse:274": "MMB",
    "RETURN": "Enter",
    "SPACE": "Space",
    "slash": "/",
    "Left": "←",
    "Right": "→",
    "Up": "↑",
    "Down": "↓"
};

function modifierNames(modmask) {
    var names = [];
    for (var i = 0; i < MODIFIERS.length; i++) {
        if (modmask & MODIFIERS[i].bit) names.push(MODIFIERS[i].name);
    }
    return names;
}

// Media and hardware keys: the icon printed on the key plus a translated name.
// Keys marked fn usually sit on F1-F12 and are pressed together with Fn.
var HARDWARE_KEYS = {
    "XF86AudioPlay": { icon: "󰐎", name: "keybinds.keys.play_pause", fn: true },
    "XF86AudioPause": { icon: "󰐎", name: "keybinds.keys.play_pause", fn: true },
    "XF86AudioPrev": { icon: "󰒮", name: "keybinds.keys.previous", fn: true },
    "XF86AudioNext": { icon: "󰒭", name: "keybinds.keys.next", fn: true },
    "XF86AudioMute": { icon: "󰝟", name: "keybinds.keys.mute", fn: true },
    "XF86AudioMicMute": { icon: "󰍭", name: "keybinds.keys.mic_mute", fn: true },
    "XF86AudioLowerVolume": { icon: "󰝞", name: "keybinds.keys.volume_down", fn: true },
    "XF86AudioRaiseVolume": { icon: "󰝝", name: "keybinds.keys.volume_up", fn: true },
    "XF86MonBrightnessDown": { icon: "󰃞", name: "keybinds.keys.brightness_down", fn: true },
    "XF86MonBrightnessUp": { icon: "󰃠", name: "keybinds.keys.brightness_up", fn: true },
    "XF86PowerOff": { icon: "󰐥", name: "keybinds.keys.power" }
};

function keyName(key, translate) {
    if (HARDWARE_KEYS[key] !== undefined) return HARDWARE_KEYS[key].icon + " " + translate(HARDWARE_KEYS[key].name);
    if (KEY_NAMES[key] !== undefined) return KEY_NAMES[key];
    if (key.indexOf("XF86") === 0) return key.substring(4);
    return key.length === 1 ? key.toUpperCase() : key;
}

// "1", "2" ... "0" read as a range; anything else is listed.
function joinKeys(keys) {
    var allDigits = keys.length > 2 && keys.every(function (k) { return /^[0-9]$/.test(k); });
    if (allDigits) return [keys[0] + "…" + keys[keys.length - 1]];
    return keys;
}

// translate(key) returns the key itself when there is no translation, like I18n.t.
function buildSections(jsonText, translate, noDescriptionText) {
    var binds = JSON.parse(jsonText);
    if (!Array.isArray(binds)) throw new Error("unexpected hyprctl output");

    var rowsBySection = {};
    var rowIndex = {};

    for (var i = 0; i < binds.length; i++) {
        var b = binds[i];
        var description = b.has_description ? String(b.description || "") : "";
        var section = "other";
        var label = noDescriptionText;

        if (description !== "") {
            var parts = description.split(".");
            if (parts.length === 3 && parts[0] === "keybinds" && SECTION_ORDER.indexOf(parts[1]) !== -1) {
                section = parts[1];
            }
            label = translate(description);
        }

        var modifiers = modifierNames(b.modmask || 0);
        // Binds sharing a description and modifiers (arrows, workspace numbers) become one row.
        var id = section + "\n" + label + "\n" + modifiers.join("+");
        if (description === "") id += "\n" + b.key;

        if (rowIndex[id] === undefined) {
            if (!rowsBySection[section]) rowsBySection[section] = [];
            rowIndex[id] = rowsBySection[section].length;
            var hardware = HARDWARE_KEYS[b.key];
            var viaFn = modifiers.length === 0 && hardware !== undefined && hardware.fn === true;
            rowsBySection[section].push({ label: label, modifiers: viaFn ? ["Fn"] : modifiers, keys: [] });
        }
        var row = rowsBySection[section][rowIndex[id]];
        var name = keyName(String(b.key), translate);
        if (row.keys.indexOf(name) === -1) row.keys.push(name);
    }

    var sections = [];
    for (var s = 0; s < SECTION_ORDER.length; s++) {
        var rows = rowsBySection[SECTION_ORDER[s]];
        if (!rows) continue;
        for (var r = 0; r < rows.length; r++) {
            rows[r].combo = rows[r].modifiers.concat([joinKeys(rows[r].keys).join(" / ")]);
        }
        sections.push({ id: SECTION_ORDER[s], rows: rows });
    }
    return sections;
}
