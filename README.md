<div align="center">
  <a href="https://ko-fi.com/ilyamiro">
    <img src="https://ko-fi.com/img/githubbutton_sm.svg" alt="ko-fi" />
  </a>
</div>

<div align="center">
  <img src="docs/assets/banner.png" alt="Serpantinum" width="850" />
</div>

## Previews

| | |
|---|---|
| ![Preview 1](docs/assets/previews/preview_1.png) | ![Preview 2](docs/assets/previews/preview_2.png) |
| ![Preview 3](docs/assets/previews/preview_3.png) | ![Preview 4](docs/assets/previews/preview_4.png) |

---

## Installation

> [!IMPORTANT]
> **Migrating from v1:** All previous configuration will be backed up and unused. Configuration of compositor settings such as monitors, keybinds, and autostart is now up to you, as the project migrated from being dotfiles to being a shell.

### Arch Linux and its derivatives

For Arch-based distributions (including systemd, OpenRC, and other init systems), run the automated installation script.:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/ilyamiro/serpantinum/master/install/install.sh)"

```

> [!NOTE]
> To update, when or if you recieve a notification about the new version being available, just run the script again and choose "update"

---

### Fedora and its derivatives

The same script works on Fedora (and derivatives such as Nobara or Ultramarine): it detects the distribution and installs the packages with dnf.

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/ilyamiro/serpantinum/master/install/install.sh)"
```

> [!NOTE]
> Fedora does not package `gpu-screen-recorder` or `wl-gammarelay-rs`, so screen recording and the blue light filter are unavailable there; the installer lists them among the failed packages. SDDM is set up with its Wayland greeter, since Fedora ships no Xorg server.

---

### NixOS

Serpantinum provides flake outputs, a NixOS module for system dependencies, and a Home Manager module for user configuration and service management.

#### 1. Add Flake Input

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

#### 2. configuration.nix

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
  ];
}

```

#### 3. Home Manager Configuration

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

#### 4. Updating

Update the flake lockfile and rebuild your system:

```bash
nix flake update serpantinum
sudo nixos-rebuild switch --flake .

```

> **Note:** The automatic installer handles compositor integration on standard distributions. On NixOS / Home Manager, you must manually integrate compositor configs.
> Sample configs, autostart entries, and keybindings for supported window managers and compositors are available in the [compositors](https://github.com/ilyamiro/serpantinum/tree/master/compositors) directory.


#### Required autostart

Remember to add clipboard listeners and required services to your compositor's autostart configuration for the clipboard and the equalizer to work properly.

Example on Hyprland:

```lua
hl.on("hyprland.start", function()
  hl.exec_cmd("wl-paste --type text --watch cliphist store")
  hl.exec_cmd("wl-paste --type image --watch cliphist store")
  hl.exec_cmd("systemctl --user enable --now easyeffects")
end)

```
---

## Running

To run the shell, launch `serpantinumd start`

---

## Credits

* Special thanks to Darkall44/Qylock for providing a gorgeous material SDDM theme!

<br><br><br>

<div align="center">
  <h3>Thanks to all contributors</h3>
  <br>

  <a href="https://github.com/TheRinder2"><img src="https://avatars.githubusercontent.com/u/48689803?v=4&s=48" width="48" height="48" alt="TheRinder2"></a>
  <a href="https://github.com/bizneskind-droid"><img src="https://avatars.githubusercontent.com/u/245046997?v=4&s=48" width="48" height="48" alt="bizneskind-droid"></a>
  <a href="https://github.com/Pigeon78"><img src="https://avatars.githubusercontent.com/u/151051379?v=4&s=48" width="48" height="48" alt="Pigeon78"></a>
  <a href="https://github.com/Eduarduar"><img src="https://avatars.githubusercontent.com/u/104547727?v=4&s=48" width="48" height="48" alt="Eduarduar"></a>
  <a href="https://github.com/Spinty-dev"><img src="https://avatars.githubusercontent.com/u/123001216?v=4&s=48" width="48" height="48" alt="Spinty-dev"></a>
  <a href="https://github.com/MrDexstor"><img src="https://avatars.githubusercontent.com/u/97257847?v=4&s=48" width="48" height="48" alt="MrDexstor"></a>
  <a href="https://github.com/coloramamoe"><img src="https://avatars.githubusercontent.com/u/117035740?v=4&s=48" width="48" height="48" alt="coloramamoe"></a>
  <a href="https://github.com/Zyxilon"><img src="https://avatars.githubusercontent.com/u/234867627?v=4&s=48" width="48" height="48" alt="Zyxilon"></a>
  <a href="https://github.com/gouthamkrishnap"><img src="https://avatars.githubusercontent.com/u/224089015?v=4&s=48" width="48" height="48" alt="gouthamkrishnap"></a>
  <a href="https://github.com/Stoltembergg"><img src="https://avatars.githubusercontent.com/u/312632452?v=4&s=48" width="48" height="48" alt="Stoltembergg"></a>
  <a href="https://github.com/andckadir"><img src="https://avatars.githubusercontent.com/u/175446585?v=4&s=48" width="48" height="48" alt="andckadir"></a>
  <a href="https://github.com/ArseniiTkachuk"><img src="https://avatars.githubusercontent.com/u/257102547?v=4&s=48" width="48" height="48" alt="ArseniiTkachuk"></a>
  <a href="https://github.com/MCUxDaredevil"><img src="https://avatars.githubusercontent.com/u/59441946?v=4&s=48" width="48" height="48" alt="MCUxDaredevil"></a>
  <a href="https://github.com/MILKv2"><img src="https://avatars.githubusercontent.com/u/142674287?v=4&s=48" width="48" height="48" alt="MILKv2"></a>
  <a href="https://github.com/pedrolourencosilva"><img src="https://avatars.githubusercontent.com/u/184855780?v=4&s=48" width="48" height="48" alt="pedrolourencosilva"></a>
  <a href="https://github.com/Vaspyyy"><img src="https://avatars.githubusercontent.com/u/197029450?v=4&s=48" width="48" height="48" alt="Vaspyyy"></a>
  <a href="https://github.com/Sergi122"><img src="https://avatars.githubusercontent.com/u/171693999?v=4&s=48" width="48" height="48" alt="Sergi122"></a>
  <a href="https://github.com/Syrup5845"><img src="https://avatars.githubusercontent.com/u/310795939?v=4&s=48" width="48" height="48" alt="Syrup5845"></a>
  <a href="https://github.com/forteleaf"><img src="https://avatars.githubusercontent.com/u/14119264?v=4&s=48" width="48" height="48" alt="forteleaf"></a>
  <a href="https://github.com/kranks-uga"><img src="https://avatars.githubusercontent.com/u/179175113?v=4&s=48" width="48" height="48" alt="kranks-uga"></a>
  <a href="https://github.com/zynx-real"><img src="https://avatars.githubusercontent.com/u/320626542?v=4&s=48" width="48" height="48" alt="zynx-real"></a>
</div>

<br><br>

---

## License

Copyright (C) 2026 Illia Miroshnichenko

This project is licensed under the GNU Affero General Public License version 3, or (at your option) any later version. See the [LICENSE.md](LICENSE.md) file for the full license text.

