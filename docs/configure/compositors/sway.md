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

## Display manager

**Settings → Display → General** arranges your monitors on a map and changes their resolution, refresh rate, scale, vertical alignment and power, and saves layouts as profiles. It talks to Sway through `swaymsg`, so it needs nothing beyond what Sway already ships.

### Keep or revert

Moving a screen on the map only prepares the change. **Apply changes** sends it to Sway and asks you to keep it. If you do nothing for 15 seconds, or the screen stays black, the previous settings come back by themselves. The timer runs in a separate process, so it still works if the shell crashes. The same goes for loading a profile.

Every change is one `swaymsg output …` command per monitor (`mode`, `position`, `scale`, `transform`), with outputs being enabled before any output is disabled, so there is never a moment with every screen off. The last output can't be turned off.

Scale accepts quarter steps from 0.5 to 4 in the settings page. A scale you set yourself, such as `1.1`, is kept as it is until you change it.

### Keep the layout after a restart

Changes last for the session. To keep them on the next boot, include Serpantinum's output file at the **end** of your Sway config, after your own `output` rules (the last rule for an output wins):

```
include ~/.config/sway/serpantinum/monitors
```

Serpantinum writes only `~/.config/sway/serpantinum/monitors` and never edits your files. Each block is matched by the panel's `make model serial` (for example `output "Dell Inc. Inspiron 3043 0x00000001" { … }`), so a layout survives connector names such as `DP-1` and `DP-2` swapping between boots. When two panels report the same identity, or none, the connector name is used instead. The file is checked with `sway --validate` before it replaces the old one, which is kept as `monitors.bak`. Disabled outputs are not saved, so a missing screen at boot can never leave you without an enabled one.

### NixOS and Home Manager

If Nix generates your Sway config, it is a read-only link and the line cannot be pasted into it. Add the `include` line from your Nix configuration instead (for example in `wayland.windowManager.sway.extraConfig`, after your output rules), and keep `~/.config/sway/serpantinum/` writable by linking individual files rather than the whole `~/.config/sway` directory. The settings page shows this variant of the hint when it detects a Nix-managed configuration.

### Recovery from a TTY

If a screen stays black, switch to a text console (`Ctrl+Alt+F3`), log in and run:

```sh
serpantinum display rescue
```

It finds your running Sway through `$XDG_RUNTIME_DIR/sway-ipc.<uid>.<pid>.sock`, restores the last layout that worked, or a safe one with every monitor enabled. A nested or headless Sway used for testing (outputs named `WAYLAND-1`, `HEADLESS-1`) is never picked over a real session, and a Hyprland session is never touched by a Sway rescue or the other way round. `serpantinum display status`, `revert` and `confirm` inspect or settle a pending change. See the [client commands](/cli/client#display).

State and logs live in `~/.local/state/serpantinum/display/` (`last-good.json`, `display.log`).
