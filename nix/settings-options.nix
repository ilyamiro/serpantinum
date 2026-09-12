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
    muteSfx = mkOpt types.bool "Mute UI sound effects.";
    weatherInterval = mkOpt types.ints.positive "Minutes between weather refreshes.";
    weatherUnit = mkOpt (types.enum [ "metric" "imperial" ]) "Units for weather display.";
    quickactions = mkOpt types.bool "Show the quick actions panel.";
    sfxVolume = mkOpt (types.ints.between 0 100) "UI sound effect volume, 0-100.";
  };

  barSubmodule = freeform {
    position = mkOpt (types.enum [ "left" "right" "top" "bottom" ]) "Which screen edge the bar docks to.";
    width = mkOpt types.ints.positive "Bar thickness in pixels.";
    opacity = mkOpt (types.ints.between 0 100) "Bar background opacity, 0-100.";
    style = mkOpt (types.enum [ "solid" "fill" "modular" ]) "Bar visual style.";
    autohide = mkOpt types.bool "Auto-hide the bar when not in use.";
    autohideTimeout = mkOpt types.ints.positive "Milliseconds of inactivity before the bar autohides.";
    workspaceCount = mkOpt types.ints.positive "Number of workspace indicators to show.";
    time = mkOption {
      type = freeform {
        format = mkOpt types.str ''Clock format, e.g. "HH:mm:ss".'';
      };
      default = { };
    };
    groupColors = mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = ''Per status-icon-group accent overrides, e.g. { g_kb = "#96cdf8"; }.'';
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
        to cluster icons together, e.g.
        `[ "tray" [ "kb" "wifi" "bt" "vol" "bat" ] ]`.
      '';
    };
  };

  themeSubmodule = freeform {
    fontFamily = mkOpt types.str "UI font family.";
    borderRadius = mkOpt types.ints.unsigned "Corner radius used across the shell, in pixels.";
    activePreset = mkOpt types.str "Name of the active theme preset.";
    matugen = mkOpt types.bool ''
      Auto-generate `colors` below from the current wallpaper. When
      true, `colors` is only a fallback/starting point - the running
      shell overwrites it at runtime.
    '';
    colors = mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = "Catppuccin-shaped hex palette (base, crust, mantle, text, surface0..2, ...). Any key name is accepted.";
    };
  };

  idleActionSubmodule = freeform {
    enabled = mkOpt types.bool "Whether this idle action is active.";
    timeout = mkOpt types.ints.positive "Seconds of inactivity before this action fires.";
    respectInhibitors = mkOpt types.bool "Skip this action while an idle inhibitor is held.";
    mprisInhibit = mkOpt types.bool "Also suppress this action while media is playing.";
    command = mkOpt types.str "Custom command instead of the built-in action. Empty uses the default.";
    resumeCommand = mkOpt types.str "Command to run when returning from this action.";
    warningTimeout = mkOpt types.ints.unsigned "Seconds of warning before the action fires, 0 disables it.";
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
    position = mkOpt (types.enum [ "top right" "top left" "bottom right" "bottom left" ]) "Corner of the screen notifications appear in.";
    sound = mkOpt types.bool "Play a sound on incoming notifications.";
    soundFile = mkOpt types.str "Path to the notification sound file.";
  };

  monitorSubmodule = freeform {
    enabled = mkOpt types.bool "Whether this output is used by the shell.";
    scale = mkOpt (types.either types.int types.float) "Display scale factor.";
    auto = mkOpt types.bool "Let Serpantinum auto-manage this output instead of using the fields above.";
    temperature = mkOpt types.int "Colour-temperature override for this output (units depend on how src/scripts drives wl-gammarelay-rs - check there if unsure).";
  };

  lockSubmodule = freeform {
    fingerprint = mkOpt types.bool "Unlock with an enrolled fingerprint (fprintd) while the password prompt is shown.";
    fingerprintTries = mkOpt types.ints.positive "Failed fingerprint matches before the reader gives up for this lock.";
  };

  displaySubmodule = freeform {
    monitors = mkOption {
      type = types.attrsOf monitorSubmodule;
      default = { };
      description = ''Per-monitor overrides keyed by output name, e.g. "eDP-1" or "DP-2".'';
    };
  };
in
{
  settingsSubmodule = freeform {
    general = mkOption { type = generalSubmodule; default = { }; };
    bar = mkOption { type = barSubmodule; default = { }; };
    theme = mkOption { type = themeSubmodule; default = { }; };
    idle = mkOption { type = idleSubmodule; default = { }; };
    notifications = mkOption { type = notificationsSubmodule; default = { }; };
    lock = mkOption { type = lockSubmodule; default = { }; };
    display = mkOption { type = displaySubmodule; default = { }; };
    wallpaperDir = mkOpt types.str ''
      Directory Serpantinum reads wallpapers from.
    '';
  };
}
