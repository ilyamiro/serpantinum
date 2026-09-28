.pragma library

// Lua sent to Hyprland for per-monitor workspace groups.
//
// Hyprland keeps a workspace on whatever monitor created it, and focusing a
// workspace that lives elsewhere moves the focus there instead of bringing
// it over. With groups that breaks as soon as a workspace from one monitor's
// block ends up on another screen - at startup Hyprland hands out workspaces
// in connector order, not left to right, and a new workspace is created on
// the monitor with keyboard focus, which is not always the one under the
// cursor. Switching to that workspace then jumps to the wrong screen.
//
// Everything runs inside Hyprland as one function dispatch: the shell's own
// view of monitors and workspaces follows events and can lag behind, and one
// dispatch keeps the moves and the focus changes in order.

function luaList(names) {
    return "{ " + names.map(n => JSON.stringify(String(n))).join(", ") + " }";
}

// Shared Lua helpers. `bring(id, mon)` moves workspace `id` onto monitor `mon`
// if it lives elsewhere. When the other monitor is showing it, that monitor
// first gets the first workspace of its own group, so it is not left on
// whatever Hyprland would plug the gap with.
function prelude(names, size) {
    return "local names = " + luaList(names) + "; "
        + "local size = " + size + "; "
        + "local function groupOf(n) for i, v in ipairs(names) do if v == n then return i end end end "
        + "local function monOf(id) local w = hl.get_workspace(id); return w and w.monitor and w.monitor.name end "
        + "local function bring(id, mon) "
        +   "local on = monOf(id); "
        +   "if not on or on == mon then return end "
        +   "local om = hl.get_monitor(on); "
        +   "local ow = om and om.active_workspace; "
        +   "local oi = groupOf(on); "
        +   "if ow and ow.id == id and oi then "
        +     "local first = (oi - 1) * size + 1; "
        +     "local fon = monOf(first); "
        +     "if first ~= id and (not fon or fon == on) then "
        +       "hl.dispatch(hl.dsp.focus({ monitor = on })); "
        +       "hl.dispatch(hl.dsp.focus({ workspace = tostring(first) })); "
        +     "end "
        +   "end "
        +   "on = monOf(id); "
        +   "if on and on ~= mon then "
        +     "hl.dispatch(hl.dsp.workspace.move({ workspace = tostring(id), monitor = mon })); "
        +   "end "
        + "end ";
}

// Focus workspace `id` on monitor `mon` (the screen the user acted on), or
// move the active window there when `action` is "move".
function switchLua(names, size, mon, id, action) {
    return "function() "
        + prelude(names, size)
        + "local mon = " + JSON.stringify(String(mon)) + "; "
        + "local id = " + Math.floor(id) + "; "
        + "local win = hl.get_active_window(); "
        + "bring(id, mon); "
        + (action === "move"
            ? "if win then hl.dispatch(hl.dsp.window.move({ workspace = tostring(id), window = \"address:\" .. win.address })) end "
            : "hl.dispatch(hl.dsp.focus({ monitor = mon })); "
              + "hl.dispatch(hl.dsp.focus({ workspace = tostring(id) })); ")
        // A window moved to a new workspace creates it on the window's monitor.
        + "if monOf(id) and monOf(id) ~= mon then "
        +   "hl.dispatch(hl.dsp.workspace.move({ workspace = tostring(id), monitor = mon })); "
        + "end "
        + "end";
}

// Put every workspace back on the monitor that owns its group, then move
// every monitor showing a workspace outside its group to the first one of
// it. Run at startup, when the screens change and when the setting is
// turned on - never on a regular switch. Focus returns to where it was.
function syncLua(names, size) {
    return "function() "
        + prelude(names, size)
        + "local prev = hl.get_active_monitor(); "
        + "local prevName = prev and prev.name; "
        + "for _, w in ipairs(hl.get_workspaces()) do "
        +   "if w.id >= 1 and not w.special and w.monitor then "
        +     "local owner = names[math.floor((w.id - 1) / size) + 1]; "
        +     "if owner and owner ~= w.monitor.name then bring(w.id, owner) end "
        +   "end "
        + "end "
        + "for i, name in ipairs(names) do "
        +   "local m = hl.get_monitor(name); "
        +   "local ws = m and m.active_workspace; "
        +   "local first = (i - 1) * size + 1; "
        +   "if ws and ws.id >= 1 and (ws.id < first or ws.id >= first + size) then "
        +     "bring(first, name); "
        +     "hl.dispatch(hl.dsp.focus({ monitor = name })); "
        +     "hl.dispatch(hl.dsp.focus({ workspace = tostring(first) })); "
        +   "end "
        + "end "
        + "if prevName then hl.dispatch(hl.dsp.focus({ monitor = prevName })) end "
        + "end";
}
