---
sidebar_position: 1
title: Installation
sidebar_label: Installation
slug: /installation
---

# Installation

:::warning[IMPORTANT]
**Migrating from v1:** All previous configuration will be backed up and unused. Configuration of compositor settings such as monitors, keybinds, and autostart is now up to you, as the project migrated from being dotfiles to being a shell.
:::

Serpantinum installs through an automated script on Arch Linux, Fedora, and their derivatives. The script detects your distribution and uses the matching package manager (`pacman` or `dnf`). On NixOS, use the [flake and modules](/installation/nixos) instead.

Use this installer:

```bash
curl -fsSL install.serpantinum.dev | bash
```

If this doesn't work, use:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/ilyamiro/serpantinum/master/install/install.sh)"
```

:::info[NOTE]
To update, when or if you receive a notification about a new version being available, run the installer script again and choose **Update**.
:::

## Fedora

Fedora and its derivatives, such as **Nobara** and **Ultramarine**, are installed with `dnf`. Fedora does not package `gpu-screen-recorder` or `wl-gammarelay-rs`, so screen recording and the blue light filter are unavailable there. SDDM is set up with its Wayland greeter, since Fedora ships no Xorg server.

## Arch Linux and derivatives

Serpantinum is verified and supported across Arch Linux and its derivative distributions, on systemd, OpenRC, and other init systems, including:

- **Arch Linux**
- **EndeavourOS**
- **Manjaro**
- **CachyOS**
- **Garuda Linux**
- **ArcoLinux**
- **Archcraft**
- **Artix Linux**
- **BlackArch**
- **RebornOS**
- **Mabox Linux**
- **blendOS**
- **Parch Linux**
- **BigLinux**
- **ArchLabs**
- **Archman**
- **ALCI**
- **BlueStar**
- **ArchBang**
- **ArchEX**
- **ArchStrike**
- **Athena OS**
- **ChimeraOS**
- **Ctlos Linux**
- **Crystal Linux**
- **HefftorLinux**
- **instantOS**
- **Nyarch Linux**
- **Obarun**
- **Hyperbola**
- **Parabola**
- **Salient OS**
- **Snal Linux**
- **SteamOS / HoloISO**
- **StormOS**
- **TeArch**
- **XeroLinux**
- **Axyl**
- **OMARCHY**
