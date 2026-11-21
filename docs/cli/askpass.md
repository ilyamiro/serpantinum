---
sidebar_position: 3
title: Password prompt for sudo
sidebar_label: Password prompt for sudo
slug: /cli/askpass
---

# Password prompt for sudo

`serpantinum-askpass` lets scripts that run `sudo` without a terminal ask for the password in Serpantinum's own dialog, the one used for polkit. The dialog follows the theme and the wallpaper colours.

Polkit already covers graphical apps. This is for tools that call plain `sudo`, for example a script started from the compositor's autostart or a keybinding.

## Usage

Point sudo at the helper and run it with `-A`:

```bash
SUDO_ASKPASS=serpantinum-askpass sudo -A pacman -Syu
```

`SUDO_ASKPASS` needs a full path when the helper is not in sudo's `PATH`, for example `~/.local/bin/serpantinum-askpass`.

To use it for every `sudo -A`, add this line to `/etc/sudo.conf`:

```
Path askpass /usr/bin/serpantinum-askpass
```

## Dialog text

| Variable | Default |
| --- | --- |
| `SERPANTINUM_ASKPASS_TITLE` | The polkit dialog's title. |
| `SERPANTINUM_ASKPASS_MESSAGE` | The polkit dialog's description. |

Sudo's own prompt, such as `[sudo] password for user:`, becomes the placeholder of the password field.

## Behaviour

- Enter submits the password. Escape, the close button or a click outside the card cancels, and sudo stops.
- After a wrong password sudo asks again, and the dialog shakes and shows an error.
- If the shell is not running, the helper prints an error and exits with status 1, so sudo fails instead of waiting.
- Sudo remembers the password per terminal. Without a terminal it remembers it per parent process, so a tool that starts each `sudo` from a new shell asks every time. To ask once, run the tool inside `script -qec '<command>' /dev/null`, which gives all its `sudo` calls one pseudo-terminal.
