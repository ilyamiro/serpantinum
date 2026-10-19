---
sidebar_position: 1
title: Installation
sidebar_label: Installation
slug: /installation
---

# Installation

:::warning[IMPORTANT]
**Migrating from v1:** All previous configuration will be backed up and unused. Configuration of compositor settings such as monitors, keybinds, and autostart is now up to you, as the project migrated from being dotfiles to being a shell.
:::

Serpantinum installs through an automated script on Arch Linux, Fedora, and their derivatives. The script detects your distribution and uses the matching package manager (`pacman` or `dnf`). On NixOS, use the [flake and modules](/installation/nixos) instead.

Use this installer:

```bash
curl -fsSL install.serpantinum.dev | bash
```

If this doesn't work, use:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/ilyamiro/serpantinum/master/install/install.sh)"
```

:::info[NOTE]
To update, when or if you receive a notification about a new version being available, run the installer script again and choose **Update**.
:::

## Fedora

Fedora and its derivatives, such as **Nobara** and **Ultramarine**, are installed with `dnf`. Fedora does not package `gpu-screen-recorder` or `wl-gammarelay-rs`, so screen recording and the blue light filter are unavailable there. SDDM is set up with its Wayland greeter, since Fedora ships no Xorg server.

## Arch Linux and derivatives

Serpantinum is verified and supported across Arch Linux and its derivative distributions, on systemd, OpenRC, and other init systems, including:

Arch Linux · EndeavourOS · Manjaro · CachyOS · Garuda Linux · ArcoLinux · Archcraft · Artix Linux · BlackArch · RebornOS · Mabox Linux · blendOS · Parch Linux · BigLinux · ArchLabs · Archman · ALCI · BlueStar · ArchBang · ArchEX · ArchStrike · Athena OS · ChimeraOS · Ctlos Linux · Crystal Linux · HefftorLinux · instantOS · Nyarch Linux · Obarun · Hyperbola · Parabola · Salient OS · Snal Linux · SteamOS / HoloISO · StormOS · TeArch · XeroLinux · Axyl · OMARCHY

## Build from source on Arch

Arch-based distributions can build Serpantinum as a native package from this repository instead of running the installer script. The package installs the shell system-wide and pulls in every runtime dependency the installer would. The parts of the installer that change your home directory, services, or login screen are not done by a package, so you run them yourself afterwards.

The repository contains two PKGBUILDs in `packaging/aur`, and they conflict with each other:

| Package | Builds |
| --- | --- |
| `serpantinum` | The latest tagged release |
| `serpantinum-git` | The latest commit on `master` |

Install the build tools and `wl-gammarelay-rs`, the one dependency that is not in the official repositories:

```bash
sudo pacman -S --needed base-devel git

git clone https://aur.archlinux.org/wl-gammarelay-rs.git
cd wl-gammarelay-rs
makepkg -si
cd ..
```

Then clone the repository and build the package:

```bash
git clone --depth 1 https://github.com/ilyamiro/serpantinum.git
cd serpantinum/packaging/aur/serpantinum
makepkg -si
```

For the latest commit instead of the latest release, use `cd serpantinum/packaging/aur/serpantinum-git`. `makepkg -si` installs the remaining dependencies with `pacman`, builds the package, and installs it.

:::warning[IMPORTANT]
Do not run the installer script on a system where Serpantinum is installed this way. It would place a second copy in `~/.local/share/serpantinum` and link it over the packaged one. Update by rebuilding the package, as described below, and use the steps that follow for anything the installer would otherwise do. If the in-app update notification offers to run the installer, ignore it.
:::

### What the package does

| Installer step | Package |
| --- | --- |
| Install dependencies | Done, including Iosevka Nerd Font |
| Replace `quickshell-git` with `quickshell` | Done, the package conflicts with `quickshell-git` and installs `quickshell` |
| Install `serpantinum` and `serpantinumd` | Done, in `/usr/bin` |
| Lock screen PAM service | Done, `/etc/pam.d/serpantinum` |
| SDDM theme files | Done, in `/usr/share/sddm/themes/material-you` |
| Compositor configs | Manual, step 1 |
| Kitty, Cava, and Fastfetch configs | Manual, step 2 |
| Wallpapers | Manual, step 3 |
| Serpantinum settings | Manual, step 4 |
| System services | Manual, step 5 |
| Qt icon theme | Manual, step 6 |
| SDDM configuration | Manual and optional, step 7 |
| First launch guide | Manual, step 8 |

The installer's anonymous install telemetry has no equivalent, so a package install sends none.

### Manual setup

The packaged files live in `/usr/share/serpantinum`. These steps copy what you need into your home directory and are written to be pasted into a shell one after another, since later steps reuse variables from earlier ones.

```bash
share=/usr/share/serpantinum
cfg="${XDG_CONFIG_HOME:-$HOME/.config}"
```

#### 1. Compositor config

Install the compositors you want, for example `sudo pacman -S hyprland`. The package lists Hyprland, Niri, Sway, and Mango as optional dependencies. Then copy the matching config. Choose one row:

| Compositor | `comp` | `dir` |
| --- | --- | --- |
| Hyprland | `hyprland` | `hypr` |
| Niri | `niri` | `niri` |
| Sway | `sway` | `sway` |
| Mango | `mango` | `mango` |

```bash
comp=hyprland
dir=hypr

if [ -d "$cfg/$dir" ]; then
    backup="$cfg/${dir}_backup/backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup"
    cp -a "$cfg/$dir/." "$backup/"
fi
mkdir -p "$cfg/$dir"
cp -r "$share/compositors/$comp/." "$cfg/$dir/"
```

Your existing config is backed up first. Files with the same name in the new config replace yours, so move any personal settings back from the backup afterwards.

#### 2. Kitty, Cava, and Fastfetch configs

```bash
for app in kitty cava fastfetch; do
    mkdir -p "$cfg/$app"
    cp -r "$share/config/$app/." "$cfg/$app/"
done
```

This replaces files with the same name. Skip any app whose config you want to keep.

#### 3. Wallpapers

```bash
pictures="$(xdg-user-dir PICTURES 2>/dev/null)"
if [ -z "$pictures" ] || [ "$pictures" = "$HOME" ]; then
    pictures="$HOME/Pictures"
fi
wallpapers="$pictures/Wallpapers"
repo="${XDG_CACHE_HOME:-$HOME/.cache}/serpantinum-wallpapers"

mkdir -p "$wallpapers"
git clone --depth 1 https://github.com/ilyamiro/shell-wallpapers.git "$repo"
find "$repo" -path "$repo/.git" -prune -o -type f \
    \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.gif' -o -iname '*.webp' \) \
    -exec cp -t "$wallpapers" {} +
```

This is the full wallpaper pack. To keep only a few, copy those files out of `$repo` instead of running the last command.

#### 4. Serpantinum settings

This merges the default settings with any settings you already have, keeps your values, and points the shell at your wallpaper folder:

```bash
settings="$cfg/serpantinum/settings.json"
mkdir -p "$cfg/serpantinum"
[ -s "$settings" ] || echo '{}' > "$settings"

jq -s --arg wp "$wallpapers" '(.[0] * .[1]) * {wallpaperDir: $wp}' \
    "$share/config/serpantinum/settings.json" "$settings" > "$settings.tmp" \
    && mv "$settings.tmp" "$settings"

bash "$share/src/scripts/location.sh" --refresh
```

The last command detects your location for the weather widget. Skip it if you prefer to set the location by hand.

#### 5. Services

On systemd, enable the audio stack, networking, and power profiles:

```bash
sudo systemctl --global enable pipewire wireplumber pipewire-pulse
systemctl --user enable --now pipewire wireplumber pipewire-pulse easyeffects
sudo systemctl enable --now NetworkManager power-profiles-daemon
```

On OpenRC, dinit, runit, or s6, enable `NetworkManager` and `power-profiles-daemon` with your init system's tools, and make sure PipeWire and WirePlumber start with your session.

#### 6. Qt icon theme

```bash
for qt in qt5ct qt6ct; do
    mkdir -p "$cfg/$qt"
    [ -f "$cfg/$qt/$qt.conf" ] || printf '[Appearance]\nicon_theme=Adwaita\n' > "$cfg/$qt/$qt.conf"
done

if [ -z "$QT_QPA_PLATFORMTHEME" ] && ! grep -rqs '^QT_QPA_PLATFORMTHEME=' "$cfg/environment.d"; then
    mkdir -p "$cfg/environment.d"
    printf 'QT_QPA_PLATFORMTHEME=qt6ct\n' > "$cfg/environment.d/serpantinum-qt.conf"
fi
```

If you already have a `qt5ct.conf` or `qt6ct.conf`, set `icon_theme=Adwaita` under `[Appearance]` yourself. Log out and back in for the environment variable to apply.

#### 7. SDDM login screen (optional)

The theme files are already installed. Install SDDM and its Qt dependencies, then configure it:

```bash
sudo pacman -S --needed sddm qt6-declarative qt6-svg

[ -f /etc/sddm.conf ] && sudo mv /etc/sddm.conf "/etc/sddm.conf.backup.$(date +%Y%m%d_%H%M%S)"

sudo mkdir -p /etc/sddm.conf.d
sudo tee /etc/sddm.conf.d/10-material-you.conf > /dev/null <<'CONF'
[Theme]
Current=material-you
ThemeDir=/usr/share/sddm/themes

[General]
InputMethod=
CONF
```

`/etc/sddm.conf` overrides the files in `/etc/sddm.conf.d`, so it is moved aside. To run the greeter on Wayland, add these two lines under `[General]`:

```ini
DisplayServer=wayland
GreeterEnvironment=QT_WAYLAND_DISABLE_WINDOWDECORATION=1
```

If another display manager is enabled, disable it before enabling SDDM, for example `sudo systemctl disable gdm`. Then enable SDDM:

```bash
sudo systemctl enable sddm.service
```

#### 8. First launch

Show the welcome guide on the next start:

```bash
rm -f "${XDG_STATE_HOME:-$HOME/.local/state}/serpantinum/first_launch.done"
```

Log in to your compositor. The configs from step 1 start Serpantinum on login. If you kept your own compositor config, add `serpantinumd start` to its autostart.

### Updating and removing

To update, pull the repository and build again. The new package replaces the installed one:

```bash
cd serpantinum
git pull
cd packaging/aur/serpantinum
makepkg -si
```

Removing the package leaves everything in your home directory alone:

```bash
sudo pacman -Rns serpantinum
```

Delete `~/.config/serpantinum`, `~/.local/state/serpantinum`, and `~/.cache/serpantinum` yourself if you also want your settings gone.
