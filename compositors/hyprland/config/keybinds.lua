local mainMod = _G.mainMod or "SUPER"
local terminal = _G.terminal or "kitty"

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true , description = "keybinds.windows.drag" })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true , description = "keybinds.windows.resize_mouse" })

hl.bind(mainMod .. " + SHIFT + Left", hl.dsp.window.resize({ x = -50, y = 0, relative = true }), { repeating = true , description = "keybinds.windows.resize" })
hl.bind(mainMod .. " + SHIFT + Right", hl.dsp.window.resize({ x = 50, y = 0, relative = true }), { repeating = true , description = "keybinds.windows.resize" })
hl.bind(mainMod .. " + SHIFT + Up", hl.dsp.window.resize({ x = 0, y = -50, relative = true }), { repeating = true , description = "keybinds.windows.resize" })
hl.bind(mainMod .. " + SHIFT + Down", hl.dsp.window.resize({ x = 0, y = 50, relative = true }), { repeating = true , description = "keybinds.windows.resize" })

hl.bind(mainMod .. " + CTRL + Left", hl.dsp.window.move({ direction = "l" }), { description = "keybinds.windows.move" })
hl.bind(mainMod .. " + CTRL + Right", hl.dsp.window.move({ direction = "r" }), { description = "keybinds.windows.move" })
hl.bind(mainMod .. " + CTRL + Up", hl.dsp.window.move({ direction = "u" }), { description = "keybinds.windows.move" })
hl.bind(mainMod .. " + CTRL + Down", hl.dsp.window.move({ direction = "d" }), { description = "keybinds.windows.move" })

hl.bind(mainMod .. " + Left", hl.dsp.focus({ direction = "left" }), { description = "keybinds.windows.focus" })
hl.bind(mainMod .. " + Right", hl.dsp.focus({ direction = "right" }), { description = "keybinds.windows.focus" })
hl.bind(mainMod .. " + Up", hl.dsp.focus({ direction = "up" }), { description = "keybinds.windows.focus" })
hl.bind(mainMod .. " + Down", hl.dsp.focus({ direction = "down" }), { description = "keybinds.windows.focus" })

hl.bind(mainMod .. " + Q", hl.dsp.window.close(), { description = "keybinds.windows.close" })
hl.bind(mainMod .. " + ALT + F", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }), { description = "keybinds.windows.fullscreen" })
hl.bind(mainMod .. " + SHIFT + F", hl.dsp.window.float({ action = "toggle" }), { description = "keybinds.windows.float" })

hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("serpantinum brightness lower"), { locked = true , description = "keybinds.system.brightness_down" })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("serpantinum brightness raise"), { locked = true , description = "keybinds.system.brightness_up" })

hl.bind("Print", hl.dsp.exec_cmd("serpantinum screenshot"), { locked = true , description = "keybinds.screenshot.area" })
hl.bind("SHIFT + Print", hl.dsp.exec_cmd("serpantinum screenshot --edit"), { locked = true , description = "keybinds.screenshot.area_edit" })
hl.bind("SUPER + Print", hl.dsp.exec_cmd("serpantinum screenshot --full"), { locked = true , description = "keybinds.screenshot.full" })
hl.bind("SUPER + SHIFT + Print", hl.dsp.exec_cmd("serpantinum screenshot --full --edit"), { locked = true , description = "keybinds.screenshot.full_edit" })

hl.bind("XF86PowerOff", hl.dsp.exec_cmd("serpantinum lock"), { locked = true , description = "keybinds.system.lock" })
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("serpantinum lock"), { repeating = true, locked = true , description = "keybinds.system.lock" })

hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true , description = "keybinds.media.play_pause" })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true , description = "keybinds.media.play_pause" })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true , description = "keybinds.media.play_pause" })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true , description = "keybinds.media.previous" })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true , description = "keybinds.media.next" })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("serpantinum volume mic-toggle"), { locked = true , description = "keybinds.media.mic_mute" })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("serpantinum volume mute-toggle"), { locked = true , description = "keybinds.media.mute" })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("serpantinum volume lower"), { repeating = true, locked = true , description = "keybinds.media.volume_down" })
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("serpantinum volume raise"), { repeating = true, locked = true , description = "keybinds.media.volume_up" })

hl.bind(mainMod .. " + F", hl.dsp.exec_cmd("firefox"), { description = "keybinds.apps.browser" })
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd("nautilus"), { description = "keybinds.apps.files" })
hl.bind(mainMod .. " + RETURN", hl.dsp.exec_cmd(terminal), { description = "keybinds.apps.terminal" })

hl.bind(mainMod .. " + R", hl.dsp.exec_cmd("serpantinum reload"), { description = "keybinds.shell.reload" })
hl.bind(mainMod .. " + C", hl.dsp.exec_cmd("serpantinum msg toggle clipboard"), { description = "keybinds.shell.clipboard" })
hl.bind(mainMod .. " + D", hl.dsp.exec_cmd("serpantinum msg toggle launcher"), { description = "keybinds.shell.launcher" })
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("serpantinum msg toggle music"), { description = "keybinds.shell.music" })
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd("serpantinum msg toggle system"), { description = "keybinds.shell.system" })
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd("serpantinum msg toggle wallpaper"), { description = "keybinds.shell.wallpaper" })
hl.bind(mainMod .. " + S", hl.dsp.exec_cmd("serpantinum msg toggle calendar"), { description = "keybinds.shell.calendar" })
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd("serpantinum msg toggle network"), { description = "keybinds.shell.network" })
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd("serpantinum msg toggle volume"), { description = "keybinds.shell.volume" })
hl.bind(mainMod .. " + H", hl.dsp.exec_cmd("serpantinum msg toggle settings"), { description = "keybinds.shell.guide" })
hl.bind(mainMod .. " + A", hl.dsp.exec_cmd("serpantinum msg toggle autohide"), { description = "keybinds.shell.autohide" })
hl.bind(mainMod .. " + slash", hl.dsp.exec_cmd("serpantinum msg toggle keybinds"), { description = "keybinds.shell.keybinds" })

for i = 1, 10 do
  local ws = tostring(i)
  local key = tostring(i % 10)
  hl.bind(mainMod .. " + " .. key, hl.dsp.exec_cmd("serpantinum msg workspace " .. ws), { description = "keybinds.workspaces.go" })
  hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.exec_cmd("serpantinum msg workspace " .. ws .. " move"), { description = "keybinds.workspaces.move" })
end
