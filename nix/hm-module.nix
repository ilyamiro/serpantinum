{ self, ... }:
{ config, lib, pkgs, ... }@args:

with lib;

let
  cfg = config.programs.serpantinum;
  system = pkgs.stdenv.hostPlatform.system;

  jsonFormat = pkgs.formats.json { };
  inherit (import ./settings-options.nix { inherit lib pkgs; }) settingsSubmodule;

  templateSettings = builtins.fromJSON (builtins.readFile "${self}/config/serpantinum/settings.json");

  userSettings = lib.filterAttrsRecursive (_: v: v != null) cfg.settings;

  mergedSettings = lib.recursiveUpdate templateSettings userSettings;
  settingsFile = jsonFormat.generate "serpantinum-settings.json" mergedSettings;

  settingsTarget = "${config.xdg.configHome}/serpantinum/settings.json";

  osGreeter = (args.osConfig or { }).programs.serpantinum.greeter or { };
  syncCfg = cfg.greeter.sync;
  avatarPath = cfg.settings.general.avatarPath or null;
in
{
  options.programs.serpantinum = {
    enable = mkEnableOption "the Serpantinum Quickshell desktop shell";

    package = mkOption {
      type = types.package;
      default = self.packages.${system}.default;
      defaultText = literalExpression "serpantinum.packages.<system>.default";
      description = "The Serpantinum package to use.";
    };

    settings = mkOption {
      type = settingsSubmodule;
      default = { };
      example = literalExpression ''
        {
          bar.position = "left";
          bar.modules.right = [ "tray" [ "kb" "wifi" "bt" "vol" "bat" ] ];
          theme.fontFamily = "Adwaita Mono";
          notifications.dnd = true;
        }
      '';
      description = ''
        Serpantinum configuration, layered on top of the package's
        bundled `config/serpantinum/settings.json` and written to
        `$XDG_CONFIG_HOME/serpantinum/settings.json`.
        See settings-options.nix for the full list of typed fields;
        anything not listed there can still be set as a plain
        attribute.
      '';
    };

    systemd = {
      enable = mkOption {
        type = types.bool;
        default = pkgs.stdenv.isLinux;
        description = "Whether to run serpantinumd as a `systemd --user` service.";
      };

      target = mkOption {
        type = types.str;
        default = "graphical-session.target";
        description = "Target serpantinumd is tied to (start/stop/restart with it).";
      };

      environment = mkOption {
        type = types.attrsOf types.str;
        default = { };
        example = { QT_QPA_PLATFORM = "wayland"; };
        description = "Extra environment variables for the serpantinumd unit.";
      };
    };

    greeter.sync = {
      enable = mkOption {
        type = types.bool;
        default = osGreeter.enable or false;
        defaultText = literalExpression "osConfig.programs.serpantinum.greeter.enable or false";
        description = ''
          Whether to mirror the files the greeter needs (wallpaper snapshot, colors,
          lock screen layout, settings, avatar, weather) into the greeter's state directory
          whenever they change. The greeter user cannot read your home directory.
        '';
      };

      stateDir = mkOption {
        type = types.str;
        default = osGreeter.stateDir or "/var/lib/serpantinum-greeter";
        defaultText = literalExpression ''osConfig.programs.serpantinum.greeter.stateDir or "/var/lib/serpantinum-greeter"'';
        description = "Greeter state directory; files are mirrored to its `home/` subfolder.";
      };
    };
  };

  config = mkIf cfg.enable {
    home.packages = [ cfg.package ];

    programs.serpantinum.settings.wallpaperDir = mkDefault "${config.home.homeDirectory}/Pictures/Wallpapers";

    home.activation.serpantinumSettings = hm.dag.entryAfter [ "writeBoundary" ] ''
      run mkdir -p ${escapeShellArg (builtins.dirOf settingsTarget)}
      if [ ! -e ${escapeShellArg settingsTarget} ]; then
        run install -m 0644 ${settingsFile} ${escapeShellArg settingsTarget}
      fi
    '';

    systemd.user.services.serpantinum = mkIf cfg.systemd.enable {
      Unit = {
        Description = "Serpantinum shell daemon";
        After = [ cfg.systemd.target ];
        PartOf = [ cfg.systemd.target ];
        X-Restart-Triggers = [ "${settingsFile}" ];
      };

      Service = {
        ExecStart = "${cfg.package}/bin/serpantinumd start";
        Restart = "on-failure";
        KillMode = "mixed";
        TimeoutStopSec = "5s";
        Environment = mapAttrsToList (n: v: "${n}=${v}") cfg.systemd.environment;
      };

      Install.WantedBy = [ cfg.systemd.target ];
    };

    systemd.user.services.serpantinum-greeter-sync = mkIf syncCfg.enable {
      Unit = {
        Description = "Mirror Serpantinum files for the login screen";
        StartLimitIntervalSec = 0;
      };
      Service = {
        Type = "oneshot";
        Environment = [ "SERPANTINUM_GREETER_DIR=${syncCfg.stateDir}" ];
        ExecStart = "${cfg.package}/bin/serpantinum-greeter sync";
      };
      Install.WantedBy = [ "default.target" ];
    };

    systemd.user.paths.serpantinum-greeter-sync = mkIf syncCfg.enable {
      Unit.Description = "Mirror Serpantinum files for the login screen when they change";
      Path = {
        PathChanged = [
          "${config.xdg.configHome}/serpantinum/settings.json"
          "${config.xdg.cacheHome}/serpantinum/wallpaper"
          "${config.xdg.cacheHome}/serpantinum/avatar/avatar_cropped.png"
          "${config.xdg.cacheHome}/serpantinum/weather/weather.json"
          "${config.xdg.stateHome}/serpantinum/qs_matugen_colors.json"
          "${config.xdg.stateHome}/serpantinum/qs_colors.json"
          "${config.xdg.stateHome}/serpantinum/lockscreen/layout.json"
          "%h/.face"
        ]
        ++ optional (avatarPath != null) avatarPath;
        Unit = "serpantinum-greeter-sync.service";
      };
      Install.WantedBy = [ "default.target" ];
    };
  };
}
