---
sidebar_position: 3
title: serpantinum-gamma
sidebar_label: serpantinum-gamma
slug: /gamma
---

# serpantinum-gamma

Serpantinum ships its own blue light filter, [serpantinum-gamma](https://github.com/ilyamiro/serpantinum-gamma). It sets the color temperature, brightness, gamma and inversion of your displays on Wayland, with a day and night schedule that follows the sun.

It is a small daemon, and the same binary is its command line client. They talk over the D-Bus session bus, so it needs no systemd. The binary links only glibc.

## In the shell

- The `serpantinum gamma` command drives it, and starts it when needed. See the [CLI reference](/cli/client#gamma).
- Serpantinum stops it on exit, and the compositor then restores normal colors.
- Without `--output`, a command changes every output, including outputs connected later.

## Compositors

The backend is picked on its own:

- **Hyprland**: its `hyprland-ctm-control-v1` color matrix, when the compositor offers it. Hyprland no longer gives gamma ramps to clients. A matrix is linear, so only temperature and brightness take effect there. Gamma and inversion are accepted but have no effect.
- **Sway, Niri, Mango and other wlroots-style compositors**: the `wlr-gamma-control-unstable-v1` protocol, where all four settings work.

GNOME and KDE support neither.

The colors last only while the daemon runs, since the compositor restores normal colors when a program's gamma control goes away. Gamma control is exclusive, so only one program can hold it per output. Stop any other night light tool first, or the compositor refuses the daemon's control and it logs a message.

## Commands

```sh
serpantinum-gamma start                         # the daemon, in the background
serpantinum-gamma set --temperature 4000        # every output
serpantinum-gamma set -o eDP-1 --brightness 0.8 # one output
serpantinum-gamma auto on --night 3500          # follow the schedule
serpantinum-gamma location 55.75 37.62          # by the sun at this place
serpantinum-gamma fallback 06:30 19:00          # or, without a location, by the clock
serpantinum-gamma status -o eDP-1
serpantinum-gamma reset
serpantinum-gamma quit                          # the compositor restores normal colors
```

`serpantinum-gamma --help` lists every command.

- `set` takes `--temperature K`, `--brightness 0-1`, `--gamma G` and `--inverted on|off`. Setting a temperature turns the schedule off.
- `reset` returns to a neutral temperature, full brightness, gamma 1 and not inverted.
- `status` shows the color and the schedule, and fails if the daemon is not running.
- A command for an output that was just connected waits up to two seconds for it to appear.
- Commands never start the daemon themselves, except `start`.

## Day and night schedule

The schedule changes the temperature with the time of day. It is off at start, and `auto on` turns it on. The daemon keeps no settings and finds no location itself: whatever starts it sets them, and they last until it exits.

- **With a location**, the temperature follows the sun's elevation: day at +2° and above, night at −4.5° and below, fading in between. That takes about 30 to 40 minutes at mid latitudes. Places without a sunrise or sunset, as in polar night, simply stay at night or day.
- **Without a location**, the fade to night starts at the fallback night time and the fade to day at the fallback day time, each lasting 30 minutes. They default to 19:00 and 07:00, and `fallback DAY NIGHT` changes them.
- The day and night temperatures default to 6500 K and 4000 K. `auto on --day K --night K` changes them.
- The fade is even in mireds (a million over the temperature), the scale on which equal steps look equally large.
- The schedule is applied every 10 seconds from the current clock, so suspend, time zone and daylight saving changes take effect at the next tick.
- Brightness, gamma and inversion are left alone by the schedule.

## Color

The color for each temperature is computed from physics, not a curve fit:

1. Planck's law gives the blackbody spectrum.
2. The CIE 1931 color matching functions turn it into XYZ.
3. A Bradford chromatic adaptation maps the 6500 K blackbody onto the display's D65 white, so 6500 K is exactly neutral and the colors change smoothly around it.
4. The sRGB transfer function encodes the result, because a gamma ramp scales encoded values.

The sun's position comes from NOAA's equations and agrees with PyEphem to about 0.01°.

## D-Bus

The daemon owns `org.serpantinum.Gamma` on the session bus. Object `/` controls every output, and `/outputs/<name>` controls one. Output names become path elements with every character other than a letter or digit replaced by `_`, so `eDP-1` is `/outputs/eDP_1`.

```sh
busctl --user set-property org.serpantinum.Gamma / org.serpantinum.Gamma Temperature q 4000
busctl --user set-property org.serpantinum.Gamma /outputs/eDP_1 org.serpantinum.Gamma Brightness d 0.8
busctl --user call org.serpantinum.Gamma / org.serpantinum.Gamma ToggleInverted
busctl --user tree org.serpantinum.Gamma
```

| Member | Type | Range |
| --- | --- | --- |
| `Temperature` | property `q` | 1000 to 10000 K, 6500 is neutral |
| `Brightness` | property `d` | 0 to 1 |
| `Gamma` | property `d` | at least 0.1, 1 is neutral |
| `Inverted` | property `b` | |
| `UpdateTemperature` | method `n` | adds a delta |
| `UpdateBrightness`, `UpdateGamma` | method `d` | adds a delta |
| `ToggleInverted` | method | |

The schedule lives on the `org.serpantinum.Gamma.Schedule` interface, with `Auto`, `DayTemperature`, `NightTemperature`, `SetLocation`, `ClearLocation`, the fallback times and read-only values for the sun. Reading `/` gives the average of all outputs, and writing to `/` changes every output, including outputs connected later.

All properties emit `PropertiesChanged`. The full list of members is in the [serpantinum-gamma README](https://github.com/ilyamiro/serpantinum-gamma#d-bus).

## Installation

### Installing and updating

The install script downloads the latest release for `x86_64`, checks it against the published checksums and installs it to `/usr/local/bin`. On other architectures it prints a warning and leaves the shell without the blue light filter, so build it from source there. Running the installer again updates it, and it does nothing when the installed version is already the latest.

The Arch packages bundle a release, and the Nix flake builds it from source.

### Checking the installation

```sh
serpantinum-gamma --version
serpantinum-gamma start
serpantinum-gamma set --temperature 4000
serpantinum-gamma reset
```

The screen should turn warmer and then return to normal. If it doesn't, see below.

### Starting it through D-Bus

The package installs `share/dbus-1/services/org.serpantinum.Gamma.service`, so the first call to `org.serpantinum.Gamma` starts the daemon. A process D-Bus starts gets D-Bus's own environment, so `WAYLAND_DISPLAY` must be in it. Most compositor setups already run `dbus-update-activation-environment --systemd WAYLAND_DISPLAY`. If yours doesn't, start the daemon from the compositor's autostart instead. The shell does this for you with `serpantinum gamma start`.

### If nothing changes

- **GNOME and KDE** are not supported.
- **Another night light tool** may hold the gamma control. Gamma control is exclusive per output, so stop the other tool first.
- **Hyprland** only applies temperature and brightness.

### Building from source

```sh
nix-shell
cargo build --release
packaging/stage.sh /tmp/stage
```

Any Rust toolchain with edition 2024 works. `stage.sh` lays out `usr/bin`, the D-Bus service file and the licence.

On NixOS, add the package to both lists, so that D-Bus can start the daemon:

```nix
let gamma = pkgs.callPackage /path/to/serpantinum-gamma { }; in {
  environment.systemPackages = [ gamma ];
  services.dbus.packages = [ gamma ];
}
```
