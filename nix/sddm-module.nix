{ config, lib, pkgs, ... }:
let
  cfg = config.programs.serpantinum.sddmTheme;
  stateDir = "/var/lib/serpantinum-greeter";
  syncUser = cfg.syncUser;
  multimedia = pkgs.qt6.qtmultimedia;
  theme = pkgs.callPackage ./sddm-theme.nix { };
  sync = pkgs.writeShellApplication {
    name = "serpantinum-greeter-sync";
    runtimeInputs = [ pkgs.python3 pkgs.imagemagick pkgs.ffmpeg-headless ];
    text = ''
      exec python3 -I ${theme}/libexec/serpantinum-greeter-sync.py
    '';
  };
in
{
  options.programs.serpantinum.sddmTheme = {
    enable = lib.mkEnableOption "Serpantinum's lock-screen-inspired SDDM theme";
    syncUser = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Local user whose Serpantinum appearance is shown on the shared login screen.";
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      services.displayManager.sddm = {
        enable = lib.mkDefault true;
        theme = "${theme}/share/sddm/themes/serpantinum";
        extraPackages = [ multimedia ];
        settings.General.GreeterEnvironment = lib.mkDefault (lib.concatStringsSep "," [
          "QML_XHR_ALLOW_FILE_READ=1"
          "QML_IMPORT_PATH=${multimedia}/lib/qt-6/qml"
          "QT_PLUGIN_PATH=${multimedia}/lib/qt-6/plugins"
        ]);
      };

      systemd.services.serpantinum-greeter-metrics = {
        description = "Collect local hardware readings for the Serpantinum SDDM theme";
        serviceConfig = {
          Type = "oneshot";
          User = "sddm";
          Group = "sddm";
          NoNewPrivileges = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          RuntimeDirectory = "serpantinum-greeter-system";
          RuntimeDirectoryPreserve = true;
          ExecStart = "${pkgs.python3}/bin/python3 -I ${theme}/libexec/serpantinum-greeter-metrics.py";
        };
      };
      systemd.timers.serpantinum-greeter-metrics = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnBootSec = "3s";
          OnUnitInactiveSec = "15s";
          AccuracySec = "2s";
        };
      };
    }
    (lib.mkIf (syncUser != null) {
      systemd.tmpfiles.rules = [ "d ${stateDir} 0755 ${syncUser} - -" ];

      systemd.services.serpantinum-greeter-initial = {
        description = "Seed the first Serpantinum SDDM appearance snapshot";
        wantedBy = [ "display-manager.service" ];
        before = [ "display-manager.service" ];
        after = [ "systemd-tmpfiles-setup.service" ];
        unitConfig.ConditionPathExists = "!${stateDir}/appearance.json";
        serviceConfig = {
          Type = "oneshot";
          User = syncUser;
          ExecStart = lib.getExe sync;
          TimeoutStartSec = "12s";
          NoNewPrivileges = true;
        };
      };

      systemd.user.services.serpantinum-greeter-sync = {
        description = "Export Serpantinum appearance for SDDM";
        unitConfig.ConditionUser = syncUser;
        serviceConfig = {
          Type = "oneshot";
          ExecStart = lib.getExe sync;
          UMask = "0022";
          TimeoutStartSec = 180;
          NoNewPrivileges = true;
        };
      };
      systemd.user.timers.serpantinum-greeter-sync = {
        description = "Keep the SDDM appearance synchronized";
        unitConfig.ConditionUser = syncUser;
        wantedBy = [ "default.target" ];
        timerConfig = {
          OnStartupSec = "2s";
          OnUnitInactiveSec = "5s";
          AccuracySec = "2s";
        };
      };
    })
  ]);
}
