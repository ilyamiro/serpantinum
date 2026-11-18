---
sidebar_position: 1
title: Flake input
sidebar_label: Flake input
slug: /installation/nixos
---

# NixOS: Flake input

Serpantinum provides flake outputs, a NixOS module for system dependencies, and a Home Manager module for user configuration and service management. This page covers the flake and the system module; see [Home Manager](/installation/nixos/home-manager) for the user configuration.

## Add the flake input

Add Serpantinum to your `flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    serpantinum.url = "github:ilyamiro/serpantinum";
  };

  outputs = { self, nixpkgs, serpantinum, ... }: {
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit serpantinum; };
      modules = [
        ./configuration.nix
        serpantinum.nixosModules.default
      ];
    };
  };
}
```

## Enable the system module

Enable the NixOS module to configure system prerequisites:

```nix
{
  programs.serpantinum.enable = true;
}
```

If you prefer installing the package directly without the system module:

```nix
{ pkgs, serpantinum, ... }:

{
  environment.systemPackages = [
    serpantinum.packages.${pkgs.stdenv.hostPlatform.system}.default
    serpantinum.packages.${pkgs.stdenv.hostPlatform.system}.ski
  ];
}
```

This installs Ski without the system module. Setting it as the default file manager and the open / save dialog needs the system module.

## Use the Serpantinum login screen

Opt into the Serpantinum theme to enable SDDM. Set `syncUser` to the desktop account whose appearance should be exported for the greeter:

```nix
{
  programs.serpantinum = {
    enable = true;
    sddmTheme = {
      enable = true;
      syncUser = "your-user";
    };
  };
}
```

Set your preferred SDDM compositor and session through the normal NixOS display manager options. Omitting `syncUser` uses the theme’s bundled appearance. The built theme and its helper scripts are also available as the `sddm-theme` package, which can be built from a checkout with `nix build .#sddm-theme`.

## Updating

Update the flake lockfile and rebuild your system:

```bash
nix flake update serpantinum
sudo nixos-rebuild switch --flake .
```
