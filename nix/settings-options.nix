{ lib, pkgs, ... }:
with lib;
let
  jsonFreeform = (pkgs.formats.json { }).type;

  freeform = options: types.submodule {
    freeformType = jsonFreeform;
    inherit options;
  };

  mkOpt = type: description: mkOption {
    type = types.nullOr type;
    default = null;
    inherit description;
  };

  generalSubmodule = freeform {
    language = mkOpt types.str "UI language code.";
    avatarPath = mkOpt types.str "Path to the avatar image shown in the shell.";
    wallpaperDir = mkOpt types.str "Directory for wallpapers.";
    workspaceCount = mkOpt types.ints.positive "Default number of workspaces.";
    muteSfx = mkOpt types.bool "Mute UI sound effects.";
    sfxVolume = mkOpt (types.ints.between 0 100) "UI sound effect volume, 0-100.";
    screenshotCaptureOnRelease = mkOpt types.bool "Capture screenshot region immediately on mouse release.";
    weatherInterval = mkOpt types.ints.positive "Minutes between weather refreshes.";
    weatherUnit = mkOpt (types.enum [ "metric" "imperial" "standard" ]) "Units for weather display.";
    quickactions = mkOpt types.bool "Show the quick actions panel.";
    location = mkOption {
      type = freeform {
        city = mkOpt types.str "Location city name.";
        latitude = mkOpt (types.either types.number types.str) "Latitude coordinate.";
        longitude = mkOpt (types.either types.number types.str) "Longitude coordinate.";
      };
      default = { };
    };
  };

  barSubmodule = freeform {
    position = mkOpt (types.enum [ "left" "right" "top" "bottom" ]) "Which screen edge the bar docks to.";
    width = mkOpt types.ints.positive "Bar thickness in pixels or percentage.";
    opacity = mkOpt (types.ints.between 0 100) "Bar background opacity, 0-100.";
    style = mkOpt (types.enum [ "solid" "fill" "modular" ]) "Bar visual style.";
    distinctPills = mkOpt types.bool "Render distinct background pills for bar modules in solid/fill style.";
    autohide = mkOpt types.bool "Auto-hide the bar when not in use.";
    autohideTimeout = mkOpt types.ints.positive "Milliseconds of inactivity before the bar autohides.";
    workspaceCount = mkOpt types.ints.positive "Number of workspace indicators to show.";
    hideEmptyWorkspaces = mkOpt types.bool "Hide unoccupied workspace indicators in the bar.";
    workspacesStyle = mkOpt (types.enum [ "pills" "numbers" "pacman" ]) "Workspace module display style.";
    timeStyle = mkOpt (types.enum [ "classic" "material" "badge" ]) "Time module display style.";
    timeShowDate = mkOpt types.bool "Display date text alongside clock in time module.";
    time = mkOption {
      type = freeform {
        format = mkOpt types.str ''Clock format, e.g. "HH:mm:ss".'';
      };
      default = { };
    };
    modules = mkOption {
      type = freeform {
        left = mkOpt (types.listOf (types.either types.str (types.listOf types.str))) "Modules in the left bar section.";
        center = mkOpt (types.listOf (types.either types.str (types.listOf types.str))) "Modules in the center bar section.";
        right = mkOpt (types.listOf (types.either types.str (types.listOf types.str))) "Modules in the right bar section.";
      };
      default = { };
      description = ''
        Which modules render in each bar section, in order. An entry
        is either a bare module name ("workspaces") or a nested list
        to cluster icons together.
      '';
    };
  };

  dockSubmodule = freeform {
    enabled = mkOpt types.bool "Enable floating application dock.";
    position = mkOpt (types.enum [ "bottom" "top" "left" "right" ]) "Screen edge to anchor the dock.";
    onTop = mkOpt types.bool "Keep dock on top of application windows.";
    elementSize = mkOpt types.ints.positive "Dimension of individual app buttons in pixels.";
    floating = mkOpt types.bool "Detach dock from screen edge with rounded corners.";
    opacity = mkOpt (types.ints.between 0 100) "Dock background opacity, 0-100.";
    exclusive = mkOpt types.bool "Prevent windows from taking space occupied by the dock.";
    exclusiveMode = mkOpt types.bool "Alias for exclusive.";
    autohide = mkOpt types.bool "Hide dock when not hovering over screen edge.";
    smartAutohide = mkOpt types.bool "Auto-hide dock only when windows are open.";
    autohideTimeout = mkOpt types.ints.positive "Duration in milliseconds before hiding dock.";
    editing = mkOpt types.bool "Whether dock is in editing mode.";
    apps = mkOpt (types.listOf jsonFreeform) "List of configured applications pinned to the dock.";
    overrideBoundsCorrection = mkOpt types.bool "Override out-of-screen-bounds size correction.";
    enableScrolling = mkOpt types.bool "Enable element scrolling on the dock.";
    visibleElements = mkOpt types.ints.positive "Number of visible dock elements when scrolling is enabled.";
    hoverScale = mkOpt types.ints.positive "Hover magnification percentage (e.g. 120).";
    cascadeScale = mkOpt types.bool "Cascading magnification on neighboring icons.";
  };

  launcherSubmodule = freeform {
    position = mkOpt (types.enum [ "top" "bottom" "left" "right" "center" ]) "Screen position for the application launcher.";
    width = mkOpt types.ints.positive "Width of the launcher window in pixels.";
    itemCount = mkOpt types.ints.positive "Number of search results displayed simultaneously.";
    terminalCommand = mkOpt types.str "Terminal execution prefix command.";
    smartRanking = mkOpt types.bool "Rank apps and widgets by usage frequency and recency.";
  };

  osdSubmodule = freeform {
    horizontalPosition = mkOpt (types.ints.between 0 100) "Horizontal position percentage across the screen.";
    verticalPosition = mkOpt (types.ints.between 0 100) "Vertical position percentage across the screen.";
    orientation = mkOpt (types.enum [ "horizontal" "vertical" ]) "Orientation of OSD bar.";
    showCapsLock = mkOpt types.bool "Show OSD notification on Caps Lock toggle.";
    showNumLock = mkOpt types.bool "Show OSD notification on Num Lock toggle.";
    showAirplane = mkOpt types.bool "Show OSD notification on Airplane mode toggle.";
    attachToBar = mkOpt types.bool "Snap OSD popups to the status bar in solid or fill mode.";
  };

  widgetsSubmodule = freeform {
    hideBarInRedactor = mkOpt types.bool "Automatically hide the bar when editing widgets in redactor mode.";
  };

  themeSubmodule = freeform {
    fontFamily = mkOpt types.str "UI font family.";
    borderRadius = mkOpt types.ints.unsigned "Corner radius used across the shell, in pixels.";
    activePreset = mkOpt types.str "Name of the active theme preset.";
    matugen = mkOpt types.bool "Auto-generate colors from the current wallpaper.";
    mode = mkOpt types.str "Color scheme mode (dark or light).";
    schemeType = mkOpt types.str "Matugen scheme type.";
    colors = mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = "Catppuccin-shaped hex palette (base, crust, mantle, text, surface0..2, ...). Any key name is accepted.";
    };
  };

  idleActionSubmodule = freeform {
    id = mkOpt types.str "Identifier for this idle action.";
    name = mkOpt types.str "Display name for this idle action.";
    desc = mkOpt types.str "Description of this idle action.";
    enabled = mkOpt types.bool "Whether this idle action is active.";
    timeout = mkOpt types.ints.positive "Seconds of inactivity before this action fires.";
    respectInhibitors = mkOpt types.bool "Skip this action while an idle inhibitor is held.";
    mprisInhibit = mkOpt types.bool "Also suppress this action while media is playing.";
    command = mkOpt types.str "Custom command instead of the built-in action. Empty uses the default.";
    beforeCommand = mkOpt types.str "Command executed right before the action triggers.";
    resumeCommand = mkOpt types.str "Command to run when returning from this action.";
    warningTimeout = mkOpt types.ints.unsigned "Seconds of warning before the action fires, 0 disables it.";
    warningCommand = mkOpt types.str "Offset command to execute when the warning period begins.";
    isCustom = mkOpt types.bool "Whether this action is user-created.";
  };

  idleSubmodule = freeform {
    enabled = mkOpt types.bool "Master switch for the idle system.";
    manualInhibit = mkOpt types.bool "Whether manually toggling \"inhibit idle\" is exposed to the user.";
    actions = mkOption {
      type = freeform {
        dim = mkOption { type = idleActionSubmodule; default = { }; };
        dpms = mkOption { type = idleActionSubmodule; default = { }; };
        lock = mkOption { type = idleActionSubmodule; default = { }; };
        suspend = mkOption { type = idleActionSubmodule; default = { }; };
      };
      default = { };
    };
    customActions = mkOpt (types.listOf jsonFreeform) "Extra idle actions beyond the four built-in ones.";
  };

  notificationsSubmodule = freeform {
    dnd = mkOpt types.bool "Do Not Disturb - suppress notification popups.";
    position = mkOpt (types.either (types.enum [ "top right" "top center" "top left" "bottom right" "bottom center" "bottom left" "custom" ]) types.str) "Corner or edge of the screen notifications appear in.";
    horizontalPosition = mkOpt (types.ints.between 0 100) "Horizontal position percentage across the screen.";
    verticalPosition = mkOpt (types.ints.between 0 100) "Vertical position percentage across the screen.";
    sound = mkOpt types.bool "Play a sound on incoming notifications.";
    soundFile = mkOpt types.str "Path to the notification sound file.";
    showEmptyGraphic = mkOpt types.bool "Show empty illustration graphic when notification history is clear.";
  };

  monitorSubmodule = freeform {
    enabled = mkOpt types.bool "Whether this output is used by the shell.";
    powerEnabled = mkOpt types.bool "Whether the monitor output display is powered on.";
    scale = mkOpt (types.either types.int types.float) "Display scale factor.";
    auto = mkOpt types.bool "Let Serpantinum auto-manage this output instead of using the fields above.";
    temperature = mkOpt types.int "Colour-temperature override for this output.";
  };

  displaySubmodule = freeform {
    monitors = mkOption {
      type = types.attrsOf monitorSubmodule;
      default = { };
      description = ''Per-monitor overrides keyed by output name, e.g. "eDP-1" or "DP-2".'';
    };
  };

  quoteSubmodule = freeform {
    enabled = mkOpt types.bool "Whether quote display is enabled.";
    text = mkOpt types.str "Quote text to display.";
    lockScreenPosition = mkOpt (types.enum [ "both" "clock" "dialog" "off" ]) "Where to display the quote on the lock screen.";
  };
in
{
  settingsSubmodule = freeform {
    general = mkOption { type = generalSubmodule; default = { }; };
    bar = mkOption { type = barSubmodule; default = { }; };
    dock = mkOption { type = dockSubmodule; default = { }; };
    launcher = mkOption { type = launcherSubmodule; default = { }; };
    osd = mkOption { type = osdSubmodule; default = { }; };
    widgets = mkOption { type = widgetsSubmodule; default = { }; };
    theme = mkOption { type = themeSubmodule; default = { }; };
    idle = mkOption { type = idleSubmodule; default = { }; };
    notifications = mkOption { type = notificationsSubmodule; default = { }; };
    display = mkOption { type = displaySubmodule; default = { }; };
    quote = mkOption { type = quoteSubmodule; default = { }; };
    wallpaperDir = mkOpt types.str ''
      Directory Serpantinum reads wallpapers from.
    '';
    wallpaper_dir = mkOpt types.str ''
      Alias for wallpaperDir.
    '';
  };
}
