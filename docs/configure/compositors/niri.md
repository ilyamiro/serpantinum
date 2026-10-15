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

The shell daemon, clipboard history, and audio effects are launched from `config/autostart.kdl`:

```kdl
spawn-at-startup "bash" "-c" "wl-paste --type text --watch cliphist store"
spawn-at-startup "bash" "-c" "wl-paste --type image --watch cliphist store"
spawn-at-startup "systemctl" "--user" "enable" "--now" "easyeffects"
spawn-at-startup "serpantinumd" "start"
```

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
- `guide` - cheat sheet for keybindings (`Mod+H`)
- `autohide` - toggle status bar autohide (`Mod+A`)

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
- Screenshots: `Print { spawn "serpantinum" "screenshot"; }` (add `--edit` or `--full`)
- Brightness: `XF86MonBrightnessDown` and `XF86MonBrightnessUp`
- Volume: `XF86AudioLowerVolume`, `XF86AudioRaiseVolume`, and `XF86AudioMute`
