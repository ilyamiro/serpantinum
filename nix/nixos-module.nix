{ self, ... }:
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.serpantinum;
  gcfg = cfg.greeter;
  system = pkgs.stdenv.hostPlatform.system;

  greeterEnv = {
    SERPANTINUM_GREETER_USER = gcfg.user;
    SERPANTINUM_GREETER_SESSION =
      if gcfg.sessionToJournal
      then "${pkgs.systemd}/bin/systemd-cat -t serpantinum-session ${gcfg.sessionCommand}"
      else gcfg.sessionCommand;
    SERPANTINUM_GREETER_SESSION_DESKTOP = gcfg.sessionDesktop;
    SERPANTINUM_GREETER_HYBRID_AUTH = if gcfg.hybridAuth then "1" else "0";
    SERPANTINUM_GREETER_DIR = gcfg.stateDir;
    SERPANTINUM_GREETER_KB_LAYOUT = gcfg.keyboard.layout;
    SERPANTINUM_GREETER_KB_VARIANT = gcfg.keyboard.variant;
    SERPANTINUM_GREETER_KB_OPTIONS = gcfg.keyboard.options;
  }
  // optionalAttrs (gcfg.extraHyprlandConfig != "") {
    SERPANTINUM_GREETER_HYPRLAND_EXTRA = "${pkgs.writeText "serpantinum-greeter-extra.lua" gcfg.extraHyprlandConfig}";
  }
  // optionalAttrs (gcfg.cursor.theme != null) {
    XCURSOR_THEME = gcfg.cursor.theme;
    HYPRCURSOR_THEME = gcfg.cursor.theme;
  }
  // {
    XCURSOR_SIZE = toString gcfg.cursor.size;
    HYPRCURSOR_SIZE = toString gcfg.cursor.size;
  };

  greeterSession = pkgs.writeShellScript "serpantinum-greeter-session" ''
    ${concatStringsSep "\n" (mapAttrsToList (n: v: "export ${n}=${escapeShellArg v}") greeterEnv)}
    export PATH=${makeBinPath [ gcfg.package gcfg.hyprlandPackage ]}:/run/current-system/sw/bin''${PATH:+:$PATH}
    export XDG_DATA_DIRS=/run/current-system/sw/share''${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}
    exec ${pkgs.systemd}/bin/systemd-cat -t serpantinum-greeter-hyprland \
      ${gcfg.hyprlandPackage}/bin/start-hyprland -- -c ${gcfg.package}/share/serpantinum/greeter/hyprland.lua
  '';

  plymouth = config.boot.plymouth.enable;
in
{
  options.programs.serpantinum = {
    enable = mkEnableOption "system-level support for the Serpantinum desktop shell";

    greeter = {
      enable = mkEnableOption "the Serpantinum lock screen as greetd greeter";

      package = mkOption {
        type = types.package;
        default = self.packages.${system}.default;
        defaultText = literalExpression "serpantinum.packages.<system>.default";
        description = "Serpantinum package the greeter is taken from. Use the same one as your shell.";
      };

      hyprlandPackage = mkOption {
        type = types.package;
        default = config.programs.hyprland.package;
        defaultText = literalExpression "config.programs.hyprland.package";
        description = "Hyprland package the greeter runs in (needs Lua config support, 0.57 or newer).";
      };

      user = mkOption {
        type = types.str;
        description = "User to log in. The greeter has no user selection.";
      };

      sessionCommand = mkOption {
        type = types.str;
        default = "start-hyprland";
        example = "uwsm start hyprland.desktop";
        description = "Command greetd runs after a successful login.";
      };

      sessionDesktop = mkOption {
        type = types.str;
        default = "Hyprland";
        description = "XDG_CURRENT_DESKTOP / XDG_SESSION_DESKTOP of the started session.";
      };

      sessionToJournal = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Run the session command through systemd-cat, so its startup output (e.g. from
          uwsm or Hyprland) goes to the journal (`journalctl -b -t serpantinum-session`)
          instead of being printed on the VT while the session starts.
        '';
      };

      hybridAuth = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Fingerprint and password at the same time, like the lock screen. Puts pam_unix
          before pam_fprintd in the greetd PAM stack. When false, the NixOS order stays
          (fingerprint first; a typed password is only checked afterwards).
          Only has an effect when `services.fprintd.enable` is true.
        '';
      };

      stateDir = mkOption {
        type = types.str;
        default = "/var/lib/serpantinum-greeter";
        description = ''
          Directory whose `home/` subfolder becomes the greeter's $HOME. It is owned by
          `user` and filled by `serpantinum-greeter sync` (see the Home Manager option
          `programs.serpantinum.greeter.sync.enable`).
        '';
      };

      keyboard = {
        layout = mkOption {
          type = types.str;
          default = config.services.xserver.xkb.layout;
          defaultText = literalExpression "config.services.xserver.xkb.layout";
          description = "Keyboard layout on the login screen.";
        };
        variant = mkOption {
          type = types.str;
          default = config.services.xserver.xkb.variant;
          defaultText = literalExpression "config.services.xserver.xkb.variant";
          description = "Keyboard variant on the login screen.";
        };
        options = mkOption {
          type = types.str;
          default = config.services.xserver.xkb.options;
          defaultText = literalExpression "config.services.xserver.xkb.options";
          description = "Keyboard options on the login screen.";
        };
      };

      cursor = {
        theme = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Cursor theme on the login screen. It must be installed system-wide.";
        };
        size = mkOption {
          type = types.int;
          default = 24;
          description = "Cursor size on the login screen.";
        };
      };

      extraHyprlandConfig = mkOption {
        type = types.lines;
        default = "";
        example = ''
          hl.monitor({ output = "eDP-1", mode = "preferred", position = "auto", scale = 1.5 })
        '';
        description = ''
          Lua appended to the greeter's Hyprland config, e.g. the same monitor lines as in
          your session, so the UI size and wallpaper snapshots per monitor match.
        '';
      };
    };
  };

  config = mkMerge [
    (mkIf cfg.enable {
      programs.ski.enable = mkDefault true;
      networking.networkmanager.enable = mkDefault true;
      hardware.bluetooth.enable = mkDefault true;
      hardware.i2c.enable = mkDefault true;
      services.power-profiles-daemon.enable = mkDefault true;
      security.rtkit.enable = mkDefault true;
      security.pam.services.serpantinum = { };

      services.pipewire = {
        enable = mkDefault true;
        alsa.enable = mkDefault true;
        alsa.support32Bit = mkDefault true;
        pulse.enable = mkDefault true;
      };

      fonts.packages = [ pkgs.nerd-fonts.iosevka ];
    })

    (mkIf gcfg.enable {
      services.greetd = {
        enable = true;
        settings.default_session = {
          user = "greeter";
          command = "${greeterSession}";
        };
        greeterManagesPlymouth = plymouth;
      };

      systemd.services.greetd = mkIf plymouth {
        after = [ "plymouth-start.service" "plymouth-quit.service" ];
        conflicts = [ "plymouth-quit.service" ];
        onFailure = [ "plymouth-quit.service" ];
        serviceConfig.ExecStartPre = [ "-${config.boot.plymouth.package}/bin/plymouth quit --retain-splash" ];
      };
      systemd.services.plymouth-quit = mkIf plymouth { wantedBy = mkForce [ ]; };

      systemd.tmpfiles.rules = [
        "d ${gcfg.stateDir} 0755 root root -"
        "d ${gcfg.stateDir}/home 0755 ${gcfg.user} users -"
      ];

      security.pam.services.greetd = mkIf (gcfg.hybridAuth && config.services.fprintd.enable) {
        useDefaultRules = mkForce true;
        startSession = true;
        updateWtmp = true;
        fprintAuth = true;
        rules = recursiveUpdate
          (genAttrs [ "auth" "account" "password" "session" ] (_: { login.enable = false; }))
          { auth.fprintd.order = config.security.pam.services.login.rules.auth.unix.order + 10; };
      };
    })
  ];
}
