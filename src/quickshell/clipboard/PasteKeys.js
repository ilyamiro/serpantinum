.pragma library

// Which key combination pastes into the window that was focused before the clipboard opened.
// Terminals reserve Ctrl+V for the shell, so they get Ctrl+Shift+V; every other app gets Ctrl+V.

var DEFAULT_TERMINALS = ["ghostty", "kitty", "wezterm", "alacritty", "foot", "konsole", "gnome-terminal", "kgx", "xterm", "urxvt", "st", "terminator", "tilix", "xfce4-terminal", "rio", "contour"];

// Window classes that mean "no app to paste into".
var NO_TARGET = ["", "desktop", "quickshell", "unknown"];

// True when appClass is one of the terminals, or ends in "." + one of them (reverse-DNS ids such as com.mitchellh.ghostty).
function isTerminal(appClass, terminals) {
    var cls = String(appClass || "").trim().toLowerCase();
    if (cls === "") return false;
    for (var i = 0; i < terminals.length; i++) {
        var t = String(terminals[i] || "").trim().toLowerCase();
        if (t === "") continue;
        if (cls === t || cls.slice(-(t.length + 1)) === "." + t) return true;
    }
    return false;
}

// wtype arguments that paste into appClass, or [] when there is no window to paste into.
function pasteCommand(appClass, terminals) {
    var cls = String(appClass || "").trim().toLowerCase();
    if (NO_TARGET.indexOf(cls) !== -1) return [];
    if (isTerminal(cls, terminals)) return ["-M", "ctrl", "-M", "shift", "v", "-m", "shift", "-m", "ctrl"];
    return ["-M", "ctrl", "v", "-m", "ctrl"];
}
