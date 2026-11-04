---
sidebar_position: 1
title: How it works
sidebar_label: How it works
slug: /audio
---

# Audio engine: How it works

Serpantinum ships its own small audio processor, [serpantinum-audio](https://github.com/ilyamiro/serpantinum-audio). It replaces EasyEffects and depends only on PipeWire. The equalizer, balance, mono, channel swap, dynamic range modes and the dynamic EQ in the music popup all run on it.

It creates a virtual output called **Serpantinum**, processes everything sent to it and plays the result on your real output device. The shell talks to it over a local socket, so changing a slider is instant.

## In the shell

- `serpantinumd start` starts the engine, so it runs whenever the shell does.
- Your real device stays the default output. The engine moves each app's audio onto the **Serpantinum** output, processes it and plays it on the default device, just as EasyEffects did. The **Serpantinum** output appears in the volume popup next to your devices.
- Choosing a device in the volume popup moves the processed audio to that device. The volume keys and every app that asks for the default output see your real device.
- An app you move to another device yourself, for example in pavucontrol, stays there and skips the engine. Apps that pick their own device are left alone too.
- When the engine stops, apps go back to the default device.
- Settings survive a reboot. The engine keeps them in `~/.local/state/serpantinum/audio.state`, and the music popup reads them back from there.

## Voice chat apps

Voice chat apps skip the engine and play directly on your device, so their sound is not processed. Without this, the people in your call would hear their own voices when you share your screen with audio: the share leaves out the voice chat app, but the engine's processed mix contains its sound too, so it would be captured and sent back to them.

These apps are skipped:

- Discord, including PTB and Canary
- Vesktop, Equibop, Legcord, ArmCord and WebCord
- Zoom
- Teams for Linux
- any app that marks its playback as call audio

Everything these apps play skips the engine, including music and videos in them, so the equalizer and the dynamics modes do not apply to it. If you want an app processed anyway, move it to the **Serpantinum** output in pavucontrol. Each stream is checked only once, when it starts, so nothing switches devices in the middle of playback.

Calls in Telegram and in a browser are still processed, because their call audio looks the same as the rest of their sound.

## Dynamic EQ

The **Dynamic** button on the equalizer page turns on an adaptive tonal balance. It listens to the last few seconds of audio and gently moves the balance toward the typical balance of commercial recordings, without changing loudness. It replaces the manual equalizer while it is on, so the sliders and presets are dimmed until you turn it off.

The design and the research behind each number are described in the [serpantinum-audio README](https://github.com/ilyamiro/serpantinum-audio#dynamic-eq).
