---
sidebar_position: 2
title: serpantinum-core
sidebar_label: serpantinum-core
slug: /core
---

# serpantinum-core

Serpantinum ships a small background service written in Rust, [serpantinum-core](https://github.com/ilyamiro/serpantinum-core). It serves system usage, compositor state, brightness, idle inhibition, screen time, launcher ranking and clipboard history to the shell. These used to be scripts and Python helpers that the shell ran on a timer or on every event. Now one long-running process answers them, so the shell no longer starts a process for each poll and no longer needs `brightnessctl` or `python-jeepney`.

It talks to the shell over the D-Bus session bus, works on any compositor and links only glibc. The same binary is its command line client, and every command prints JSON, one object or array per line.

## In the shell

- The daemon starts the first time anything asks for it, and every command except `quit` starts it when it is not running. `watch` starts it again if it goes away.
- `serpantinumd start` runs `serpantinum-core screentime track` for the digital wellbeing tab, and `serpantinumd stop` ends it.
- The daemon can outlive a login. `serpantinum-core quit` stops it.

## Feeds cost nothing when unused

The daemon samples a feed only while a client holds a lease on it. A lease ends when the client exits or leaves the bus, so closing a popup that shows CPU usage stops the sampling. When several clients watch the same feed, it samples at the shortest interval any of them asked for.

## What it serves

| Command | Used for |
| --- | --- |
| `sysinfo`, `watch sysinfo [--interval S]` | CPU, memory, temperature, network and disk usage in the system monitor |
| `watch locks` | Caps Lock and Num Lock in the on-screen display |
| `watch compositor` | Workspaces, windows and keyboard layout on Sway, Niri and Mango |
| `watch brightness`, `brightness get\|set\|raise\|lower\|backend` | Brightness sliders, keys and the on-screen display |
| `watch idle MARKER` | Idle inhibition and the sleep lock |
| `screentime track`, `screentime stats [DATE]` | Counting and reading screen time |
| `launcher rank`, `launcher log NAME`, `launcher files QUERY` | App ranking, launch counts and file search in the launcher |
| `monitors` | Monitor lists in the wallpaper picker, the bar's workspace settings and `serpantinum info monitors` |
| `system can-hibernate`, `system fingerprint` | Whether the system panel offers hibernate, and whether fingerprint unlock is set up |
| `clipboard list\|pin\|delete\|wipe` | The clipboard history |

`serpantinum-core --help` lists every command.

### System usage

`sysinfo` reads `/proc` and `/sys` and prints CPU, memory, temperature, network and disk values as one JSON object.

### Keyboard locks

Caps Lock and Num Lock follow the keyboards' LED events when `/dev/input` can be read, for example as a member of the `input` group, and nothing runs between changes. Otherwise the LEDs in `/sys/class/leds` are polled every 250 ms while someone watches, because the kernel sends no change events there. On Hyprland every change is checked against Hyprland's main keyboard, which ignores LED flicker from other keyboards.

### Compositor state

The compositor feed speaks each compositor's own socket: Sway's i3-ipc, Niri's JSON socket and Mango's IPC socket, so following them costs no processes. Every watcher passes the variables that locate its compositor, because the daemon may outlive a login.

Hyprland is read natively by the shell. Of Hyprland, the daemon follows only the focused window, which screen time needs.

### Monitors

`monitors` prints the outputs in use with their size and refresh rate, asked over the same sockets and Hyprland's. On other Wayland compositors it reads `wl_output`, and without a compositor it lists the connectors the kernel reports connected.

### Brightness

Brightness drives the first backlight in `/sys/class/backlight`. When its file is not writable, it goes through logind, as `brightnessctl` does. Without a backlight it drives the first DDC/CI display through `ddcutil`, which then needs to be installed. `brightness backend` prints `backlight`, `ddc` or `none`, and `brightness get` prints `-1` when there is nothing to read.

### Idle

While `watch idle` runs, the daemon serves `org.freedesktop.ScreenSaver`, so video players and other apps can keep the screen awake. With the sleep lock on, it also holds a logind sleep delay inhibitor for up to 4 seconds, so the system waits for the lock screen to appear before it suspends. The lock screen signals this by creating the marker file passed to the command.

### Screen time

Screen time counts the focused app once a second into the shell's database, per day, hour, quarter hour and minute. It follows the compositor feed for the focus, and notifies you when a daily limit from the shell's settings is reached. The statistics in the digital wellbeing tab come from `screentime stats`. A database from the earlier Python daemon, in `~/.local/share/focustime`, is moved to the shell's state directory on first use.

### Launcher

`launcher rank` scores apps from screen time and launches, both decaying by half a week at a time. `launcher log` counts a launch, and `launcher files` searches files, or completes the path when the query is one.

### Clipboard

The clipboard commands read the history from [cliphist](https://github.com/sentriz/cliphist), which must be installed. Decoded images and pins are kept in the directory passed with `--cache-dir`, by default `$XDG_CACHE_HOME/serpantinum/clipboard`.

## D-Bus

The daemon owns `org.serpantinum.Core` on the session bus, with one object per feed:

| Object | Interface |
| --- | --- |
| `/` | `org.serpantinum.Core` |
| `/sysinfo` | `org.serpantinum.Core.SysInfo` |
| `/locks` | `org.serpantinum.Core.Locks` |
| `/compositor` | `org.serpantinum.Core.Compositor` |
| `/brightness` | `org.serpantinum.Core.Brightness` |
| `/idle` | `org.serpantinum.Core.Idle` |
| `/screentime` | `org.serpantinum.Core.ScreenTime` |
| `/clipboard` | `org.serpantinum.Core.Clipboard` |

Properties signal `PropertiesChanged`. You can query it by hand:

```sh
busctl --user call org.serpantinum.Core /sysinfo org.serpantinum.Core.SysInfo Subscribe u 1000
busctl --user get-property org.serpantinum.Core /sysinfo org.serpantinum.Core.SysInfo Cpu
```

The full list of members is in the [serpantinum-core README](https://github.com/ilyamiro/serpantinum-core#d-bus).

## Installation

### Installing and updating

The install script downloads the latest release for `x86_64`, checks it against the published checksums and installs it to `/usr/local/bin`. On other architectures it prints a warning and leaves the shell without the core services, so build it from source there. Running the installer again updates it, and it does nothing when the installed version is already the latest.

The Arch packages bundle a release, and the Nix flake builds it from source.

### Checking the installation

```sh
serpantinum-core --version
serpantinum-core sysinfo
```

The second command should print one JSON object with your CPU, memory, temperature, network and disk usage. It starts the daemon if it is not running.

### Optional tools

- [cliphist](https://github.com/sentriz/cliphist) for the clipboard history
- `ddcutil` for brightness on external monitors without a backlight

### Building from source

```sh
nix-shell
cargo build --release
packaging/stage.sh /tmp/stage
```

Any Rust toolchain with edition 2024 works. `stage.sh` lays out `usr/bin`, the D-Bus service file and the licence. On NixOS, adding the package to `services.dbus.packages` lets D-Bus start the daemon on first use.

### If something looks stuck

Stop the daemon and run any command again to start a fresh one:

```sh
serpantinum-core quit
serpantinum-core sysinfo
```
