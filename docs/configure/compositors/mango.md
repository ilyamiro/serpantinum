---
sidebar_position: 4
title: Mango
sidebar_label: Mango
slug: /configure/compositors/mango
---

# Mango

Configuration is stored in `~/.config/mango`. The main file is `config.conf`, which includes modular files from `config/`:

- `input` - keyboard layout and touchpad settings
- `layout` - tag count, window borders, and gaps
- `autostart` - startup processes
- `keybinds` - keybindings for compositor actions and shell controls

The bundled files use the option names of Mango 0.18. Older releases used different names (for example `gappih` and `exec-once`), so update to 0.18 or later. Validate a config without starting the compositor using `mango -c ~/.config/mango/config.conf -p`.

## Autostart

The shell daemon and clipboard history are launched from `config/autostart.conf`:

```ini
exec_once=wl-paste --type text --watch cliphist store
exec_once=wl-paste --type image --watch cliphist store
exec_once=serpantinumd start
```

`serpantinumd start` also starts the [audio engine](/audio).

## Keybindings

Shell overlays and controls are bound in `config/keybinds.conf` using `spawn,serpantinum msg toggle <module>`, with the same keys as the other compositors:

```ini
bind=SUPER,D,spawn,serpantinum msg toggle launcher
bind=SUPER,B,spawn,serpantinum msg toggle system
```

Tag switching is routed through the shell to update bar indicators. Mango has nine tags by default (`tag_num`):

```ini
bind=SUPER,1,spawn,serpantinum msg workspace 1
bind=SUPER+SHIFT,1,spawn,serpantinum msg workspace 1 move
```

## Your own overrides

Put your changes in `~/.config/mango/custom/` instead of editing `config/`. There is one file per topic, mirroring the defaults: `input.conf`, `layout.conf`, `autostart.conf` and `keybinds.conf`. Each custom file loads right after its default counterpart, except `keybinds.conf`, which loads before the default keybinds because Mango uses the first matching bind.

A `bind=` in `custom/keybinds.conf` therefore wins over the default on the same key. To disable a default bind, bind it to a harmless command:

```
bind=SUPER,Q,spawn,kitty
bind=SUPER,Q,spawn,true
```

A custom bind with the `c` flag (for example `bindc=`) lets the default bind run as well.
Installs and updates never overwrite or delete anything in `custom/`. Starter files (comments only) are created only when missing.

When you update, the installer adds the `custom/` load lines to your main config if they are missing (it saves `config.conf.pre-custom-overrides.bak` first and marks each line with a `serpantinum: custom overrides` comment). Commenting one of these lines out does not stick: it is added back on the next run. If the main config is a symlink or lives in a symlinked folder, the installer does not edit it and prints the lines to add yourself.

Updates also refresh default files you have not edited. Files you changed are kept and listed at the end of the update, so move your changes into `custom/`. Symlinked folders are never written through, and when the installed version cannot be determined, existing files are left alone.

## Tags

Mango uses tags instead of workspaces. The bar shows the lowest active tag of each monitor as the current workspace and marks tags that hold windows as occupied.

## Limitations

- The UI scale setting is hidden because output scale cannot be changed at runtime. Set it with `monitor_rule` in the config.
- The output toggle in display settings puts the monitor to sleep instead of removing it.
