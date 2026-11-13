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
- `settings` - cheat sheet for keybindings

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
- Bar autohide: `serpantinum msg bar autohide`
- Screenshots: `serpantinum screenshot` (add `--edit`, `--full`, or `--full --edit`)
- Brightness: `serpantinum brightness lower` and `serpantinum brightness raise`
- Volume: `serpantinum volume lower`, `serpantinum volume raise`, and `serpantinum volume mute-toggle`

## Your own overrides

Put your changes in `~/.config/hypr/custom/` instead of editing `config/`. There is one file per topic, mirroring the defaults: `variables.lua`, `env.lua`, `autostart.lua`, `monitors.lua`, `settings.lua` and `keybinds.lua`. Each custom file loads right after its default counterpart, so it wins.

To replace a default bind, bind the same key in `custom/keybinds.lua`. The default on that key is removed first. To remove a bind, use `hl.unbind`:

```lua
hl.bind("SUPER + Q", hl.dsp.exec_cmd("kitty"))
hl.unbind("SUPER + SHIFT + Q")
```

To change the modifier used by the default binds, set it in `custom/variables.lua`:

```lua
_G.mainMod = "ALT"
```

An error in a custom file is shown as a notification and does not stop the rest of the config.

Installs and updates never overwrite or delete anything in `custom/`. Starter files (comments only) are created only when missing.

When you update, the installer adds the `custom/` load lines to your main config if they are missing (it saves `hyprland.lua.pre-custom-overrides.bak` first and marks each line with a `serpantinum: custom overrides` comment). Commenting one of these lines out does not stick: it is added back on the next run. If the main config is a symlink, lives in a symlinked folder, or is missing `config/custom.lua`, the installer does not edit it and prints the lines to add yourself.

Updates also refresh default files you have not edited. Files you changed are kept and listed at the end of the update, so move your changes into `custom/`. Symlinked folders are never written through, and when the installed version cannot be determined, existing files are left alone.
