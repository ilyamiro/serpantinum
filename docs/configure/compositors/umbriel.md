---
sidebar_position: 5
title: Umbriel
sidebar_label: Umbriel
slug: /configure/compositors/umbriel
---

# Umbriel

Configuration is stored in `~/.config/umbriel`. The main file is `config.toml`, which includes modular files from `config/`:

- `input` - keyboard layout and touchpad settings
- `layout` - window gaps and borders
- `autostart` - startup processes
- `keybinds` - keybindings for compositor actions and shell controls

The bundled files use the current action syntax, where an action and its arguments are separated by spaces (`workspace-switch 3`, `spawn kitty`). Older Umbriel builds used a colon (`spawn:kitty`) and reject these files, so use a current build. Validate a config without starting the compositor using `umbriel config validate -c ~/.config/umbriel/config.toml`.

:::warning[NixOS]
Nixpkgs currently ships an older snapshot of Umbriel that still uses the colon syntax and rejects these files. Use the upstream flake, which provides current builds. Add `inputs.umbriel.url = "github:noctalia-dev/umbriel";`, then import its module and enable it:

```nix
{ inputs, ... }:
{
  imports = [ inputs.umbriel.nixosModules.default ];

  programs.umbriel.enable = true;
}
```
:::

## Autostart

The shell daemon and clipboard history are launched from `config/autostart.toml`:

```toml
[general]
show_cheatsheet = false
autostart = [
  "wl-paste --type text --watch cliphist store",
  "wl-paste --type image --watch cliphist store",
  "serpantinumd start",
]
```

Umbriel runs each entry through `/bin/sh`. `serpantinumd start` also starts the [audio engine](/audio).

## Keybindings

Umbriel's default binds live in its packaged `config.toml`, which it only loads when no user configuration exists, so `config/keybinds.toml` lists every bind. The packaged `Mod` bind that opens the Noctalia launcher is not included. `Mod` is the Super key.

Shell overlays and controls use `spawn serpantinum msg toggle <module>`, with the same keys as the other compositors:

```toml
[keybinds]
"Mod+D" = { action = "spawn serpantinum msg toggle launcher", repeat = false }
"Mod+B" = { action = "spawn serpantinum msg toggle system", repeat = false }
```

Window and workspace controls use native Umbriel actions:

| Key | Action |
| --- | --- |
| `Mod+Return`, `Mod+F`, `Mod+E` | Open kitty, Firefox and Ski |
| `Mod+Q` | `window-close` |
| `Mod+Shift+F` | `window-toggle-floating` |
| `Mod+BackSpace` | `scratchpad-toggle` |
| `Mod+Left`, `Mod+Right` | `window-focus-left`, `window-focus-right` |
| `Mod+Up`, `Mod+Down` | `workspace-previous`, `workspace-next` |
| `Mod+Ctrl+Left`, `Mod+Ctrl+Right` | `column-move-left`, `column-move-right` |
| `Mod+Ctrl+Up`, `Mod+Ctrl+Down` | `window-move-to-workspace-previous`, `window-move-to-workspace-next` |
| `Mod+Shift+Left`, `Mod+Shift+Right` | `window-modify-primary-extent` by -0.05 and +0.05 |
| `Mod+Shift+Up`, `Mod+Shift+Down` | `window-modify-secondary-extent` by -0.05 and +0.05 |
| `Mod+1` to `Mod+9` | `workspace-switch <n>` |
| `Mod+Shift+1` to `Mod+Shift+9` | `window-move-to-workspace <n>` |

Moving a window to a workspace follows it there. Volume and brightness keys repeat while held, while launchers and toggles do not.

The bind that quits the session is not set. Add `"Mod+Escape" = "session-quit"` to `config/keybinds.toml` if you want one.

## Workspaces

Workspaces belong to each output and are dynamic: Umbriel keeps one empty workspace at the end and removes empty ones when you leave them, so there is no fixed count. To use a fixed set instead, set `workspaces` on an output in your own `config.toml`, as described in the [Umbriel documentation](https://docs.noctalia.dev/umbriel/workspaces/).

## Layout

New windows open in Umbriel's default scrolling layout. The bundled config only sets a 4 px gap and removes window borders. Change the layout mode with `layout.mode` in `config/layout.toml`.
