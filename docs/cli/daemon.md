---
sidebar_position: 2
title: Serpantinum daemon
sidebar_label: Serpantinum daemon
slug: /cli/daemon
---

# Serpantinum daemon

`serpantinumd` is the background service daemon for the desktop shell.

## Options

- `-v, --verbose`: Enable verbose logging output.
- `-V, --version`: Print installed version and exit.
- `-h, --help`: Show usage help and exit.

## Commands

### `start`

- `serpantinumd start`: Start the desktop shell and background services (default command).

### `stop`

- `serpantinumd stop`: Stop the running daemon and all background shell processes (`focus_daemon.py`, `quickshell`).

### `status`

- `serpantinumd status`: Check whether the daemon is currently running (exit code 0 if running, 1 if stopped).

## Autostart

Compositor autostart examples:

- Hyprland (`config/autostart.lua`): `hl.exec_cmd("serpantinumd start")`
- Niri (`config/autostart.kdl`): `spawn-at-startup "serpantinumd" "start"`
- Sway (`configDir/autostart`): `exec serpantinumd start`
