---
sidebar_position: 2
title: App theming
sidebar_label: App theming
slug: /configure/app-theming
---

# App theming

Serpantinum can recolor other apps with the same palette as the shell, whether it comes from the wallpaper (Matugen) or from a preset. Open **Settings → Theme → App theming**. The page lists the apps that are currently themed. Add another one from **Add app**, or remove one with the cross next to it.

**Add app** only offers apps that are installed. Nothing is installed for you, and an app that is switched on but not installed is skipped.

On by default: **Kitty**, **Cava**, **GTK** and **Qt**. Everything else is opt-in.

## How it works

Every time the colors change, Serpantinum renders each enabled app's template with [matugen](https://github.com/InioX/matugen) into a separate theme file, such as `~/.config/kitty/themes/serpantinum.conf`. It then adds a single include line to the app's own config so the app loads that file.

Your config files are never overwritten. The lines Serpantinum adds are wrapped in markers:

```
# >>> serpantinum theme >>>
include themes/serpantinum.conf
# <<< serpantinum theme <<<
```

If one of your existing lines would override the theme (for example another `theme =` line), it is commented out as `# serpantinum-disabled: ...`.

When you switch an app off, Serpantinum removes its block, restores the lines it commented out, deletes the generated theme file and puts back any setting values it changed. A config file it had to create is removed again if nothing else was added to it.

When a config can't be edited safely, for example because it is a read-only file managed by Home Manager or its structure is unusual, nothing is changed. The settings page shows the exact line to add yourself.

Apps are only reloaded when their colors actually changed. A broken template only affects its own app, never the shell or other apps.

## Built-in apps

| App | Theme file | Config change |
| :--- | :--- | :--- |
| GTK 3 / 4 | `~/.config/gtk-{3,4}.0/serpantinum.css` | `@import` at the top of `gtk.css`; sets `color-scheme` and, if [adw-gtk3](https://github.com/lassekongo83/adw-gtk3) is installed, `gtk-theme` |
| Qt | `~/.config/qt{5,6}ct/colors/serpantinum.conf` | `color_scheme_path` and `custom_palette` in `qt5ct.conf` / `qt6ct.conf`. Needs qt6ct (or qt5ct) and `QT_QPA_PLATFORMTHEME=qt6ct` |
| KDE apps | `~/.local/share/color-schemes/Serpantinum.colors` | Color groups and `ColorScheme` in `kdeglobals` |
| Kitty | `~/.config/kitty/themes/serpantinum.conf` | `include` in `kitty.conf` |
| Alacritty | `~/.config/alacritty/themes/serpantinum.toml` | `import` under `[general]` |
| Foot | `~/.config/foot/themes/serpantinum` | `include=` in `foot.ini` |
| Ghostty | `~/.config/ghostty/themes/serpantinum` | `theme = serpantinum` |
| WezTerm | `~/.config/wezterm/colors/serpantinum.toml` | `config.color_scheme` before `return config` |
| Konsole | `~/.local/share/konsole/Serpantinum.colorscheme` | None, pick it in your profile |
| Helix | `~/.config/helix/themes/serpantinum.toml` | `theme = "serpantinum"` |
| Neovim | `~/.config/nvim/colors/serpantinum.lua` | None, run `:colorscheme serpantinum` |
| Zed | `~/.config/zed/themes/serpantinum.json` | None, pick it in the theme selector |
| Btop | `~/.config/btop/themes/serpantinum.theme` | `color_theme` in `btop.conf` |
| Cava | `~/.config/cava/themes/serpantinum` | `theme` under `[color]` |
| Fastfetch | `~/.config/fastfetch/serpantinum.jsonc` | None, run `fastfetch -c serpantinum` |
| tmux | `~/.config/tmux/serpantinum.conf` | `source-file` in `tmux.conf` |
| Zellij | `~/.config/zellij/themes/serpantinum.kdl` | `theme "serpantinum"` |
| Zathura | `~/.config/zathura/serpantinum` | `include serpantinum` |
| Fuzzel | `~/.config/fuzzel/serpantinum.ini` | `include=` in `fuzzel.ini` |
| Rofi | `~/.local/share/rofi/themes/serpantinum.rasi` | `@theme "serpantinum"` |
| Discord (Vencord, Vesktop, Equicord, Equibop) | `themes/serpantinum.theme.css` in each client's folder | None, enable it in the client |
| Spotify (Spicetify) | `~/.config/spicetify/Themes/Serpantinum/` | None, run `spicetify config current_theme Serpantinum`, then `spicetify apply` |
| Firefox (Pywalfox) | `~/.cache/wal/colors.json` | None, runs `pywalfox update` |

Compositor borders are never themed. They stay in your compositor config.

## Your own templates

Templates you own live in `${XDG_CONFIG_HOME:-~/.config}/serpantinum/matugen/apps/`. The folder button on the App theming page opens it.

- **Customize a built-in app:** press the edit button next to it. Its template is copied into this folder and opened. A folder with the same name as a built-in app replaces it, and the reset button restores the built-in version. Your copy is kept in `~/.local/state/serpantinum/matugen/backup/`.
- **Add any other app:** choose **Custom app...** in **Add app** and fill in:
  - **Name:** how it shows in the list.
  - **Theme file:** where the colors are written, such as `~/.config/myapp/colors.conf`. It has to be a new file, so nothing of yours is overwritten.
  - **Config file** and **Line to add** (optional, together): the app's own config and the line that makes it load the theme file, such as `include colors.conf`. It is added and removed just like for built-in apps.

  The app is themed straight away, and its template opens. The template starts as a list of example `key=value` colors. Rewrite it in the format your app expects, using matugen placeholders like `{{colors.primary.default.hex}}`. It is rendered again on every color change. The generated `app.json` can be edited for anything the form doesn't cover.

Each app is a folder with an `app.json` and its template files:

```json
{
  "name": "My app",
  "category": "apps",
  "icon": "󰏘",
  "detect": { "bin": ["myapp"] },
  "templates": [
    { "input": "colors.conf", "output": "$XDG_CONFIG_HOME/myapp/serpantinum.conf" }
  ],
  "integrate": [
    {
      "type": "line",
      "file": "$XDG_CONFIG_HOME/myapp/myapp.conf",
      "line": "include serpantinum.conf",
      "create": true
    }
  ],
  "reload": ["pkill -USR1 -x myapp; true"]
}
```

- `templates`: Files rendered with matugen. Use the usual matugen syntax, such as `{{colors.primary.default.hex}}`, `{{colors.surface.default.hex_stripped}}` or `{{mode}}`.
- `detect`: The app is listed when any of `bin` (a command on `PATH`), `flatpak` (an app id) or `path` exists. Leave it out to always list the app.
- `integrate`: Optional config edits.
  - `line`: Adds lines inside a marker block. Takes `section` (an INI or TOML section, or `""` for the top of the file), `position` (`"end"`, `"start"` or `{"before": "<regex>"}`), `disable` (a regex of lines to comment out), `skip_if` (a regex that means the user already set it up), `comment` (`"#"`, `"//"`, `"--"` or `["/*", "*/"]`) and `create`.
  - `ini`: Sets `key=value` pairs in apps that rewrite their own config (like qt6ct). The previous values are remembered and restored.
  - `gsettings`: Sets a GSettings key. The previous value is restored when the app is switched off.
- `when`: Any template or integration can take a `when` condition with the same keys as `detect`, plus `version` (`{"bin": "foot", "min": "1.23.0"}`).
- `reload`: Shell commands run after the theme changed.

Paths can use `$HOME`, `$XDG_CONFIG_HOME`, `$XDG_DATA_HOME`, `$XDG_CACHE_HOME`, `$XDG_STATE_HOME` and `$TILDE_CONFIG_HOME` (the config folder written with `~`, for config lines that should stay portable).

## Command line

```sh
serpantinum info theme apps
serpantinum set theme app <id> [on|off|toggle]
```
