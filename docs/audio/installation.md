---
sidebar_position: 2
title: Installation
sidebar_label: Installation
slug: /audio/installation
---

# Audio engine: Installation

## Installing and updating

The install script downloads the latest release for `x86_64` or `aarch64`, checks it against the published checksums and installs it to `/usr/local/bin`. Prebuilt binaries need glibc 2.39 or newer. On other systems, such as Void Linux musl, the installer installs a compiler and the PipeWire development files and builds it from source. Running the installer again updates it.

The Arch packages bundle a release, and the Nix flake builds it from source.

## Moving from EasyEffects

The first time the installer or the shell runs with the audio engine installed, Serpantinum undoes what it set up for EasyEffects. This runs once:

- stops the EasyEffects instance that the old equalizer started, the one running the `live_eq` preset, and `ee-eq.service` if it is running
- removes the `live_eq` preset that Serpantinum used to generate
- removes the `systemctl --user enable --now easyeffects` line from the autostart file Serpantinum installed for Hyprland, Niri, Sway or Mango, keeping a `.pre-audio-engine.bak` copy of each file it edits

Anything you set up yourself stays as it is. EasyEffects stays installed, and your presets, services and autostart entries are not touched. An EasyEffects you started yourself keeps running. A line you moved or changed, and config files that are links, for example from Home Manager or a dotfiles manager, are left alone too.

If EasyEffects is still running or set to start at login after this, Serpantinum tells you once: in the installer output, or as a notification when the shell starts. EasyEffects can interfere with the audio engine, so turn it off unless you use it for something else, such as microphone effects, which Serpantinum does not do. Depending on how you set it up, that means `systemctl --user disable --now easyeffects`, turning off its start-at-login option in EasyEffects, or removing `services.easyeffects.enable` from your Home Manager configuration.
