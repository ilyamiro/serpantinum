---
sidebar_position: 2
title: Installation
sidebar_label: Installation
slug: /core/installation
---

# serpantinum-core: Installation

## Installing and updating

The install script downloads the latest release for `x86_64`, checks it against the published checksums and installs it to `/usr/local/bin`. On other architectures it prints a warning and leaves the shell without the core services, so build it from source there. Running the installer again updates it, and it does nothing when the installed version is already the latest.

The Arch packages bundle a release, and the Nix flake builds it from source.

## Checking the installation

```sh
serpantinum-core --version
serpantinum-core sysinfo
```

The second command should print one JSON object with your CPU, memory, temperature, network and disk usage. It starts the daemon if it is not running.

## Optional tools

- [cliphist](https://github.com/sentriz/cliphist) for the clipboard history
- `ddcutil` for brightness on external monitors without a backlight

## Building from source

```sh
nix-shell
cargo build --release
packaging/stage.sh /tmp/stage
```

Any Rust toolchain with edition 2024 works. `stage.sh` lays out `usr/bin`, the D-Bus service file and the licence. On NixOS, adding the package to `services.dbus.packages` lets D-Bus start the daemon on first use.

## If something looks stuck

Stop the daemon and run any command again to start a fresh one:

```sh
serpantinum-core quit
serpantinum-core sysinfo
```
