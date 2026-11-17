---
sidebar_position: 3
title: Login screen
sidebar_label: Login screen
slug: /configure/greeter
---

# Login screen

Serpantinum can use its lock screen as your login screen. You get the same clock, dashboard, layout, fingerprint ring, power menu and unlock animation at login as when you unlock. After you log in, your session starts.

The login screen is a [greetd](https://sr.ht/~kennylevinsen/greetd/) greeter called `serpantinum-greeter`. It runs in a minimal Hyprland, so it needs Hyprland 0.57 or newer (Lua config), even if your own session uses another compositor.

## How it works

greetd runs the login screen as the `greeter` user, which cannot read your home directory. So Serpantinum keeps a copy of everything the login screen needs in `/var/lib/serpantinum-greeter/home`:

- your settings
- the wallpaper snapshot of each monitor
- the colors (Matugen or preset)
- the lock screen layout
- your avatar
- the weather cache

`serpantinum-greeter sync` refreshes this copy. Run it after you change any of these, or let a systemd path unit do it for you, as described below. If the login screen looks different from your lock screen, the copy is usually out of date.

## NixOS

Enable the greeter in the [system module](/installation/nixos):

```nix
programs.serpantinum.greeter = {
  enable = true;
  user = "alice";
};
```

This sets up greetd, the copy in `/var/lib/serpantinum-greeter` and, with `services.fprintd.enable`, a PAM stack that accepts a fingerprint and a password at the same time. With Plymouth, the boot splash stays on screen until the login screen appears.

If you use the [Home Manager module](/installation/nixos/home-manager) as part of your NixOS configuration, the copy is kept up to date automatically. With standalone Home Manager, turn it on yourself:

```nix
programs.serpantinum.greeter.sync.enable = true;
```

After the first `nixos-rebuild switch`, run `systemctl --user start serpantinum-greeter-sync` once so the copy exists before you log out.

### Match your monitors

By default the login screen uses each monitor's preferred mode and automatic scale. Use the same monitor lines as in your session, so that the interface has the same size and each monitor shows its own wallpaper:

```nix
programs.serpantinum.greeter.extraHyprlandConfig = ''
  hl.monitor({ output = "eDP-1", mode = "preferred", position = "auto", scale = 1.5 })
'';
```

### Options

All options are under `programs.serpantinum.greeter`.

| Option | Default | Description |
| :--- | :--- | :--- |
| `enable` | `false` | Use the Serpantinum login screen. |
| `user` | none, required | User to log in. There is no user selection. |
| `sessionCommand` | `"start-hyprland"` | Command that starts your session, for example `"uwsm start hyprland.desktop"`. |
| `sessionDesktop` | `"Hyprland"` | `XDG_CURRENT_DESKTOP` and `XDG_SESSION_DESKTOP` of the session. |
| `sessionToJournal` | `true` | Send the session's startup output to the journal instead of the screen. |
| `hybridAuth` | `true` | Fingerprint and password at the same time. See [Fingerprint](#fingerprint). |
| `keyboard.layout`, `keyboard.variant`, `keyboard.options` | `services.xserver.xkb.*` | Keyboard on the login screen. |
| `cursor.theme` | `null` | Cursor theme. It must be installed system-wide. |
| `cursor.size` | `24` | Cursor size. |
| `extraHyprlandConfig` | `""` | Lua added to the login screen's Hyprland config, for example monitor lines. |
| `stateDir` | `"/var/lib/serpantinum-greeter"` | Where the copy is kept. |
| `package` | Serpantinum from this flake | Use the same package as your shell. |
| `hyprlandPackage` | `programs.hyprland.package` | Hyprland that runs the login screen. |

The Home Manager options `programs.serpantinum.greeter.sync.enable` and `programs.serpantinum.greeter.sync.stateDir` take their defaults from the NixOS options.

## Other distributions

Serpantinum must be installed system-wide, for example with the Arch package, because the `greeter` user cannot read `~/.local/share/serpantinum`. `serpantinum-greeter`, `qs` and `hyprctl` must be on the greeter's `PATH`. The Arch package installs `serpantinum-greeter` to `/usr/bin`.

1. Install greetd and create the folder for the copy, owned by you:

   ```sh
   sudo install -d -m 0755 /var/lib/serpantinum-greeter
   sudo install -d -m 0755 -o "$USER" /var/lib/serpantinum-greeter/home
   serpantinum-greeter sync
   ```

2. Keep the copy up to date with two systemd user units. Save this as `~/.config/systemd/user/serpantinum-greeter-sync.service`:

   ```ini
   [Unit]
   Description=Mirror Serpantinum files for the login screen
   StartLimitIntervalSec=0

   [Service]
   Type=oneshot
   ExecStart=serpantinum-greeter sync
   ```

   and this as `~/.config/systemd/user/serpantinum-greeter-sync.path`:

   ```ini
   [Unit]
   Description=Mirror Serpantinum files for the login screen when they change

   [Path]
   PathChanged=%h/.config/serpantinum/settings.json
   PathChanged=%h/.cache/serpantinum/wallpaper
   PathChanged=%h/.cache/serpantinum/avatar/avatar_cropped.png
   PathChanged=%h/.cache/serpantinum/weather/weather.json
   PathChanged=%h/.local/state/serpantinum/qs_matugen_colors.json
   PathChanged=%h/.local/state/serpantinum/qs_colors.json
   PathChanged=%h/.local/state/serpantinum/lockscreen/layout.json
   PathChanged=%h/.face

   [Install]
   WantedBy=default.target
   ```

   Then enable it with `systemctl --user enable --now serpantinum-greeter-sync.path`.

3. Point greetd at the login screen in `/etc/greetd/config.toml`:

   ```toml
   [default_session]
   user = "greeter"
   command = "systemd-cat -t serpantinum-greeter-hyprland env SERPANTINUM_GREETER_USER=alice SERPANTINUM_GREETER_KB_LAYOUT=us start-hyprland -- -c /usr/share/serpantinum/src/greeter/hyprland.lua"
   ```

   Replace `alice` and `us` with your user and keyboard layout. See [Reference](#reference) for the other variables. `systemd-cat` sends Hyprland's output to the journal, so it doesn't show up on screen. Do the same for your session with `SERPANTINUM_GREETER_SESSION="systemd-cat -t serpantinum-session start-hyprland"`.

4. [Try the login screen](#try-it-first), then switch from your current display manager to greetd:

   ```sh
   sudo systemctl disable sddm.service
   sudo systemctl enable greetd.service
   ```

To keep the boot splash on screen until the login screen appears with Plymouth, add a drop-in for `greetd.service` with `Conflicts=plymouth-quit.service`, `After=plymouth-quit.service`, `OnFailure=plymouth-quit.service` and `ExecStartPre=-plymouth quit --retain-splash`, and remove any ordering after `plymouth-quit-wait.service`.

## Try it first

Before you switch, preview the login screen in your running session:

```sh
serpantinum-greeter test
```

In this preview any password logs you in and plays the unlock animation. **Ctrl+Esc** quits.

For the first real login through greetd, also log in on a second TTY (Ctrl+Alt+F3), so you can fix things if the login screen doesn't come up.

## Fingerprint

The lock screen asks for your fingerprint and your password at the same time. greetd only allows one question at a time, so the login screen can do this in two ways:

- **Both at once** (`SERPANTINUM_GREETER_HYBRID_AUTH=1`, the default): the sensor is active right away and you can also type your password. This needs `pam_unix` before `pam_fprintd` in greetd's PAM stack. The NixOS module sets that up when `services.fprintd.enable` is true. Every login with a fingerprint is also logged as a failed password attempt, so don't use this together with `pam_faillock`.
- **Fingerprint first** (`SERPANTINUM_GREETER_HYBRID_AUTH=0`): the usual PAM order. A password you type is checked once the fingerprint reader gives up.

If you log in with a fingerprint, your GNOME keyring stays locked, because there is no password to unlock it with.

## Troubleshooting

The login screen writes to the journal:

```sh
journalctl -b -t serpantinum-greeter            # the login screen
journalctl -b -t serpantinum-greeter-hyprland   # its Hyprland
journalctl -b -t serpantinum-session            # your session's startup (NixOS)
```

- **Wrong wallpaper, colors or layout:** run `serpantinum-greeter sync` and check `ls -R /var/lib/serpantinum-greeter/home`.
- **Interface too large or too small, or the wrong wallpaper on one monitor:** use the same monitor lines as in your session (`extraHyprlandConfig` on NixOS, `SERPANTINUM_GREETER_HYPRLAND_EXTRA` elsewhere).
- **Text on the screen before the login screen or your session appears:** send that output to the journal with `systemd-cat` (see [Other distributions](#other-distributions)). On NixOS this is the default.
- **No avatar:** the login screen uses the avatar from Settings, or `~/.face`.

## Limits

- One user, no user or session selection.
- Video wallpapers don't play. The login screen shows their snapshot.
- The login screen always runs in Hyprland.

## Reference

`serpantinum-greeter` has three commands, plus `--help` and `--version`:

| Command | Description |
| :--- | :--- |
| `serpantinum-greeter` | Start the login screen. greetd runs this through `greeter/hyprland.lua`. |
| `serpantinum-greeter test` | Preview the login screen in your running session. |
| `serpantinum-greeter sync` | Refresh the copy of your files for the login screen. |

It reads these environment variables:

| Variable | Default | Description |
| :--- | :--- | :--- |
| `SERPANTINUM_GREETER_USER` | none, required | User to log in. |
| `SERPANTINUM_GREETER_SESSION` | `start-hyprland` | Command that starts your session. greetd runs it with `sh`, so quotes and variables work as in a shell. |
| `SERPANTINUM_GREETER_SESSION_DESKTOP` | `Hyprland` | `XDG_CURRENT_DESKTOP` of the session. |
| `SERPANTINUM_GREETER_HYBRID_AUTH` | `1` | `1`: fingerprint and password at once. `0`: fingerprint first. |
| `SERPANTINUM_GREETER_DIR` | `/var/lib/serpantinum-greeter` | Where the copy is kept, in its `home/` folder. |
| `SERPANTINUM_GREETER_KB_LAYOUT` | `us` | Keyboard layout. `SERPANTINUM_GREETER_KB_VARIANT` and `SERPANTINUM_GREETER_KB_OPTIONS` set variant and options. |
| `SERPANTINUM_GREETER_HYPRLAND_EXTRA` | none | Lua file added to the login screen's Hyprland config, for example with monitor lines. |
| `XCURSOR_THEME`, `XCURSOR_SIZE` | Hyprland's defaults | Cursor theme and size. `HYPRCURSOR_THEME` and `HYPRCURSOR_SIZE` work too. |
