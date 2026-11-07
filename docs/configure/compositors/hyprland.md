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

## Display manager

**Settings → Display → General** arranges your monitors and changes their resolution, refresh rate, scale, vertical alignment and power, and saves layouts as profiles. It is available on Hyprland with the Lua configuration.

### Keep or revert

Moving a screen on the map only prepares the change. **Apply changes** sends it to Hyprland and asks you to keep it. If you do nothing for 15 seconds, or the screen stays black, the previous settings come back by themselves. The timer runs in a separate process, so it still works if the shell crashes. The same goes for loading a profile.

### Keep the layout after a restart

Changes last for the session. To keep them on the next boot, load Serpantinum's monitor file from `hyprland.lua`, after your own monitor rules:

```lua
require("config/monitors")
require("serpantinum/monitors")
```

Serpantinum writes only `~/.config/hypr/serpantinum/monitors.lua` and never edits your files. Monitors are matched by their panel description (for example `desc:Dell Inc. Inspiron 3043 0x00000001`), so a layout survives connector names such as `eDP-1` and `eDP-2` swapping between boots. The file is checked with `Hyprland --verify-config` before it replaces the old one, which is kept as `monitors.lua.bak`.

### NixOS and Home Manager

If Nix generates `hyprland.lua`, it is a read-only link and the line cannot be pasted into it. Add it from your Nix configuration instead, in the same place and after your monitor rules, and link individual files rather than the whole `~/.config/hypr` directory, so that `~/.config/hypr/serpantinum/` stays writable. The settings page shows this variant of the hint when it detects a Nix-managed configuration.

### Recovery from a TTY

If a screen stays black, switch to a text console (`Ctrl+Alt+F3`), log in and run:

```sh
serpantinum display rescue
```

It restores the last layout that worked, or a safe one with every monitor enabled. `serpantinum display status`, `revert` and `confirm` inspect or settle a pending change. See the [client commands](/cli/client#display).

State and logs live in `~/.local/state/serpantinum/display/` (`last-good.json`, `display.log`). Transaction files are kept in `$XDG_RUNTIME_DIR`, or in a private directory under the temporary directory on systems that have none, such as Void Linux without elogind.
