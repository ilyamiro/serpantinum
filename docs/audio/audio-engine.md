---
sidebar_position: 1
title: Audio engine
sidebar_label: Audio engine
slug: /audio
---

# Audio engine

Serpantinum ships its own small audio processor, [serpantinum-audio](https://github.com/ilyamiro/serpantinum-audio). It replaces EasyEffects and depends only on PipeWire. The equalizer, balance, mono, channel swap, dynamic range modes and the dynamic EQ in the music popup all run on it.

It creates a virtual output called **Serpantinum**, processes everything sent to it and plays the result on your real output device. The shell talks to it over a local socket, so changing a slider is instant.

## In the shell

- `serpantinumd start` starts the engine, so it runs whenever the shell does.
- Your real device stays the default output. The engine moves each app's audio onto the **Serpantinum** output, processes it and plays it on the default device, just as EasyEffects did. The **Serpantinum** output appears in the volume popup next to your devices.
- Choosing a device in the volume popup moves the processed audio to that device. The volume keys and every app that asks for the default output see your real device.
- An app you move to another device yourself, for example in pavucontrol, stays there and skips the engine. Apps that pick their own device are left alone too.
- When the engine stops, apps go back to the default device.
- Settings survive a reboot. The engine keeps them in `~/.local/state/serpantinum/audio.state`, and the music popup reads them back from there.

## Dynamic EQ

The **Dynamic** button on the equalizer page turns on an adaptive tonal balance. It listens to the last few seconds of audio and gently moves the balance toward the typical balance of commercial recordings, without changing loudness. It replaces the manual equalizer while it is on, so the sliders and presets are dimmed until you turn it off.

The design and the research behind each number are described in the [serpantinum-audio README](https://github.com/ilyamiro/serpantinum-audio#dynamic-eq).

## Installation

The install script downloads the latest release for `x86_64` or `aarch64`, checks it against the published checksums and installs it to `/usr/local/bin`. Prebuilt binaries need glibc 2.39 or newer. On other systems, such as Void Linux musl, the installer installs a compiler and the PipeWire development files and builds it from source. Running the installer again updates it.

The Arch packages bundle a release, and the Nix flake builds it from source.

## Moving from EasyEffects

The first time the installer or the shell runs with the audio engine installed, Serpantinum undoes what it set up for EasyEffects. This runs once:

- stops the EasyEffects instance that the old equalizer started, the one running the `live_eq` preset, and `ee-eq.service` if it is running
- removes the `live_eq` preset that Serpantinum used to generate
- removes the `systemctl --user enable --now easyeffects` line from the autostart file Serpantinum installed for Hyprland, Niri, Sway or Mango, keeping a `.pre-audio-engine.bak` copy of each file it edits

Anything you set up yourself stays as it is. EasyEffects stays installed, and your presets, services and autostart entries are not touched. An EasyEffects you started yourself keeps running. A line you moved or changed, and config files that are links, for example from Home Manager or a dotfiles manager, are left alone too.

If EasyEffects is still running or set to start at login after this, Serpantinum tells you once: in the installer output, or as a notification when the shell starts. EasyEffects can interfere with the audio engine, so turn it off unless you use it for something else, such as microphone effects, which Serpantinum does not do. Depending on how you set it up, that means `systemctl --user disable --now easyeffects`, turning off its start-at-login option in EasyEffects, or removing `services.easyeffects.enable` from your Home Manager configuration.
