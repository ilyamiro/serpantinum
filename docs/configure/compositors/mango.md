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

## Tags

Mango uses tags instead of workspaces. The bar shows the lowest active tag of each monitor as the current workspace and marks tags that hold windows as occupied.

## Display manager

**Settings → Display → General** arranges your monitors on a map and changes their resolution, refresh rate, scale, vertical alignment and power, and saves layouts as profiles. `mmsg` can't describe monitors well enough (no modes, make, model or serial, and its `active` flag means *focused*, not *on*), so Serpantinum reads and changes the layout with **`wlr-randr`**, which talks to Mango over the standard `wlr-output-management` protocol. Install it (`pacman -S wlr-randr`; it is a dependency of the Arch, Nix and installer packages). Without it the page stays read-only and says so.

### Keep or revert

Moving a screen on the map only prepares the change. **Apply changes** sends it to Mango and asks you to keep it. If you do nothing for 15 seconds, or the screen stays black, the previous settings come back by themselves. The timer runs in a separate process, so it still works if the shell crashes. The same goes for loading a profile.

Mango applies the outputs of one request one by one, keeps going after a failure and does not stop you from turning every output off. So Serpantinum first checks the whole change with `wlr-randr --dryrun` (a rejected change applies nothing), then enables and reconfigures outputs in one request, sets the position of any output that was off in a second one (Mango auto-places a re-enabled output to the right of the others, ignoring `--pos`), and only then turns outputs off in a last request. The last enabled output can't be turned off.

Scale accepts quarter steps from 0.5 to 4. Positions can't be negative in Mango, so move the other monitors instead.

### Keep the layout after a restart

Changes last for the session. To keep them, add this line to `~/.config/mango/config.conf` **twice**: as the very first line and as the last line:

```ini
source_optional=./serpantinum/monitors.conf
```

Why twice: at startup Mango applies the **first** `monitor_rule` that matches an output, but when it reloads its config it applies the **last** one. One line at the top wins at boot and loses on the next reload; one at the bottom is the opposite. With both, Serpantinum's rules win in either case, whatever rules you have in between. `source_optional` does not complain while the file does not exist yet.

Serpantinum writes only `~/.config/mango/serpantinum/monitors.conf` and never edits your files. Each rule is matched by the panel's `make`, `model` and `serial` (all three must match) so a layout survives connector names swapping between boots. When two panels report the same identity, an identity is incomplete, or it contains characters that Mango's one-line parser would misread (`, : # $ " ' = \`), the connector name is used instead, written as an anchored regex (`name:^HDMI\-A\-1$`, because `name` is a regular expression). The file is checked with `mango -p` before it replaces the old one, which is kept as `monitors.conf.bak`. Disabled outputs are not saved, so a missing screen at boot can never leave you without an enabled one.

Mango reloads its config a moment after any file it reads changes, including this one, and a reload re-applies every `monitor_rule` to every monitor. That would silently undo what you just confirmed (a rule of yours that wins over ours, or a screen you turned off, which is not written), so right after saving, Serpantinum checks the layout and applies the confirmed one again if the reload changed it. A screen you turned off stays off for the session; after a restart or a manual config reload it comes back on, because disabled outputs are never written. (Mango only watches files that existed when it started, so the very first save of a new session may not trigger a reload at all.) Mango also reads `~/.config/mango/config.toml` when there is no `config.conf`; the page only detects the line in `config.conf`.

### NixOS and Home Manager

If Nix generates `config.conf`, it is a read-only link. Add the two `source_optional` lines from your Nix configuration instead, and keep `~/.config/mango/serpantinum/` writable. The settings page shows this variant of the hint when it detects a Nix-managed configuration.

### Recovery from a TTY

If a screen stays black, switch to a text console (`Ctrl+Alt+F3`), log in and run:

```sh
serpantinum display rescue
```

It finds your running Mango through `$XDG_RUNTIME_DIR/mango-<pid>.sock` and its Wayland display by asking which `wayland-N` socket that process serves (so `wlr-randr` can never be pointed at another compositor), restores the last layout that worked, or a safe one with every monitor enabled. A nested Mango used for testing (its outputs are called `WAYLAND-1` or `HEADLESS-1`) is never picked over a real session, and Hyprland, Sway or niri sessions are never touched by a Mango rescue or the other way round. `serpantinum display status`, `revert` and `confirm` inspect or settle a pending change. See the [client commands](/cli/client#display).

State and logs live in `~/.local/state/serpantinum/display/` (`last-good.json`, `display.log`).

## Limitations

- Mango's `focused` monitor is not shown on the display page (`wlr-randr` doesn't report it).
- Without `wlr-randr`, the display page falls back to the read-only view that comes with Serpantinum: the UI scale setting is hidden and the output toggle puts the monitor to sleep instead of removing it.
