local mainMod = _G.mainMod or "SUPER"
local terminal = _G.terminal or "kitty"

-- Cyrillic keysym mappings for dual-layout support (US + RU)
local ru_keysyms = {
  Q = { "Cyrillic_shorti", "Cyrillic_SHORTI" },
  W = { "Cyrillic_tse", "Cyrillic_TSE" },
  E = { "Cyrillic_u", "Cyrillic_U" },
  R = { "Cyrillic_ka", "Cyrillic_KA" },
  T = { "Cyrillic_ie", "Cyrillic_IE" },
  Y = { "Cyrillic_en", "Cyrillic_EN" },
  U = { "Cyrillic_ge", "Cyrillic_GE" },
  I = { "Cyrillic_sha", "Cyrillic_SHA" },
  O = { "Cyrillic_shcha", "Cyrillic_SHCHA" },
  P = { "Cyrillic_ze", "Cyrillic_ZE" },
  A = { "Cyrillic_ef", "Cyrillic_EF" },
  S = { "Cyrillic_yeru", "Cyrillic_YERU" },
  D = { "Cyrillic_ve", "Cyrillic_VE" },
  F = { "Cyrillic_a", "Cyrillic_A" },
  G = { "Cyrillic_pe", "Cyrillic_PE" },
  H = { "Cyrillic_er", "Cyrillic_ER" },
  J = { "Cyrillic_o", "Cyrillic_O" },
  K = { "Cyrillic_el", "Cyrillic_EL" },
  L = { "Cyrillic_de", "Cyrillic_DE" },
  Z = { "Cyrillic_ya", "Cyrillic_YA" },
  X = { "Cyrillic_che", "Cyrillic_CHE" },
  C = { "Cyrillic_es", "Cyrillic_ES" },
  V = { "Cyrillic_em", "Cyrillic_EM" },
  B = { "Cyrillic_i", "Cyrillic_I" },
  N = { "Cyrillic_te", "Cyrillic_TE" },
  M = { "Cyrillic_softsign", "Cyrillic_SOFTSIGN" },
}

local function bind(combo, action, opts)
  hl.bind(combo, action, opts)
  local prefix, key = combo:match("^(.-%+%s*)([%a%d_]+)$")
  if not prefix then
    key = combo:match("^%s*([%a%d_]+)%s*$")
    prefix = ""
  end
  if key and ru_keysyms[key:upper()] then
    for _, sym in ipairs(ru_keysyms[key:upper()]) do
      hl.bind(prefix .. sym, action, opts)
    end
  end
end

-- Mouse window controls
bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Focus windows with arrow keys
bind(mainMod .. " + Left", hl.dsp.focus({ direction = "left" }))
bind(mainMod .. " + Right", hl.dsp.focus({ direction = "right" }))
bind(mainMod .. " + Up", hl.dsp.focus({ direction = "up" }))
bind(mainMod .. " + Down", hl.dsp.focus({ direction = "down" }))

-- Swap windows with SHIFT + arrow keys
bind(mainMod .. " + SHIFT + Left", hl.dsp.window.swap({ direction = "left" }))
bind(mainMod .. " + SHIFT + Right", hl.dsp.window.swap({ direction = "right" }))
bind(mainMod .. " + SHIFT + Up", hl.dsp.window.swap({ direction = "up" }))
bind(mainMod .. " + SHIFT + Down", hl.dsp.window.swap({ direction = "down" }))

-- Move window in direction with CTRL + arrow keys
bind(mainMod .. " + CTRL + Left", hl.dsp.window.move({ direction = "l" }))
bind(mainMod .. " + CTRL + Right", hl.dsp.window.move({ direction = "r" }))
bind(mainMod .. " + CTRL + Up", hl.dsp.window.move({ direction = "u" }))
bind(mainMod .. " + CTRL + Down", hl.dsp.window.move({ direction = "d" }))

-- Window state management
bind(mainMod .. " + Q", hl.dsp.window.close())
bind(mainMod .. " + F", hl.dsp.window.fullscreen())
bind(mainMod .. " + ALT + F", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }))
bind(mainMod .. " + ALT + SPACE", hl.dsp.window.float({ action = "toggle" }))

-- Apps
bind(mainMod .. " + RETURN", hl.dsp.exec_cmd(terminal))
bind(mainMod .. " + E", hl.dsp.exec_cmd("nautilus"))

-- Serpantinum Shell Widgets & Toggles
bind(mainMod .. " + SPACE", hl.dsp.exec_cmd("serpantinum msg toggle launcher"))
bind(mainMod .. " + V", hl.dsp.exec_cmd("serpantinum msg toggle clipboard"))
bind(mainMod .. " + B", hl.dsp.exec_cmd("serpantinum msg toggle wallpaper"))
bind(mainMod .. " + D", hl.dsp.exec_cmd("serpantinum msg toggle system"))
bind(mainMod .. " + backslash", hl.dsp.exec_cmd("serpantinum msg toggle settings"))
bind(mainMod .. " + A", hl.dsp.exec_cmd("serpantinum msg toggle autohide"))
bind(mainMod .. " + SHIFT + R", hl.dsp.exec_cmd("serpantinum reload"))

-- Screen Lock
bind("XF86PowerOff", hl.dsp.exec_cmd("serpantinum lock"), { locked = true })
bind(mainMod .. " + L", hl.dsp.exec_cmd("serpantinum lock"), { repeating = true, locked = true })

-- Screenshots
bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("serpantinum screenshot"))
bind(mainMod .. " + SHIFT + s", hl.dsp.exec_cmd("serpantinum screenshot"))
bind("Print", hl.dsp.exec_cmd("serpantinum screenshot"))
bind("SHIFT + Print", hl.dsp.exec_cmd("serpantinum screenshot --edit"))
bind("SUPER + Print", hl.dsp.exec_cmd("serpantinum screenshot --full"))
bind("SUPER + SHIFT + Print", hl.dsp.exec_cmd("serpantinum screenshot --full --edit"))

-- Brightness
bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("serpantinum brightness lower"), { locked = true })
bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("serpantinum brightness raise"), { locked = true })

-- Audio & Media Controls
bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
bind("XF86AudioMicMute", hl.dsp.exec_cmd("serpantinum volume mic-toggle"), { locked = true })
bind("XF86AudioMute", hl.dsp.exec_cmd("serpantinum volume mute-toggle"), { locked = true })
bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("serpantinum volume lower"), { repeating = true, locked = true })
bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("serpantinum volume raise"), { repeating = true, locked = true })

-- Workspaces (native Hyprland dispatchers for instant 0ms latency)
for i = 1, 10 do
  local ws = tostring(i)
  local key = tostring(i % 10)
  hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = ws }))
  hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = ws }))
end

-- Scroll through workspaces with mainMod + scroll
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

