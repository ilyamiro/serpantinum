---
sidebar_position: 1
title: Serpantinum client
sidebar_label: Serpantinum client
slug: /cli/client
---

# Serpantinum client

`serpantinum` is the command-line client for the desktop shell.

## Overview

| Command | Purpose |
| --- | --- |
| `msg` | Open, close or toggle panels and switch workspaces. |
| `settings` | Open the settings window, optionally on a given tab. |
| `launch` | Run standalone components such as the setup wizard or the layout editors. |
| `config` | Read and write raw settings. |
| `info` | Print the current state of a setting. |
| `set` | Change a setting. |
| `trigger` | Run a one-off action. |
| `ipc` | Send raw IPC calls to the running shell. |
| `kill`, `restart` | Stop or restart the daemon. |
| [Script shortcuts](#script-shortcuts) | Wrappers around the bundled scripts, such as `lock`, `volume` or `reboot`. |

## Options

- `-v, --verbose`: Enable verbose logging output.
- `-V, --version`: Print installed version and exit.
- `-h, --help`: Show usage help and exit.

## Commands

### `msg`

Dispatches layout, workspace, and overlay actions to the shell:

- `serpantinum msg workspace <number>`: Switch to workspace `<number>`.
- `serpantinum msg workspace <number> move`: Move active window to workspace `<number>`.
- `serpantinum msg <number>`: Shorthand to switch to workspace `<number>`.
- `serpantinum msg <number> move`: Shorthand to move active window to workspace `<number>`.
- `serpantinum msg open <target> [subtarget]`: Open a panel or activate a subtab.
- `serpantinum msg toggle <target> [subtarget]`: Toggle panel visibility.
- `serpantinum msg close`: Close any open overlay.
- `serpantinum msg notifications clear`: Clear all notifications.
- `serpantinum msg network airplane`: Toggle airplane mode (WiFi and Bluetooth).
- `serpantinum msg bar autohide`: Toggle bar autohide live.

#### Targets

- `launcher`: Application search and launcher overlay.
- `clipboard` (alias: `clip`): Clipboard history manager.
- `network`: Network manager popup.
  - `network wifi`: Open directly on WiFi tab.
  - `network ethernet`: Open directly on Ethernet tab.
- `volume`: Audio mixer and device picker.
- `settings`: Settings panel or window (same as [`serpantinum settings`](#settings)).
  - `settings keybinds`: Open shortcut cheat sheet tab.
  - `settings appearance`: Open appearance and styling tab.
  - `guide` is a deprecated alias for `settings` and prints a warning.
- `calendar`: Calendar, clock, and schedule panel.
- `music`: Media player controls and track artwork.
- `wallpaper`: Wallpaper picker and live preview.
- `notifications`: Notification history center.
- `system`: System resource monitor and power controls.

### `settings`

Opens the settings as a panel inside the shell, like other popups.

- `serpantinum settings`: Open the settings.
- `serpantinum settings <tab> [subtab]`: Open directly on a tab, for example `serpantinum settings theme`.
- `serpantinum settings toggle [tab]`: Close the settings if they are open, otherwise open them.
- `serpantinum settings close`: Close the settings.

### `launch`

Runs standalone interface components in runner mode:

- `serpantinum launch start [args...]`: Launch first-time setup and onboarding wizard.

### `ipc`

Sends raw IPC calls directly to the running shell:

- `serpantinum ipc call <target> <method> [args...]`: Forward call to target object.
  - `ipc call main handleCommand <cmd> <target> <arg>`: Dispatch generic UI command.
  - `ipc call main forceReload`: Force reload shell components.
  - `ipc call main clearNotifications`: Purge all notification popups and history.
  - `ipc call lock activate`: Trigger lock screen immediately.
  - `ipc call screenshotOverlay toggle [args...]`: Toggle interactive screenshot overlay.
  - `ipc call floating toggle`: Open the quick actions panel on the last used tab, or close it if it is open on any screen. Bind it to a key in your compositor, e.g. Hyprland: `hl.bind(mainMod .. " + SHIFT + A", hl.dsp.exec_cmd("serpantinum ipc call floating toggle"))`.
  - `ipc call floating open` / `close`: Open the panel on the screen under the cursor, or close it on every screen. Opened this way, it stays until closed, Escape is pressed, or the pointer enters and leaves it.

### `kill`

Stops the daemon and terminates all background shell workers (`serpantinum-core screentime track`, `quickshell`, `serpantinumd`).

### `restart`

Stops the daemon and starts it again.

## Settings and state

### `config`

Reads and writes `settings.json`. Keys use dots to reach nested values and changes apply live:

- `serpantinum config get <key> [fallback]`: Print a setting.
- `serpantinum config set <key> <value>`: Set a setting. Values are parsed as JSON and fall back to plain strings.
- `serpantinum config dump`: Print the whole settings file.
- `serpantinum config path`: Print the settings file path.
- `serpantinum config edit`: Open the settings file in `$VISUAL` or `$EDITOR`.

### `info`

Prints the current state of a group as JSON. Add a key to print just that value, for example `serpantinum info dock autohide`. Lists print one item per line:

- `serpantinum info notifications [dnd]`: Do not disturb.
- `serpantinum info idle [key]`: Idle system state: whether idle is active, caffeine and its seconds remaining (`0` when it has no time limit), app and media inhibitors, and each action's timeout and status.
- `serpantinum info dock [enabled|autohide]`: Dock visibility and autohide.
- `serpantinum info sfx [mute]`: Interface sound effects muted.
- `serpantinum info theme [preset|matugen|apps|presets]`: Active preset, wallpaper-derived colors, apps that follow the palette and bundled presets.
- `serpantinum info lang [current|available]`: Active language code and available codes.
- `serpantinum info wallpaper [screen]`: Current wallpaper path.
- `serpantinum info monitors [--json]`: Active outputs, with width, height and refresh rate as JSON.
- `serpantinum info updates [--json]`: Installed version compared with the latest release.

### `set`

Changes a setting. Switches take `on`, `off` or `toggle` and default to `toggle`:

- `serpantinum set notifications dnd [on|off|toggle]`
- `serpantinum set idle caffeine [on|off|toggle]`
- `serpantinum set dock enabled [on|off|toggle]`
- `serpantinum set dock autohide [on|off|toggle]`
- `serpantinum set sfx mute [on|off|toggle]`
- `serpantinum set theme matugen [on|off|toggle]`
- `serpantinum set theme preset <name>`: Apply a bundled preset and turn Matugen off.
- `serpantinum set theme app <id> [on|off|toggle]`: Recolor an app with the shell palette. See [App theming](../configure/AppTheming.md).
- `serpantinum set lang <code>`
- `serpantinum set wallpaper <path|random|next|prev|play|pause|clear> [screen]`: `screen` is a monitor name and defaults to `all`. A path may also take a transition after the screen.

### `trigger`

Runs a one-off action:

- `serpantinum trigger idle <dim|dpms|lock|suspend>`: Run an idle action now.
- `serpantinum trigger notifications clear`: Clear all notifications.
- `serpantinum trigger firstlaunch <trigger|reset>`: Run or reset the first launch setup.
- `serpantinum trigger theme reload`: Reload colors.
- `serpantinum trigger theme generate <image> [mode] [scheme]`: Generate colors from an image.

## Script shortcuts

### `screenshot`

Captures screen images, records video, or decodes QR codes:

- `serpantinum screenshot`: Open interactive selection and recording overlay.
- `serpantinum screenshot --full`: Capture focused monitor immediately.
- `serpantinum screenshot --edit`: Open screenshot in Satty image editor.
- `serpantinum screenshot --record`: Toggle screen video recording (start or stop).
- `serpantinum screenshot --scan-qr`: Scan selected region for QR codes.
- `serpantinum screenshot --geometry <X,Y WxH>`: Set capture crop region.
- `serpantinum screenshot --monitor <name>`: Set target monitor output.
- `serpantinum screenshot --backend <gpu-screen-recorder|wf-recorder>`: Set recording backend.
- `serpantinum screenshot --desk-vol <0.0-1.0>`: Set desktop audio volume multiplier.
- `serpantinum screenshot --desk-mute <true|false>`: Mute desktop audio in recording.
- `serpantinum screenshot --mic-vol <0.0-1.0>`: Set microphone audio volume multiplier.
- `serpantinum screenshot --mic-mute <true|false>`: Mute microphone audio in recording.
- `serpantinum screenshot --mic-dev <name>`: Set microphone input device name.

### `volume`

Controls audio sink and source levels via WirePlumber:

- `serpantinum volume raise`: Increase output volume by 5%.
- `serpantinum volume lower`: Decrease output volume by 5%.
- `serpantinum volume mute-toggle`: Toggle output mute.
- `serpantinum volume mic-toggle`: Toggle microphone mute.
- `serpantinum volume mic-raise`: Increase microphone volume by 5%.
- `serpantinum volume mic-lower`: Decrease microphone volume by 5%.

### `brightness`

Controls display backlight and external monitor brightness:

- `serpantinum brightness get`: Print current brightness percentage (default).
- `serpantinum brightness set <0-100>`: Set brightness to percentage.
- `serpantinum brightness raise`: Increase brightness by 5%.
- `serpantinum brightness lower`: Decrease brightness by 5%.
- `serpantinum brightness backend`: Print active backend (`backlight`, `ddc`, or `none`).
- `serpantinum brightness watch`: Watch backlight changes with inotify.

### `weather`

Queries weather data and manages forecast cache:

- `serpantinum weather --current-temp`: Print current temperature.
- `serpantinum weather --current-icon`: Print current weather icon glyph.
- `serpantinum weather --current-hex`: Print current weather condition accent hex.
- `serpantinum weather --temp`: Print today forecasted maximum temperature.
- `serpantinum weather --icon`: Print today forecast icon glyph.
- `serpantinum weather --hex`: Print today forecast accent hex.
- `serpantinum weather --json`: Print complete structured forecast JSON.
- `serpantinum weather --getdata`: Force fresh fetch from Open-Meteo API.
- `serpantinum weather --nav next`: Advance 5-day forecast view to next day.
- `serpantinum weather --nav prev`: Move 5-day forecast view to previous day.
- `serpantinum weather --view-listener`: Stream active forecast view index.
- `serpantinum weather --unit <metric|imperial|standard>`: Set temperature unit profile.
- `serpantinum weather --location '<json>'`: Pass custom coordinates JSON.
- `serpantinum weather --verbose` (`-v`): Print verbose debug output.

### `location`

Retrieves and updates geographic coordinates:

- `serpantinum location`: Print cached or retrieved location JSON.
- `serpantinum location --refresh` (`-r`): Force fresh lookup from IP geolocation providers.
- `serpantinum location --verbose` (`-v`): Print debug diagnostics to stderr.

### `location_manual`

Sets geographic coordinates manually:

- `serpantinum location_manual <latitude> <longitude>`: Set coordinates, reverse-geocode city and country, resolve timezone, and save to settings.

### `gamma`

Controls color temperature and the day/night schedule through [serpantinum-gamma](https://github.com/ilyamiro/serpantinum-gamma), which it starts when needed. Serpantinum stops it on exit, and the compositor then restores normal colors.

- `serpantinum gamma set <temperature> [output] [mode] [latitude] [longitude]`: Set temperature (1000-10000K) manually (`mode=manual`), or use it as the night temperature of the solar schedule (`mode=auto`). Without coordinates, or with `0 0`, the schedule fades to night at 19:00 and to day at 06:30. Without an output, every output is changed.
- `serpantinum gamma reset [output]`: Reset color temperature to 6500K daylight neutral and turn the schedule off.
- `serpantinum gamma status [output]`: Print status (`running` or `stopped`).
- `serpantinum gamma start`: Start serpantinum-gamma if it is not running.
- `serpantinum gamma stop`: Stop serpantinum-gamma.
- `serpantinum gamma --verbose` (`-v`): Print verbose output with current Kelvin, brightness and schedule state.

### `lock`

Activates lock screen:

- `serpantinum lock`: Trigger lock screen interface immediately.

### `redactor`

Opens the desktop widget layout editor in the running shell:

- `serpantinum redactor`: Open the editor.
- `serpantinum redactor <monitor> [widget]`: Open the editor on a monitor, optionally with a widget selected.

### `lock-redactor`

Opens the lock screen layout editor in the running shell:

- `serpantinum lock-redactor`: Close the editor if it is open, otherwise open it.
- `serpantinum lock-redactor open [monitor]`: Open the editor, optionally on a given monitor.
- `serpantinum lock-redactor close`: Close the editor.

### `reload`

Reloads shell:

- `serpantinum reload`: Force reload QuickShell desktop elements without restarting the daemon.

### `exit`

Terminates desktop session:

- `serpantinum exit`: Cleanly terminate graphical session and exit active compositor.

### `suspend`, `hibernate`, `reboot`, `poweroff`

- `serpantinum suspend`: Lock the screen and suspend the system.
- `serpantinum hibernate`: Hibernate the system.
- `serpantinum reboot`: Reboot the system.
- `serpantinum poweroff`: Power off the system.

## Keybinding examples

Panels and workspaces go through `msg`, everything else through `set`, `trigger` or the script shortcuts:

```
serpantinum msg toggle launcher
serpantinum msg toggle clipboard
serpantinum msg toggle calendar
serpantinum set notifications dnd toggle
serpantinum set wallpaper random
serpantinum set idle caffeine toggle
serpantinum trigger notifications clear
serpantinum volume raise
serpantinum screenshot --full
```
