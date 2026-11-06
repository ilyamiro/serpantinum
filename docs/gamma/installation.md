---
sidebar_position: 2
title: Installation
sidebar_label: Installation
slug: /gamma/installation
---

# serpantinum-gamma: Installation

## Installing and updating

The install script downloads the latest release for `x86_64`, checks it against the published checksums and installs it to `/usr/local/bin`. On other architectures it prints a warning and leaves the shell without the blue light filter, so build it from source there. Running the installer again updates it, and it does nothing when the installed version is already the latest.

The Arch packages bundle a release, and the Nix flake builds it from source.

## Checking the installation

```sh
serpantinum-gamma --version
serpantinum-gamma start
serpantinum-gamma set --temperature 4000
serpantinum-gamma reset
```

The screen should turn warmer and then return to normal. If it doesn't, see below.

## Starting it through D-Bus

The package installs `share/dbus-1/services/org.serpantinum.Gamma.service`, so the first call to `org.serpantinum.Gamma` starts the daemon. A process D-Bus starts gets D-Bus's own environment, so `WAYLAND_DISPLAY` must be in it. Most compositor setups already run `dbus-update-activation-environment --systemd WAYLAND_DISPLAY`. If yours doesn't, start the daemon from the compositor's autostart instead. The shell does this for you with `serpantinum blue_light_filter start`.

## If nothing changes

- **GNOME and KDE** are not supported.
- **Another night light tool** may hold the gamma control. Gamma control is exclusive per output, so stop the other tool first.
- **Hyprland** only applies temperature and brightness.

## Building from source

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
