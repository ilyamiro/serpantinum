---
sidebar_position: 2
title: App theming
sidebar_label: App theming
slug: /configure/app-theming
---

# App theming

Serpantinum can recolor other apps with the same palette as the shell, whether it comes from the wallpaper (Matugen) or from a preset. Open **Settings → Theme → App theming**. The page lists the apps that are currently themed. Add another one from **Add app**, or remove one with the delete button on its tile.

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

When a config can't be edited safely, for example because it is a read-only file managed by Home Manager or its structure is unusual, nothing is changed. A warning button appears on the app's tile. Click it to see what went wrong and the exact line to add yourself, with buttons to copy it and to open the folder.

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
| Rio | `~/.config/rio/themes/serpantinum.toml` | `theme = "serpantinum"` |
| Helix | `~/.config/helix/themes/serpantinum.toml` | `theme = "serpantinum"` |
| VS Code (also VSCodium, Code - OSS, Cursor) | `~/.cache/serpantinum/apps/vscode.json` | Colors, token colors and the matching default theme in `User/settings.json`. Only plain JSON is edited: a file with comments gets a warning instead |
| Emacs | `serpantinum-theme.el` in `~/.config/emacs`, `~/.emacs.d` or `~/.config/doom/themes` | None, run `M-x load-theme serpantinum` |
| Obsidian | `.obsidian/snippets/serpantinum.css` in every vault | Adds the snippet to `enabledCssSnippets` in the vault's `appearance.json` |
| Neovim | `~/.config/nvim/colors/serpantinum.lua` | None, run `:colorscheme serpantinum` |
| Vim | `~/.vim/colors/serpantinum.vim` | None, run `:colorscheme serpantinum` |
| Kakoune | `~/.config/kak/colors/serpantinum.kak` | `colorscheme serpantinum` in `kakrc` |
| Micro | `~/.config/micro/colorschemes/serpantinum.micro` | None, run `> set colorscheme serpantinum` |
| Sublime Text | `~/.config/sublime-text/Packages/User/Serpantinum.sublime-color-scheme` | None, pick it in the color scheme selector |
| Btop | `~/.config/btop/themes/serpantinum.theme` | `color_theme` in `btop.conf` |
| Cava | `~/.config/cava/themes/serpantinum` | `theme` under `[color]` |
| Fastfetch | `~/.config/fastfetch/serpantinum.jsonc` | None, run `fastfetch -c serpantinum` |
| Fish | `~/.config/fish/conf.d/serpantinum.fish` | None, loaded by new shells |
| Bat | `~/.config/bat/themes/serpantinum.tmTheme` | `--theme="serpantinum"` in `bat/config`; runs `bat cache --build` |
| Yazi | `~/.config/yazi/flavors/serpantinum.yazi/` | `dark` and `light` under `[flavor]` in `theme.toml` |
| Lazygit | `~/.cache/serpantinum/apps/lazygit.yml` | A `gui.theme` block in `config.yml`. If it already has a `gui:` section, a warning shows the block to add |
| Starship | `~/.cache/serpantinum/apps/starship.toml` | `palette = "serpantinum"` and a `[palettes.serpantinum]` table in `starship.toml` |
| fzf | `~/.config/fzf/serpantinum.sh` (and a Fish `conf.d` snippet) | Sources the snippet from `~/.bashrc` and `~/.zshrc` if they exist |
| lsd | `~/.config/lsd/serpantinum.yaml` | `color.theme` in `config.yaml` |
| Superfile | `~/.config/superfile/theme/serpantinum.toml` | `theme` in `config.toml` |
| Glow | `~/.config/glow/serpantinum.json` | `style` in `glow.yml` |
| Atuin | `~/.config/atuin/themes/serpantinum.toml` | `name` under `[theme]` in `config.toml` |
| k9s | `~/.config/k9s/skins/serpantinum.yaml` | None, set `skin: serpantinum` in your k9s config |
| Claude Code | `~/.claude/themes/serpantinum.json` | None, pick it with `/theme` |
| tmux | `~/.config/tmux/serpantinum.conf` | `source-file` in `tmux.conf` |
| Zellij | `~/.config/zellij/themes/serpantinum.kdl` | `theme "serpantinum"` |
| Zathura | `~/.config/zathura/serpantinum` | `include serpantinum` |
| Fuzzel | `~/.config/fuzzel/serpantinum.ini` | `include=` in `fuzzel.ini` |
| Rofi | `~/.local/share/rofi/themes/serpantinum.rasi` | `@theme "serpantinum"` |
| Wofi | `~/.config/wofi/serpantinum.css` | `@import` at the top of `style.css` |
| Vicinae | `~/.local/share/vicinae/themes/serpantinum.toml` | None, pick it in the settings |
| Firefox (userChrome; also LibreWolf, Floorp) | `chrome/serpantinum.css` in every profile | `@import` in `chrome/userChrome.css` and the `toolkit.legacyUserProfileCustomizations.stylesheets` pref in `user.js` |
| Zen Browser | `chrome/serpantinum.css` in every profile | Same as Firefox |
| Halloy | `~/.config/halloy/themes/serpantinum.toml` | `theme` in `config.toml` |
| aerc | `~/.config/aerc/stylesets/serpantinum` | `styleset-name` under `[ui]` in `aerc.conf` |
| spotify-player | A `[[themes]]` entry in `theme.toml` | `theme` in `app.toml` |

Compositor borders are never themed. They stay in your compositor config.

## Customizing a built-in app

Press the edit button on an app's tile. Its files are copied to `${XDG_CONFIG_HOME:-~/.config}/serpantinum/matugen/apps/<app>/` and the folder opens. The folder button at the top of the page opens the parent folder.

- The template files use matugen syntax, such as `{{colors.primary.default.hex}}`, `{{colors.surface.default.hex_stripped}}` or `{{mode}}`. They are rendered again on every color change.
- `app.json` describes where the theme file goes and which line is added to the app's config. It usually doesn't need changes.
- The reset button restores the built-in version. Your copy is kept in `~/.local/state/serpantinum/matugen/backup/`.

Only built-in apps can be customized this way. Folders with other names are ignored.

## Command line

```sh
serpantinum info theme apps
serpantinum set theme app <id> [on|off|toggle]
```
