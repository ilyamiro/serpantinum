---
sidebar_position: 2
title: Home Manager
sidebar_label: Home Manager
slug: /installation/nixos/home-manager
---

# NixOS: Home Manager

The Home Manager module manages the user configuration and the systemd service. It requires the [flake input](/installation/nixos) from the previous page.

:::note[Same options as settings.json]
The `settings` attribute set mirrors `settings.json` one to one: every section and key described in [Variables](/configure) is available under `programs.serpantinum.settings` with the same name and structure. Only the syntax changes, since you write Nix attributes instead of JSON. Keys that are not declared in the module are passed through to `settings.json` unchanged.
:::

```nix
{ serpantinum, ... }:

{
  imports = [
    serpantinum.homeManagerModules.default
  ];

  programs.serpantinum = {
    enable = true;
    systemd.enable = true;

    settings = {
      wallpaperDir = "/home/username/Pictures/Wallpapers";

      general = {
        language = "en";
        weatherUnit = "metric";
        weatherInterval = 30;
      };

      bar = {
        position = "top";
        style = "solid";
        width = 40;
        workspaceCount = 10;
        modules = {
          left = [ "workspaces" ];
          center = [ "time" ];
          right = [ "tray" [ "kb" "wifi" "bt" "vol" "bat" ] ];
        };
      };

      theme = {
        fontFamily = "Adwaita Mono";
        borderRadius = 12;
        matugen = true;
      };

      notifications = {
        dnd = false;
        position = "top right";
        sound = true;
      };
    };
  };
}
```
