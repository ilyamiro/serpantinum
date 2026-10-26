---
sidebar_position: 1
title: Hyprland
sidebar_label: Hyprland
slug: /configure/compositors/hyprland
---

# Hyprland

Configuration is stored in `~/.config/hypr`. The main file is `hyprland.lua`, which loads modules from the `config/` directory:

- `variables.lua` - modifier keys and default applications
- `env.lua` - environment variables
- `autostart.lua` - startup processes
- `monitors.lua` - display and resolution setup
- `settings.lua` - window decorations, blur, animations, and input
- `keybinds.lua` - keybindings for compositor actions and shell controls

## Autostart

The shell daemon, clipboard history, and audio effects are launched from `config/autostart.lua`:

```lua
hl.on("hyprland.start", function()
  hl.exec_cmd("wl-paste --type text --watch cliphist store")
  hl.exec_cmd("wl-paste --type image --watch cliphist store")
  hl.exec_cmd("systemctl --user enable --now easyeffects")
  hl.exec_cmd("serpantinumd start")
end)
```

## Keybindings

Shell overlays and controls are bound in `config/keybinds.lua` using `serpantinum msg toggle <module>`:

- `launcher` - application launcher
- `system` - system control panel
- `clipboard` - clipboard history
- `music` - media player
- `wallpaper` - wallpaper selector
- `calendar` - calendar popout
- `network` - wi-fi and network connections
- `volume` - audio output and input slider
- `settings` - cheat sheet for keybindings
- `autohide` - toggle status bar autohide

Workspace switching is routed through the shell to update bar indicators:

```lua
for i = 1, 10 do
  hl.bind("SUPER + " .. (i % 10), hl.dsp.exec_cmd("serpantinum msg workspace " .. i))
  hl.bind("SUPER + SHIFT + " .. (i % 10), hl.dsp.exec_cmd("serpantinum msg workspace " .. i .. " move"))
end
```

Quick utility actions:
- Lock screen: `serpantinum lock`
- Reload shell: `serpantinum reload`
- Screenshots: `serpantinum screenshot` (add `--edit`, `--full`, or `--full --edit`)
- Brightness: `serpantinum brightness lower` and `serpantinum brightness raise`
- Volume: `serpantinum volume lower`, `serpantinum volume raise`, and `serpantinum volume mute-toggle`