# serpantinum-pet

A pixel-art desktop cat for the serpantinum Quickshell shell. It lives along the bottom of
the screen above your windows, reacts to what the shell already knows (music, focused app,
CPU, notifications, workspaces, weather, idle, battery, wallpaper colors), sleeps in a bed
on your bar, and earns treats while you code.

This folder is the source of truth. The shell only gets a copy. It lives in the
`hyprland-rice` repo as `mods/pet/`; `mods/pet` is a symlink to it.

## Install / reinstall

```sh
mods/pet/install.sh
```

Run it again any time: after a serpantinum update, after a reinstall, or after editing
anything in `src/`. It is idempotent and it:

1. copies `src/pet/` to `~/.local/share/serpantinum/src/quickshell/pet/`
2. adds one marked `Loader` block at the end of `Shell.qml`
3. adds a marked block with two binds to `~/.config/hypr/config/keybinds.lua`
   (falls back to `hyprland.lua` / `hyprland.conf`): `SUPER+K` and `SUPER+SHIFT+K`
4. puts the `pet` bed module in the bar's center group (first install only; if you remove
   it in Settings → Bar it stays removed)
5. reloads the shell (same as SUPER+R) and checks the new version is running

Options: `--key J` (use SUPER+J / SUPER+SHIFT+J), `--no-keybind`, `--no-bed`, `--quiet`.

Uninstall: `mods/pet/uninstall.sh` (add `--purge` to also delete the pet's saved state).

## On / off

The pet has a real off switch: no overlay, no animations, no sounds, no treat earning.

- right-click its bed in the bar → **Turn pet off**
- or `SUPER+SHIFT+K`, or `serpantinum ipc call pet off`

While it's off the bed stays in the bar as a dimmed, empty cushion. Click it (or press
`SUPER+SHIFT+K` / `SUPER+K`) to switch the pet back on, and it hops out of bed. The choice is
remembered across reboots (`"enabled"` in the `pet` settings block). If you'd rather not see
the bed at all, remove the "Pet bed" module in Settings → Bar.

## Controls

| | |
|---|---|
| `SUPER+K` | summon / send home (`serpantinum ipc call pet toggle`), turns it on if it's off |
| `SUPER+SHIFT+K` | turn the whole pet on / off |
| drag | pick it up by the scruff; let go to drop or throw it |
| scroll on it | pet it (purrs) |
| click | meow |
| double-click | chase mode: it runs after your cursor and pounces (up to 60 s or 5 catches) |
| right-click | send it home |

On the **bar bed**: click to call it out or send it home, scroll to pet it while it sleeps,
right-click for the menu (send to bed / call out, drop a treat, chase, sounds on/off, turn
off), click the fish counter to drop a treat, or drag from the fish counter to carry a treat
and drop it on the cat. Treats on the floor can be dragged around too.

## What it reacts to

| when | it |
|---|---|
| music is playing | wears headphones, dances to the bass (Cava) |
| IntelliJ / VS Code / kitty / … focused | walks to a corner, puts on glasses, types on a laptop |
| CPU ≥ 90 % or ≥ 80 °C for a while | pants with a sweat drop |
| a notification pops up | ears up, "!" and looks toward your popups (skipped in DND) |
| you switch workspace | stumbles, as if the floor moved |
| no input for 2 min | curls up and sleeps, stretches when you're back |
| battery ≤ 15 % and discharging | flops over |
| the weather module says rain | holds an umbrella |
| wallpaper / matugen colors change | re-colors itself and notices |
| a fullscreen app is up or the screen is locked | hides (and stops animating) |

## Treats

- 1 treat per 25 minutes of focused coding today (read from the Digital Wellbeing database)
- 1 treat per finished pomodoro focus session (from the Timer quick action)
- 3 welcome treats on the very first run

Each treat fills its tummy by 25 %; it digests about 25 % per hour. When it's full it
politely refuses and leaves the treat on the floor for later.

## Settings

Optional `"pet"` block in `~/.config/serpantinum/settings.json` (all keys optional):

```json
"pet": {
  "enabled": true,
  "scale": 3,
  "fur": "mauve",
  "bed": "peach",
  "sounds": true,
  "soundVolume": 0.7,
  "musicReactive": true,
  "idleTimeout": 120,
  "treatMinutes": 25,
  "codingApps": ["jetbrains-*", "code", "kitty", "DBeaver", "beekeeper-studio"],
  "hotTemp": 80,
  "busyCpu": 90,
  "lowBattery": 15,
  "floorOffset": 6
}
```

`fur` / `bed` take a theme color name (`mauve`, `peach`, `blue`, `green`, …) so they follow
matugen, or a `#rrggbb` value. `scale` is the pixel size (2–6). Sounds also respect the
shell's own "mute SFX" and SFX volume settings. `enabled: false` is the off switch (the
menu and `SUPER+SHIFT+K` just flip it for you).

## IPC

```sh
serpantinum ipc call pet on|off|power     # power switch (power = toggle)
serpantinum ipc call pet toggle|summon|dismiss|chase|treat|menu
serpantinum ipc call pet react alert|stumble|meow|purr|dizzy|notice|greet|stretch|sleep
serpantinum ipc call pet give 3        # gift treats
serpantinum ipc call pet status        # JSON snapshot
serpantinum ipc call pet events        # recent things it did
```

## Files

```
install.sh / uninstall.sh
src/pet/
  PetRoot.qml      always loaded: IPC target, bar bed registration, on/off switch
  Pet.qml          the pet itself (loaded only while it's on)
  PetMenu.qml      the bed's right-click menu
  PetWindow.qml    full-screen click-through overlay: behavior, physics, input
  PetState.qml     singleton: saved state, settings, colors, sounds, beds
  PetBedFace.qml   the bar module
  PetTreats.qml    treat earning (coding time + pomodoros)
  PetArt.js        all pixel art + scene composer (palette-indexed)
  PetSprite.qml    Canvas renderer
  pet_cursor.py    streams the cursor position from Hyprland (chase mode only)
  pet_stats.py     reads today's coding time from focustime.db
  sounds/          synthesized by tools/gen_sounds.py
tools/
  preview.sh       renders previews/sprites.png (every pose, offscreen)
  gen_sounds.py    regenerates the sound effects
```

Saved state (treats, stats, in/out): `~/.local/state/serpantinum/pet/state.json`.

## Troubleshooting

```sh
quickshell log -p ~/.local/share/serpantinum/src/quickshell/Shell.qml -t 60 | grep @pet/
serpantinum ipc call pet status
```

If a shell update changed `Shell.qml` and the pet is gone, just run `install.sh` again.
