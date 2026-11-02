---
sidebar_position: 1
title: Variables
sidebar_label: Variables
slug: /configure
---

# Variables

The configuration file is located at `~/.config/serpantinum/settings.json` (or `${XDG_CONFIG_HOME:-$HOME/.config}/serpantinum/settings.json`), and changes apply instantly without a reload.

## Example settings.json

```json
{
  "general": {
    "language": "en"
  },
  "bar": {
    "position": "top",
    "width": 100,
    "style": "fill",
    "modules": {
      "left": ["left", "workspaces", "media"],
      "center": [["timedate", "info", "weather"]],
      "right": ["tray", ["kb", "wifi", "bt", "vol", "bat"]]
    }
  },
  "theme": {
    "fontFamily": "Adwaita Mono",
    "borderRadius": 10,
    "activePreset": "Matugen",
    "matugen": true
  },
  "launcher": {
    "position": "center",
    "terminalCommand": "kitty -e"
  },
  "dock": {
    "enabled": true,
    "position": "bottom"
  }
}
```

## Options

### General

| Key | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `general.language` | `string` | `"en"` | Interface language code (`en`, `fr`, `ua`, `ru`, `de`, `es`, `it`, `hy`, `vi`, `ko`, `pt`, `az`, `ar`, `ja`, `zh`, `zh_tw`, `pl`, `tr`, `id`, `nl`, `fa`, `hi`, `bg`). |
| `general.avatarPath` | `string` | `""` | Absolute path to custom profile picture. |
| `general.quickactions` | `boolean` | `true` | Enables the floating quick-actions overlay. |
| `general.settingsSeparateWindow` | `boolean` | `false` | Opens settings as a standalone resizable window instead of a panel inside the shell. |
| `general.muteSfx` | `boolean` | `false` | Mutes all sound effects. |
| `general.sfxVolume` | `number` | `100` | UI sound effects volume level (`0` to `100`). |
| `general.screenshotCaptureOnRelease` | `boolean` | `false` | Immediately captures region when releasing mouse drag without manual shutter confirmation. |
| `general.weatherInterval` | `number` | `15` | Weather update polling frequency in minutes (`1` to `1440`). |
| `general.weatherUnit` | `string` | `"metric"` | Temperature unit: `"metric"`, `"imperial"`, or `"standard"`. |
| `general.location` | `object` | `{}` | Geographic coordinates cache (`latitude`, `longitude`, `city`, `timezone`). |

### Theme

| Key | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `theme.fontFamily` | `string` | `"Adwaita Mono"` | Font family applied globally across all shell surfaces and popouts. |
| `theme.borderRadius` | `number` | `10` | Global corner radius in pixels (`0` to `24`). |
| `theme.activePreset` | `string` | `"Matugen"` | Active color palette preset name (e.g., `"Matugen"`, `"Catppuccin Mocha"`, `"Tokyo Night"`, `"Nord"`). |
| `theme.matugen` | `boolean` | `true` | Enables automatic Material You color extraction from the current wallpaper. |
| `theme.mode` | `string` | `"dark"` | Color scheme mode used for Material You generation: `"dark"` or `"light"`. |
| `theme.schemeType` | `string` | `"scheme-tonal-spot"` | Matugen scheme type used for Material You generation (e.g., `"scheme-tonal-spot"`). |
| `theme.colors` | `object` | `{}` | Custom hex color overrides for palette roles (`base`, `surface0`, `surface1`, `surface2`, `text`, `mauve`, `blue`, `sapphire`, `green`, `peach`, `red`, `crust`, `mantle`). |
| `wallpaperDir` | `string` | `"~/Pictures/Wallpapers"` | Directory scanned for desktop wallpapers in the wallpaper selector. |

### Display

| Key | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `display.monitors.<name>.enabled` | `boolean` | `true` | Output power state toggled via compositor IPC (Hyprland, Sway, Niri, Mango). |
| `display.monitors.<name>.powerEnabled` | `boolean` | `true` | Whether the monitor output is powered on. |
| `display.monitors.<name>.scale` | `number` | `1.0` | Output scaling factor (e.g., `1.0`, `1.25`, `1.5`, `2.0`). |
| `display.monitors.<name>.auto` | `boolean` | `false` | Automatically calculates night-light color temperature from local sunrise and sunset. |
| `display.monitors.<name>.temperature` | `number` | `50` | Night light warmth level (`0` to `100`). |

### Widgets

| Key | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `widgets.hideBarInRedactor` | `boolean` | `true` | Automatically hides the status bar while the desktop widget redactor is open. |

### Bar

| Key | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `bar.position` | `string` | `"top"` | Screen edge where the bar attaches: `"top"`, `"bottom"`, `"left"`, or `"right"`. |
| `bar.width` | `number` | `100` | Bar length percentage (`10` to `100`). Values below 100 render a floating dock-style bar, or in `"fill"` style a bar that rounds down into the screen edge. |
| `bar.opacity` | `number` | `100` | Background opacity percentage (`0` to `100`). |
| `bar.style` | `string` | `"modular"` | Visual bar style: `"modular"`, `"fill"`, or `"solid"`. |
| `bar.distinctPills` | `boolean` | `false` | Renders each module inside an isolated, detached capsule pill. |
| `bar.centerByEdges` | `boolean` | `true` | Keeps equal margins on both ends of the bar (left and right, or top and bottom for a vertical bar) instead of centering by the middle module. |
| `bar.autohide` | `boolean` | `false` | Automatically hides the bar until cursor enters the screen trigger area. |
| `bar.autohideTimeout` | `number` | `1000` | Delay in milliseconds before hiding the bar after cursor leaves. |
| `bar.workspaceCount` | `number` | `8` | Total number of persistent workspace indicators displayed. |
| `bar.hideEmptyWorkspaces` | `boolean` | `false` | Hides workspace indicators that have no assigned windows. |
| `bar.modules.left` | `array` | `["left", "workspaces", "media"]` | Modules positioned on the left/top section. Sub-arrays group modules into a shared pill. |
| `bar.modules.center` | `array` | `[["timedate", "info", "weather"]]` | Modules positioned on the center section. |
| `bar.modules.right` | `array` | `["tray", ["kb", "wifi", "bt", "vol", "bat"]]` | Modules positioned on the right/bottom section. |
| `bar.groupColors` | `object` | `{}` | Custom hex accent colors mapped to grouped module pill IDs (e.g. `{"g_sysmon": "#ffb59c"}`). |

### Bar modules

| Key | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `bar.workspacesStyle` | `string` | `"pills"` | Workspace indicator style: `"pills"`, `"numbers"`, or `"pacman"`. |
| `bar.timeStyle` | `string` | `"classic"` | Clock module visual style: `"classic"`, `"material"`, or `"badge"`. |
| `bar.time.format` | `string` | `"HH:mm:ss"` | Qt time format pattern string (e.g., `"HH:mm:ss"`, `"HH:mm"`, `"hh:mm AP"`). |
| `bar.timeShowDate` | `boolean` | `true` | Shows calendar date beside time. |
| `bar.visBarCount` | `number` | `16` | Number of spectrum frequency bars rendered (`4` to `32`). |
| `bar.visAlignment` | `string` | `"center"` | Visualizer spectrum alignment: `"center"`, `"top"`, `"bottom"`, `"left"`, or `"right"`. |
| `bar.visContinuous` | `boolean` | `false` | Renders a continuous waveform line instead of discrete frequency bars. |
| `bar.sysmonStyle` | `string` | `"wave"` | Resource monitor style: `"wave"`, `"circle"`, or `"bars"`. |
| `bar.sysmonStats` | `array` | `["cpu", "ram", "temp"]` | Monitored resource metrics: subset of `["cpu", "ram", "temp", "disk"]`. |
| `bar.batStyle` | `string` | `"classic"` | Battery module visual style: `"classic"`, `"minimal"`, `"text"`, or `"button"`. |
| `bar.batShowPercent` | `boolean` | `true` | Displays numeric percentage charge level. |
| `bar.batShowIcon` | `boolean` | `true` | Displays battery status glyph. |
| `bar.wifiStyle` | `string` | `"button"` | Wi-Fi module visual style: `"button"` or `"text"`. |
| `bar.wifiShowIcon` | `boolean` | `true` | Displays wireless signal icon. |
| `bar.wifiShowName` | `boolean` | `true` | Displays connected network SSID name. |
| `bar.btStyle` | `string` | `"button"` | Bluetooth module visual style: `"button"` or `"text"`. |
| `bar.btShowIcon` | `boolean` | `true` | Displays Bluetooth status icon. |
| `bar.btShowName` | `boolean` | `true` | Displays connected Bluetooth device alias. |
| `bar.volStyle` | `string` | `"button"` | Audio volume module visual style: `"button"` or `"text"`. |
| `bar.volShowIcon` | `boolean` | `true` | Displays speaker icon. |
| `bar.volShowPercent` | `boolean` | `true` | Displays numeric volume percentage. |
| `bar.kbStyle` | `string` | `"button"` | Keyboard layout module visual style: `"button"` or `"text"`. |
| `bar.kbShowIcon` | `boolean` | `true` | Displays keyboard glyph. |
| `bar.mediaInfoMode` | `string` | `"duration"` | Secondary line of the media module: `"duration"` or `"author"` (top and bottom bars). |
| `bar.mediaWidth` | `integer` | `120` | Width of the media text area in pixels (top and bottom bars). |
| `bar.mediaShowIcon` | `boolean` | `true` | Displays album art or music icon. |
| `bar.mediaShowControls` | `boolean` | `true` | Displays previous, play and next buttons. |

### Media source and visibility

These options are available in **Settings → Bar → Modules → Media**.
They are stored under `media`, because the source also controls desktop music
and lyrics widgets, including widgets on other monitors.

| Key | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `media.musicSource` | `string` | `"automatic"` | Automatic selection or the application key saved by the Media source selector. |
| `media.musicSourceName` | `string` | `""` | Display name retained while the selected application is unavailable. |
| `media.hideWhenIdle` | `boolean` | `false` | Hide media when no track is available. Keep the selected player's current track and controls visible while paused. |
| `media.hideUnavailableLyrics` | `boolean` | `false` | Hide desktop lyrics content and background when inactive, loading, or unavailable for the current track. |

- **Automatic** keeps the existing selection order: playing, last-playing,
  loaded, controllable, then any available player. Ties use the MPRIS D-Bus name
  (`dbusName` in Quickshell), not track metadata.
- Applications are discovered through MPRIS, without an application allowlist.
  Manual selection never falls back to another application. The preference
  remains visible when unavailable and reconnects when the application returns.
- Keys use `desktop:<DesktopEntry>`, then `mpris:<service>` with instance/PID
  suffixes removed, or `identity:<Identity>` when no service identifier exists.
  MPRIS has no universal application ID: fallback keys depend on the identifiers
  supplied by the application. Runtime service names are never saved as instance preferences.
- Multiple instances are grouped by application. Initial selection follows the
  automatic rules within that application; the chosen instance stays selected,
  including while paused, until it disconnects.

The music popup retains its manual player picker. When it selects another
player, its lyrics, seeking and local-file picker use a separate lyrics context;
the bar and desktop widgets continue following the global source. A track or
source change clears old lyrics immediately; cached matching lyrics can reappear
without a network request.

Changes apply immediately and persist across restarts. Missing keys and legacy
category policies from earlier versions of this feature use Automatic.

Hidden media takes no bar layout space and ignores input; the settings preview
stays visible. Hidden lyrics keep their subscription, so discovering a result
can reveal the widget again. Use the desktop editor to move or configure an
invisible lyrics widget.


### Launcher

| Key | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `launcher.position` | `string` | `"top"` | Screen anchor: `"top"`, `"bottom"`, `"left"`, `"right"`, or `"center"`. |
| `launcher.width` | `number` | `600` | Width of the launcher search window in pixels. |
| `launcher.itemCount` | `number` | `6` | Maximum visible applications in results list (`3` to `15`). |
| `launcher.terminalCommand` | `string` | `"kitty -e"` | Terminal execution command prefix for CLI applications (`"kitty -e"`, `"alacritty -e"`, `"foot -e"`). |
| `launcher.smartRanking` | `boolean` | `true` | Dynamically sorts search results based on launch history and usage frequency. |

### Dock

| Key | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `dock.enabled` | `boolean` | `true` | Master toggle for the application dock. |
| `dock.position` | `string` | `"bottom"` | Screen edge where dock attaches: `"bottom"`, `"top"`, `"left"`, or `"right"`. |
| `dock.onTop` | `boolean` | `true` | Keeps dock above normal client windows. |
| `dock.floating` | `boolean` | `false` | Detaches dock from screen edge with outer margin padding. |
| `dock.exclusive` | `boolean` | `false` | Reserves screen space via compositor layer-shell so tiled windows do not overlap. |
| `dock.opacity` | `number` | `100` | Dock surface opacity percentage (`0` to `100`). |
| `dock.elementSize` | `number` | `44` | Base icon size in pixels (`24` to `96`). |
| `dock.hoverScale` | `number` | `120` | Hover zoom factor percentage (`100` to `200`). |
| `dock.cascadeScale` | `boolean` | `false` | Applies parabolic wave magnification to neighboring icons on hover. |
| `dock.autohide` | `boolean` | `false` | Hides the dock until hovered. |
| `dock.smartAutohide` | `boolean` | `true` | Automatically hides the dock only when a window overlaps its area (intellihide). |
| `dock.autohideTimeout` | `number` | `1000` | Delay in milliseconds before hiding. |
| `dock.overrideBoundsCorrection` | `boolean` | `false` | Keeps the custom element size even if the dock exceeds the screen limits. |
| `dock.enableScrolling` | `boolean` | `false` | Enables mouse wheel scrolling when items exceed visible count. |
| `dock.visibleElements` | `number` | `7` | Maximum number of visible icons when scrolling is enabled. |
| `dock.focusRunning` | `boolean` | `true` | Clicking a running application raises and focuses its existing window. |
| `dock.showRunningIndicators` | `boolean` | `true` | Displays indicator dots beneath active running applications. |
| `dock.showRunningApps` | `boolean` | `false` | Automatically adds unpinned active applications to the dock. |
| `dock.runningScope` | `string` | `"auto"` | Filters running applications by workspace scope: `"auto"`, `"workspace"`, or `"all"`. |
| `dock.apps` | `array` | `[]` | List of pinned application objects (`[{"name": "...", "comment": "...", "desktop_id": "...", "icon": "..."}]`). |

### OSD

| Key | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `osd.horizontalPosition` | `number` | `50` | Horizontal coordinate on screen (`0` to `100` percent). |
| `osd.verticalPosition` | `number` | `90` | Vertical coordinate on screen (`0` to `100` percent). |
| `osd.orientation` | `string` | `"horizontal"` | Slider orientation: `"horizontal"` or `"vertical"`. |
| `osd.showCapsLock` | `boolean` | `true` | Displays popout banner when toggling CapsLock. |
| `osd.showNumLock` | `boolean` | `true` | Displays popout banner when toggling NumLock. |
| `osd.showAirplane` | `boolean` | `true` | Displays popout banner when toggling Airplane mode. |
| `osd.attachToBar` | `boolean` | `true` | Automatically offsets position relative to status bar when placed near the same edge. |

### Notifications

| Key | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `notifications.dnd` | `boolean` | `false` | Do Not Disturb mode; suppresses desktop banner popups. |
| `notifications.position` | `string` | `"top right"` | Screen anchor position: `"top right"`, `"top center"`, `"top left"`, `"bottom right"`, `"bottom center"`, `"bottom left"`, or `"custom"`. |
| `notifications.horizontalPosition` | `number` | `95` | Horizontal screen percentage used when position is `"custom"`. |
| `notifications.verticalPosition` | `number` | `5` | Vertical screen percentage used when position is `"custom"`. |
| `notifications.sound` | `boolean` | `true` | Plays an audio chime when notifications arrive. |
| `notifications.soundFile` | `string` | `""` | Absolute path to custom notification sound file (`.wav` or `.ogg`). |
| `notifications.showEmptyGraphic` | `boolean` | `true` | Displays decorative art in notification center when no notifications remain. |

### Idle

| Key | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `idle.enabled` | `boolean` | `true` | Master toggle for the idle power management subsystem. |
| `idle.lockOnSleep` | `boolean` | `true` | Locks the session before the system suspends for any reason, such as closing the lid. Requires `python-jeepney` and systemd-logind. |
| `idle.manualInhibit` | `boolean` | `false` | Caffeine mode; suppresses all automated idle timeouts. |
| `idle.actions.dim` | `object` | `{...}` | Screen dim action (`timeout`: seconds, `enabled`: boolean, `respectInhibitors`: boolean, `mprisInhibit`: boolean, `warningTimeout`: seconds, `beforeCommand`: string, `resumeCommand`: string). |
| `idle.actions.lock` | `object` | `{...}` | Session lock action (`timeout`: seconds, `enabled`: boolean, `respectInhibitors`: boolean, `mprisInhibit`: boolean, `warningTimeout`: seconds, `warningCommand`: string). |
| `idle.actions.dpms` | `object` | `{...}` | Display power off (DPMS) action (`timeout`: seconds, `enabled`: boolean, `respectInhibitors`: boolean, `mprisInhibit`: boolean). |
| `idle.actions.suspend` | `object` | `{...}` | System suspend action (`timeout`: seconds, `enabled`: boolean, `respectInhibitors`: boolean, `mprisInhibit`: boolean). |
| `idle.customActions` | `array` | `[]` | User-defined custom idle actions. Each entry accepts `id`, `name`, `desc`, `enabled`, `timeout`, `respectInhibitors`, `mprisInhibit`, `command`, `beforeCommand`, `resumeCommand`, `warningTimeout` and `warningCommand`. |

### Inputs

| Key | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `inputs.passwordReveal` | `boolean` | `false` | Displays a show/hide password toggle button inside password input fields. |
