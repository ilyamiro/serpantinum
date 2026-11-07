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

## Display manager

**Settings → Display → General** arranges your monitors on a map and changes their resolution, refresh rate, scale, vertical alignment and power, and saves layouts as profiles. It talks to niri through `niri msg`, so it needs nothing beyond niri itself. It requires a niri version with the KDL `include` directive (26.04 has it; older ones can still use the page, but not the persistence below).

### Keep or revert

Moving a screen on the map only prepares the change. **Apply changes** sends it to niri and asks you to keep it. If you do nothing for 15 seconds, or the screen stays black, the previous settings come back by themselves. The timer runs in a separate process, so it still works if the shell crashes. The same goes for loading a profile.

`niri msg output` has no batch mode, so a change is a few commands per monitor (`on`, `mode`, `scale`, `transform`, `position set`), with outputs being enabled before any output is turned off. niri answers success even for an output that does not exist, so Serpantinum checks the result against `niri msg outputs` instead of trusting the exit code. The last enabled output can't be turned off.

Scale accepts quarter steps from 0.5 to 4 in the settings page. A scale you set yourself, such as `1.1`, is kept as it is until you change it.

### Keep the layout after a restart

Changes last for the session. To keep them on the next boot, include Serpantinum's output file at the **end** of `~/.config/niri/config.kdl`, after your own `output` blocks:

```kdl
include "serpantinum/monitors.kdl"
```

The path is relative to the file that contains the `include`. Serpantinum writes only `~/.config/niri/serpantinum/monitors.kdl` and never edits your files. Each block is matched by the panel's `make model serial` (for example `output "Dell Inc. Inspiron 3043 0x00000001" { … }`; niri writes `Unknown` for a missing part), so a layout survives connector names such as `DP-1` and `DP-2` swapping between boots. When two panels report the same identity, or none, the connector name is used instead. The file is checked with `niri validate` before it replaces the old one, which is kept as `monitors.kdl.bak`. Disabled outputs are not saved, so a missing screen at boot can never leave you without an enabled one.

niri reloads its config when the file changes, and the settings written there take effect right away. Because disabled outputs are not written, confirming a layout with a screen turned off can make niri switch that screen back on when the file is reloaded; turn it off again from the page if needed.

### NixOS and Home Manager

If Nix generates `config.kdl`, it is a read-only link and the line cannot be pasted into it. Add the `include` line from your Nix configuration instead (after your output blocks), and keep `~/.config/niri/serpantinum/` writable by linking individual files rather than the whole `~/.config/niri` directory. The settings page shows this variant of the hint when it detects a Nix-managed configuration.

### Recovery from a TTY

If a screen stays black, switch to a text console (`Ctrl+Alt+F3`), log in and run:

```sh
serpantinum display rescue
```

It finds your running niri through `$XDG_RUNTIME_DIR/niri.<display>.<pid>.sock`, restores the last layout that worked, or a safe one with every monitor enabled. A nested niri used for testing (its only output is called `winit`) is never picked over a real session, and a Hyprland or Sway session is never touched by a niri rescue or the other way round. `serpantinum display status`, `revert` and `confirm` inspect or settle a pending change. See the [client commands](/cli/client#display).

State and logs live in `~/.local/state/serpantinum/display/` (`last-good.json`, `display.log`).
