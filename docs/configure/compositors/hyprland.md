---
sidebar_position: 1
title: Hyprland
sidebar_label: Hyprland
slug: /configure/compositors/hyprland
---

# Hyprland

Configuration is stored in `~/.config/hypr`. The main file is `hyprland.lua`, which loads modules from the `config/` directory:

- `variables.lua` - modifier keys, default applications, and the managed window layout mode
- `env.lua` - environment variables
- `autostart.lua` - startup processes
- `monitors.lua` - display and resolution setup
- `settings.lua` - window decorations, blur, animations, and input
- `keybinds.lua` - keybindings for compositor actions and shell controls

## Window layout

`variables.lua` stores the layout mode used by `settings.lua`:

```lua
layoutMode = "mixed"
```

- `tiling` - every window tiles; floating is disabled.
- `mixed` - applications tile, dialogs and utilities float centered (default).
- `floating` - every window floats and opens centered.

Change it from **Settings → Keybinds** or from the command line:

```bash
serpantinum layout tiling
serpantinum layout mixed
serpantinum layout floating
```

The value is also stored in `settings.json` as `windowLayout.mode`, so the last selected mode is restored on the next login. Floating and tiled states of already-open windows are updated immediately.

## Autostart

The shell daemon and clipboard history are launched from `config/autostart.lua`:

```lua
hl.on("hyprland.start", function()
  hl.exec_cmd("wl-paste --type text --watch cliphist store")
  hl.exec_cmd("wl-paste --type image --watch cliphist store")
  hl.exec_cmd("serpantinumd start")
end)
```

`serpantinumd start` also starts the [audio engine](/audio).

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
- `settings` - open Serpantinum settings; the **Keybinds** tab lists all active shortcuts, lets you edit or translate their descriptions, switch the window layout mode, and add your own shortcuts with the **+** button

Workspace switching is routed through the shell to update bar indicators:

```lua
for i = 1, 10 do
  hl.bind("SUPER + " .. (i % 10), hl.dsp.exec_cmd("serpantinum msg workspace " .. i))
  hl.bind("SUPER + SHIFT + " .. (i % 10), hl.dsp.exec_cmd("serpantinum msg workspace " .. i .. " move"))
end
```

Custom shortcuts created with **+** in the Keybinds tab are stored in `settings.json` as `keybinds.custom` and written to `config/keybinds_custom.lua`, which `config/keybinds.lua` loads at the end. The generated file is rewritten on every change and must not be edited by hand.

Quick utility actions:
- Lock screen: `serpantinum lock`
- Reload shell: `serpantinum reload`
- Bar autohide: `serpantinum msg bar autohide`
- Screenshots: `serpantinum screenshot` (add `--edit`, `--full`, or `--full --edit`)
- Brightness: `serpantinum brightness lower` and `serpantinum brightness raise`
- Volume: `serpantinum volume lower`, `serpantinum volume raise`, and `serpantinum volume mute-toggle`
