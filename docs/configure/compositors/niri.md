---
sidebar_position: 2
title: Niri
sidebar_label: Niri
slug: /configure/compositors/niri
---

# Niri

Configuration is stored in `~/.config/niri`. The main file is `config.kdl`, which includes files from the `config/` directory:

- `env.kdl` - environment variables
- `input.kdl` - keyboard layout, touchpad, and mouse settings
- `output.kdl` - display and resolution setup
- `layout.kdl` - gaps, column width, and border settings
- `autostart.kdl` - startup processes
- `keybinds.kdl` - keybindings for compositor actions and shell controls

## Autostart

The shell daemon and clipboard history are launched from `config/autostart.kdl`:

```kdl
spawn-at-startup "bash" "-c" "wl-paste --type text --watch cliphist store"
spawn-at-startup "bash" "-c" "wl-paste --type image --watch cliphist store"
spawn-at-startup "serpantinumd" "start"
```

`serpantinumd start` also starts the [audio engine](/audio).

## Keybindings

Shell overlays and controls are bound in `config/keybinds.kdl` using `spawn "serpantinum" "msg" "toggle" "<module>"`:

- `launcher` - application launcher (`Mod+D`)
- `system` - system control panel (`Mod+B`)
- `clipboard` - clipboard history (`Mod+C`)
- `music` - media player (`Mod+M`)
- `wallpaper` - wallpaper selector (`Mod+W`)
- `calendar` - calendar popout (`Mod+S`)
- `network` - network connections (`Mod+N`)
- `volume` - audio popout (`Mod+V`)
- `settings` - cheat sheet for keybindings (`Mod+H`)

Workspace switching is routed through the shell to update bar indicators:

```kdl
Mod+1 { spawn "serpantinum" "msg" "workspace" "1"; }
Mod+2 { spawn "serpantinum" "msg" "workspace" "2"; }
// ...
Mod+Shift+1 { spawn "serpantinum" "msg" "workspace" "1" "move"; }
```

Quick utility actions:
- Lock screen: `Mod+L { spawn "serpantinum" "lock"; }`
- Reload shell: `Mod+R { spawn "serpantinum" "reload"; }`
- Bar autohide: `Mod+A { spawn "serpantinum" "msg" "bar" "autohide"; }`
- Screenshots: `Print { spawn "serpantinum" "screenshot"; }` (add `--edit` or `--full`)
- Brightness: `XF86MonBrightnessDown` and `XF86MonBrightnessUp`
- Volume: `XF86AudioLowerVolume`, `XF86AudioRaiseVolume`, and `XF86AudioMute`

## Your own overrides

Put your changes in `~/.config/niri/custom/` instead of editing `config/`. There is one file per topic, mirroring the defaults: `env.kdl`, `input.kdl`, `output.kdl`, `layout.kdl`, `autostart.kdl` and `keybinds.kdl`. Each custom file is included right after its default counterpart, so it wins.

To replace a default bind, bind the same key again. To disable one, bind it to `spawn "true"`:

```kdl
binds {
    Mod+Q { spawn "kitty"; }
    Mod+Shift+F { spawn "true"; }
}
```

Installs and updates never overwrite or delete anything in `custom/`. Starter files (comments only) are created only when missing.

When you update, the installer adds the `custom/` load lines to your main config if they are missing (it saves `config.kdl.pre-custom-overrides.bak` first and marks each line with a `serpantinum: custom overrides` comment). Commenting one of these lines out does not stick: it is added back on the next run. If the main config is a symlink or lives in a symlinked folder, the installer does not edit it and prints the lines to add yourself.

Updates also refresh default files you have not edited. Files you changed are kept and listed at the end of the update, so move your changes into `custom/`. Symlinked folders are never written through, and when the installed version cannot be determined, existing files are left alone.
