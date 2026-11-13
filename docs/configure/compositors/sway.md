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

Workspace switching is routed through the shell to update bar indicators:

```ini
bindsym $mod+1 exec serpantinum msg workspace 1
bindsym $mod+Shift+1 exec serpantinum msg workspace 1 move
# ... up to workspace 10 ($mod+0)
```

Quick utility actions:
- Lock screen: `$mod+L exec serpantinum lock`
- Reload shell: `$mod+R exec serpantinum reload`
- Bar autohide: `$mod+A exec serpantinum msg bar autohide`
- Screenshots: `Print exec serpantinum screenshot` (add `--edit` or `--full`)
- Brightness: `XF86MonBrightnessDown` and `XF86MonBrightnessUp`
- Volume: `XF86AudioLowerVolume`, `XF86AudioRaiseVolume`, and `XF86AudioMute`

## Your own overrides

Put your changes in `~/.config/sway/custom/` instead of editing `configDir/`. There is one file per topic, mirroring the defaults: `variables`, `input`, `output`, `layout`, `autostart` and `keybinds`. Each custom file is included right after its default counterpart, so a later `bindsym` wins.

To replace a default bind, bind the same key again. To remove one, use `unbindsym`:

```
bindsym $mod+q exec kitty
unbindsym $mod+Shift+q
```

Installs and updates never overwrite or delete anything in `custom/`. Starter files (comments only) are created only when missing.

When you update, the installer adds the `custom/` load lines to your main config if they are missing (it saves `config.pre-custom-overrides.bak` first and marks each line with a `serpantinum: custom overrides` comment). Commenting one of these lines out does not stick: it is added back on the next run. If the main config is a symlink or lives in a symlinked folder, the installer does not edit it and prints the lines to add yourself.

Updates also refresh default files you have not edited. Files you changed are kept and listed at the end of the update, so move your changes into `custom/`. Symlinked folders are never written through, and when the installed version cannot be determined, existing files are left alone.
