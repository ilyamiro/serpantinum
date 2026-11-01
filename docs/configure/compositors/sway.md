---
sidebar_position: 3
title: Sway
sidebar_label: Sway
slug: /configure/compositors/sway
---

# Sway

Configuration is stored in `~/.config/sway`. The main file is `config`, which includes modular files from `configDir/`:

- `variables` - modifier keys and default applications
- `input` - keyboard and touchpad settings
- `output` - display and monitor configurations
- `layout` - window borders and gaps
- `autostart` - startup processes
- `window-rules` - floating window rules and assignments
- `keybinds` - keybindings for compositor actions and shell controls

## Autostart

The shell daemon and clipboard history are launched from `configDir/autostart`:

```ini
exec wl-paste --type text --watch cliphist store
exec wl-paste --type image --watch cliphist store
exec serpantinumd start
```

`serpantinumd start` also starts the [audio engine](/audio).

## Keybindings

Shell overlays and controls are bound in `configDir/keybinds` using `exec serpantinum msg toggle <module>`:

- `launcher` - application launcher (`$mod+D`)
- `system` - system control panel (`$mod+B`)
- `clipboard` - clipboard history (`$mod+C`)
- `music` - media player (`$mod+M`)
- `wallpaper` - wallpaper selector (`$mod+W`)
- `calendar` - calendar popout (`$mod+S`)
- `network` - network connections (`$mod+N`)
- `volume` - audio popout (`$mod+V`)
- `settings` - cheat sheet for keybindings (`$mod+H`)
- `autohide` - toggle status bar autohide (`$mod+A`)

Workspace switching is routed through the shell to update bar indicators:

```ini
bindsym $mod+1 exec serpantinum msg workspace 1
bindsym $mod+Shift+1 exec serpantinum msg workspace 1 move
# ... up to workspace 10 ($mod+0)
```

Quick utility actions:
- Lock screen: `$mod+L exec serpantinum lock`
- Reload shell: `$mod+R exec serpantinum reload`
- Screenshots: `Print exec serpantinum screenshot` (add `--edit` or `--full`)
- Brightness: `XF86MonBrightnessDown` and `XF86MonBrightnessUp`
- Volume: `XF86AudioLowerVolume`, `XF86AudioRaiseVolume`, and `XF86AudioMute`
