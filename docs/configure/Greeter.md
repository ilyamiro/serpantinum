---
sidebar_position: 3
title: Login screen
sidebar_label: Login screen
slug: /configure/greeter
---

# Login screen

Serpantinum can use its lock screen as the login screen. `serpantinum-greeter` runs the lock screen UI (clock, dashboard, lock screen layout, fingerprint ring, power menu, unlock animation) as a [greetd](https://sr.ht/~kennylevinsen/greetd/) greeter inside a minimal Hyprland. After a successful login it starts your session.

Compared to the lock screen, only the parts that differ at login are replaced (`quickshell/greeter/GreeterLock.qml` instead of `lock/Lock.qml`):

| Lock screen                              | Login screen                                          |
|------------------------------------------|-------------------------------------------------------|
| `WlSessionLock` surface per monitor      | an overlay `PanelWindow` per monitor                  |
| two PAM conversations (password + finger)| one greetd conversation                               |
| unlocks the session                      | starts the session command                            |
| screenshot of the session as background  | mirrored wallpaper snapshot                           |

## How it works

greetd runs as the `greeter` user, which cannot read your home directory. `serpantinum-greeter sync` copies what the lock screen needs (settings, wallpaper snapshot, Matugen colors, lock screen layout, avatar, weather cache) to `/var/lib/serpantinum-greeter/home`, which becomes the greeter's `$HOME`. Run it whenever those files change; the NixOS and Home Manager modules do this automatically with a systemd path unit.

`serpantinum-greeter` is configured through environment variables:

| Variable                              | Default                         | Meaning                                         |
|---------------------------------------|---------------------------------|-------------------------------------------------|
| `SERPANTINUM_GREETER_USER`            | (required)                      | user to log in; there is no user selection      |
| `SERPANTINUM_GREETER_SESSION`         | `start-hyprland`                | command greetd runs after login                 |
| `SERPANTINUM_GREETER_SESSION_DESKTOP` | `Hyprland`                      | `XDG_CURRENT_DESKTOP` of that session           |
| `SERPANTINUM_GREETER_HYBRID_AUTH`     | `1`                             | fingerprint and password at once (see below)    |
| `SERPANTINUM_GREETER_DIR`             | `/var/lib/serpantinum-greeter`  | state directory, `home/` is the greeter's home  |
| `SERPANTINUM_GREETER_KB_LAYOUT`       | `us`                            | keyboard layout (also `_KB_VARIANT`, `_KB_OPTIONS`) |
| `SERPANTINUM_GREETER_HYPRLAND_EXTRA`  | (none)                          | extra Lua file for the greeter's Hyprland, e.g. monitor lines |

The cursor follows `XCURSOR_THEME`/`XCURSOR_SIZE` and `HYPRCURSOR_THEME`/`HYPRCURSOR_SIZE`.

Logs go to the journal: `journalctl -b -t serpantinum-greeter`.

## NixOS

Import the NixOS module and enable the greeter:

```nix
{
  imports = [ inputs.serpantinum.nixosModules.default ];

  programs.serpantinum.greeter = {
    enable = true;
    user = "alice";
    # sessionCommand = "uwsm start hyprland.desktop";
    # keyboard.layout = "de";          # defaults to services.xserver.xkb.layout
    # cursor = { theme = "Bibata-Modern-Classic"; size = 24; };
    # extraHyprlandConfig = ''
    #   hl.monitor({ output = "eDP-1", mode = "preferred", position = "auto", scale = 1.5 })
    # '';
  };
}
```

This sets up greetd, the state directory and, with fingerprint login, the PAM stack. When Home Manager runs as a NixOS module, `programs.serpantinum.greeter.sync.enable` turns on automatically and keeps the mirror up to date. After the first rebuild, run `systemctl --user start serpantinum-greeter-sync` once and check `ls -R /var/lib/serpantinum-greeter/home`.

## Other distributions

The greeter user has to be able to read the Serpantinum files, so install Serpantinum somewhere system-wide (not only in `~/.local/share/serpantinum`) and make sure `serpantinum-greeter`, `qs` and `hyprctl` are on the greeter's `PATH`. Then:

1. Create the state directory, owned by your user and readable by everyone:
   ```sh
   sudo install -d -m 0755 /var/lib/serpantinum-greeter
   sudo install -d -m 0755 -o "$USER" /var/lib/serpantinum-greeter/home
   serpantinum-greeter sync
   ```
2. Point greetd at the greeter in `/etc/greetd/config.toml`:
   ```toml
   [default_session]
   user = "greeter"
   command = "env SERPANTINUM_GREETER_USER=alice SERPANTINUM_GREETER_KB_LAYOUT=de start-hyprland -- -c /usr/share/serpantinum/src/greeter/hyprland.lua"
   ```
   Adjust the path to where Serpantinum is installed (`$SERPANTINUM_DIR/greeter/hyprland.lua`).
3. Run `serpantinum-greeter sync` whenever your wallpaper, colors or lock screen layout change, for example from a systemd user path unit.

### Avoiding text on the screen during boot

greetd connects the greeter and the session to the VT, so anything Hyprland or the session command prints shows up on screen before they draw. The NixOS module handles this; on other distributions:

- Wrap both commands in `systemd-cat` so their output goes to the journal, e.g. `command = "systemd-cat -t serpantinum-greeter-hyprland env ... start-hyprland -- -c ..."` and `SERPANTINUM_GREETER_SESSION="systemd-cat -t serpantinum-session uwsm start hyprland.desktop"`.
- With Plymouth, let greetd take over the splash like GDM does: in a drop-in for `greetd.service`, add `Conflicts=plymouth-quit.service`, `After=plymouth-quit.service`, `OnFailure=plymouth-quit.service` and `ExecStartPre=-plymouth quit --retain-splash`, and remove any ordering after `plymouth-quit-wait.service`. The splash then stays on screen until the greeter's Hyprland draws.

## Testing

Preview the greeter in your running session before switching to it:

```sh
serpantinum-greeter test
```

Without greetd the greeter runs in test mode: any password plays the unlock animation and quits, **Ctrl+Esc** quits immediately. For the first real test through greetd, log in on a second TTY first (Ctrl+Alt+F3) in case something hangs.

## Fingerprint

greetd has only one PAM conversation, while the lock screen uses two in parallel.

- `SERPANTINUM_GREETER_HYBRID_AUTH=1` (default): `pam_unix` has to come before `pam_fprintd` in the greetd PAM stack. The greeter answers the password question empty, PAM moves on to the sensor, and the sensor is active right away. When you type a password, the greeter restarts the conversation and sends it as the answer to the first question. Every cycle logs a failed `pam_unix` attempt, so don't combine this with `pam_faillock`. The NixOS module sets up this PAM stack when `services.fprintd.enable` is true.
- `SERPANTINUM_GREETER_HYBRID_AUTH=0`: fingerprint first (the usual order). A typed password is kept and sent once `pam_fprintd` gives up.

Logging in with a fingerprint leaves a GNOME keyring locked, because there is no password to unlock it.

## Limits

- One user, no user or session selection.
- Video wallpapers don't play; the PNG snapshot is shown instead.
- The greeter runs in Hyprland (0.57 or newer, Lua config).
