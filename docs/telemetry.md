---
title: Telemetry
sidebar_label: Telemetry
slug: /telemetry
---

# Telemetry

Serpantinum collects a small amount of anonymous data. Nothing it collects can identify you, your machine, or your activity. The only goal is to understand the userbase: how many people use the project, and which distros and compositors it runs on, so development time goes where it matters.

There are two separate sources, and both can be turned off.

## Daily ping

Once a day, the shell sends one empty `POST` request to `https://dots-telemetry.ilyamiro-work.workers.dev/ping`. The request has no body, no ID, no version, and no system information. It only reaches the server, which adds one to the counter for that day.

- The shell pings at most once per UTC day and remembers the last day in `${XDG_STATE_HOME:-$HOME/.local/state}/serpantinum/daily_ping`.
- To keep the count honest, the server counts at most 10 pings per IP address per day, enough for a household or office with several machines, but not for someone spamming requests. It never stores the address. It keeps a one-way hash of the address, salted with a secret key and the current date, only until the day ends, then deletes it. Hashes from different days cannot be linked to each other, and the hash cannot be turned back into an address.
- The only thing kept long term is a number per day, such as `2026-11-27: 412`.

This applies to every install method, including the AUR and Nix packages.

To turn it off, uncheck **Settings → General → Daily ping**, or set it in `~/.config/serpantinum/settings.json`:

```json
{
  "general": {
    "dailyPing": false
  }
}
```

## Installer telemetry

The `install.sh` installer reports when an install starts and finishes, so failed installs and broken packages show up. Package installs from the AUR or Nix send none of this.

When the installer finishes, it sends:

| Field | Example |
| --- | --- |
| Serpantinum version and the version you updated from | `2.5.4`, `2.5.3` |
| Install type | fresh, update, reinstall, or migration from v1 |
| Distro | `Arch Linux` |
| Selected compositors | `hyprland niri` |
| Previous desktop environment | `KDE` |
| Session type and architecture | `wayland`, `x86_64` |
| Kernel version | `6.17.2-arch1-1` |
| CPU and GPU model, total RAM | `AMD Ryzen 7 7840HS`, `15.3 GB` |
| Packages that failed to install | `foo-git` |

These reports are tied to a random ID generated on your machine at first install. It is not derived from your hardware or accounts, and it only exists to link the start and finish of one install, and later updates, together.

To turn it off, disable **Anonymous telemetry** in the installer menu. The choice is remembered for future updates, and with it off the installer sends nothing at all.

## What is never stored

- IP addresses, usernames, hostnames, or email addresses
- File names, paths, or anything about your files
- Location, timezone, or language
- What you do in the shell: apps, windows, keybinds, or settings
