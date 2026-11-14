local mainMod = _G.mainMod or "SUPER"
local terminal = _G.terminal or "kitty"

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true, description = "Move window" })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true, description = "Resize window" })

hl.bind(mainMod .. " + SHIFT + Left", hl.dsp.window.resize({ x = -50, y = 0, relative = true }), { repeating = true, description = "Resize window left" })
hl.bind(mainMod .. " + SHIFT + Right", hl.dsp.window.resize({ x = 50, y = 0, relative = true }), { repeating = true, description = "Resize window right" })
hl.bind(mainMod .. " + SHIFT + Up", hl.dsp.window.resize({ x = 0, y = -50, relative = true }), { repeating = true, description = "Resize window up" })
hl.bind(mainMod .. " + SHIFT + Down", hl.dsp.window.resize({ x = 0, y = 50, relative = true }), { repeating = true, description = "Resize window down" })

hl.bind(mainMod .. " + CTRL + Left", hl.dsp.window.move({ direction = "l" }), { description = "Move window left" })
hl.bind(mainMod .. " + CTRL + Right", hl.dsp.window.move({ direction = "r" }), { description = "Move window right" })
hl.bind(mainMod .. " + CTRL + Up", hl.dsp.window.move({ direction = "u" }), { description = "Move window up" })
hl.bind(mainMod .. " + CTRL + Down", hl.dsp.window.move({ direction = "d" }), { description = "Move window down" })

hl.bind(mainMod .. " + Left", hl.dsp.focus({ direction = "left" }), { description = "Focus left" })
hl.bind(mainMod .. " + Right", hl.dsp.focus({ direction = "right" }), { description = "Focus right" })
hl.bind(mainMod .. " + Up", hl.dsp.focus({ direction = "up" }), { description = "Focus up" })
hl.bind(mainMod .. " + Down", hl.dsp.focus({ direction = "down" }), { description = "Focus down" })

hl.bind(mainMod .. " + Q", hl.dsp.window.close(), { description = "Close window" })
hl.bind(mainMod .. " + ALT + F", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }), { description = "Toggle fullscreen" })
hl.bind(mainMod .. " + SHIFT + F", hl.dsp.window.float({ action = "toggle" }), { description = "Toggle floating" })

hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("serpantinum brightness lower"), { locked = true, description = "Brightness down" })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("serpantinum brightness raise"), { locked = true, description = "Brightness up" })

hl.bind("Print", hl.dsp.exec_cmd("serpantinum screenshot"), { locked = true, description = "Screenshot region" })
hl.bind("SHIFT + Print", hl.dsp.exec_cmd("serpantinum screenshot --edit"), { locked = true, description = "Screenshot region and edit" })
hl.bind("SUPER + Print", hl.dsp.exec_cmd("serpantinum screenshot --full"), { locked = true, description = "Screenshot full screen" })
hl.bind("SUPER + SHIFT + Print", hl.dsp.exec_cmd("serpantinum screenshot --full --edit"), { locked = true, description = "Screenshot full screen and edit" })

hl.bind("XF86PowerOff", hl.dsp.exec_cmd("serpantinum lock"), { locked = true, description = "Lock screen" })
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("serpantinum lock"), { repeating = true, locked = true, description = "Lock screen" })

hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, description = "Play / pause" })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, description = "Play / pause" })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, description = "Play / pause" })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true, description = "Previous track" })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true, description = "Next track" })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("serpantinum volume mic-toggle"), { locked = true, description = "Mute microphone" })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("serpantinum volume mute-toggle"), { locked = true, description = "Mute audio" })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("serpantinum volume lower"), { repeating = true, locked = true, description = "Volume down" })
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("serpantinum volume raise"), { repeating = true, locked = true, description = "Volume up" })

hl.bind(mainMod .. " + F", hl.dsp.exec_cmd("firefox"), { description = "Firefox" })
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd("ski"), { description = "Files" })
hl.bind(mainMod .. " + RETURN", hl.dsp.exec_cmd(terminal), { description = "Terminal" })

hl.bind(mainMod .. " + R", hl.dsp.exec_cmd("serpantinum reload"), { description = "Reload shell" })
hl.bind(mainMod .. " + C", hl.dsp.exec_cmd("serpantinum msg toggle clipboard"), { description = "Clipboard" })
hl.bind(mainMod .. " + D", hl.dsp.exec_cmd("serpantinum msg toggle launcher"), { description = "Launcher" })
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("serpantinum msg toggle music"), { description = "Music player" })
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd("serpantinum msg toggle system"), { description = "System panel" })
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd("serpantinum msg toggle wallpaper"), { description = "Wallpaper picker" })
hl.bind(mainMod .. " + S", hl.dsp.exec_cmd("serpantinum msg toggle calendar"), { description = "Calendar" })
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd("serpantinum msg toggle network"), { description = "Network" })
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd("serpantinum msg toggle volume"), { description = "Volume panel" })
hl.bind(mainMod .. " + H", hl.dsp.exec_cmd("serpantinum msg toggle settings"), { description = "Settings" })
hl.bind(mainMod .. " + A", hl.dsp.exec_cmd("serpantinum msg bar autohide"), { description = "Toggle bar autohide" })

for i = 1, 10 do
  local ws = tostring(i)
  local key = tostring(i % 10)
  hl.bind(mainMod .. " + " .. key, hl.dsp.exec_cmd("serpantinum msg workspace " .. ws), { description = "Workspace " .. ws })
  hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.exec_cmd("serpantinum msg workspace " .. ws .. " move"), { description = "Move window to workspace " .. ws })
end

-- Shortcuts created in Settings > Keybinds. The file is generated by
-- src/scripts/keybinds.sh and is optional.
local config_home = os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")
pcall(dofile, config_home .. "/hypr/config/keybinds_custom.lua")
