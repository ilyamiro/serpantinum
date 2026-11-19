.pragma library

// Which key combination pastes into the window that was focused before the clipboard opened.
// Terminals reserve Ctrl+V for the shell, so they get Ctrl+Shift+V; every other app gets Ctrl+V.

var DEFAULT_TERMINALS = ["ghostty", "kitty", "wezterm", "alacritty", "foot", "konsole", "gnome-terminal", "kgx", "xterm", "urxvt", "st", "terminator", "tilix", "xfce4-terminal", "rio", "contour", "footclient", "ptyxis", "blackbox", "org.gnome.terminal", "org.gnome.console", "org.gnome.ptyxis", "com.raggesilver.blackbox"];

// Window classes that mean "no app to paste into".
var NO_TARGET = ["", "desktop", "quickshell", "unknown"];

// True when appClass, or one of its dot-separated parts, is one of the terminals
// (com.mitchellh.ghostty, or a custom class such as com.ghostty.htop).
function isTerminal(appClass, terminals) {
    var cls = String(appClass || "").trim().toLowerCase();
    if (cls === "") return false;
    var parts = cls.split(".");
    for (var i = 0; i < terminals.length; i++) {
        var t = String(terminals[i] || "").trim().toLowerCase();
        if (t === "") continue;
        if (cls === t || parts.indexOf(t) !== -1) return true;
    }
    return false;
}

// The default terminals plus the user's own entries from settings (clipboard.terminals).
function terminalList(userTerminals) {
    var list = DEFAULT_TERMINALS.slice();
    if (!userTerminals || typeof userTerminals.length !== "number") return list;
    for (var i = 0; i < userTerminals.length; i++) {
        var t = String(userTerminals[i] || "").trim();
        if (t !== "" && list.indexOf(t) === -1) list.push(t);
    }
    return list;
}

function hasTarget(appClass) {
    return NO_TARGET.indexOf(String(appClass || "").trim().toLowerCase()) === -1;
}

// wtype arguments that paste into appClass, or [] when there is no window to paste into.
function pasteCommand(appClass, terminals) {
    if (!hasTarget(appClass)) return [];
    if (isTerminal(appClass, terminals)) return ["-M", "ctrl", "-M", "shift", "v", "-m", "shift", "-m", "ctrl"];
    return ["-M", "ctrl", "v", "-m", "ctrl"];
}

// Hyprland reads keys from wtype's own keymap with the main keyboard layout, so a synthetic Ctrl+Shift+V
// can fire an unrelated bind (keycode 9 is Escape). Hyprland gets its own dispatcher instead, sent straight
// to the window: the Lua-config form first, then the legacy one. "" when there is nothing to paste into.
function hyprlandPasteShell(appClass, address, terminals) {
    if (!hasTarget(appClass)) return "";
    var addr = String(address || "").trim().toLowerCase();
    if (addr.indexOf("0x") !== 0) addr = "0x" + addr;
    if (!/^0x[0-9a-f]+$/.test(addr)) return "";
    var mods = isTerminal(appClass, terminals) ? "CTRL SHIFT" : "CTRL";
    return "hyprctl dispatch 'hl.dsp.send_shortcut({ mods = \"" + mods + "\", key = \"V\", window = \"address:" + addr + "\" })'"
        + " || hyprctl dispatch sendshortcut '" + mods + ", V, address:" + addr + "'";
}
