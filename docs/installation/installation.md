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

Serpantinum installs through an automated script on Arch Linux, Fedora, Void Linux, and their derivatives. The script detects your distribution and uses the matching package manager (`pacman`, `dnf`, or `xbps`). On NixOS, use the [flake and modules](/installation/nixos) instead.

Use this installer:

```bash
curl -fsSL install.serpantinum.dev | bash
```

If this doesn't work, use:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/ilyamiro/serpantinum/master/install/install.sh)"
```

:::info[NOTE]
To update, run the installer script again and choose **Update**.
:::

When SDDM is selected, the installer sets up the Serpantinum login screen and enables appearance sync for the account running the installer. An update migrates the installer-managed Material You selection to Serpantinum and preserves a custom SDDM theme selected in local configuration. The updated theme loads the next time SDDM starts.

## Fedora

Fedora and its derivatives, such as **Nobara** and **Ultramarine**, are installed with `dnf`. Fedora does not package `gpu-screen-recorder`, so screen recording is unavailable there. SDDM is set up with its Wayland greeter, since Fedora ships no Xorg server.

## Void Linux

Void Linux, both glibc and musl, is installed with `xbps`. Everything comes from the official repositories except:

- **Hyprland**, which Void does not package. When you select it, the installer adds the third-party [black-hole.dev](https://mirror.black-hole.dev) repository in `/etc/xbps.d/20-serpantinum-hyprland.conf` and accepts its signing key. Niri, Sway, and Mango come from the official repositories.
- **adw-gtk3** and **JetBrains Mono**, which are downloaded from their latest GitHub releases into `/usr/share/themes` and `/usr/share/fonts`.

Services are enabled through runit. `dbus`, `bluetoothd`, and `power-profiles-daemon` start right away. `NetworkManager` and `sddm` start from the next boot, so the installer does not cut your network or take over the screen while it runs. If `dhcpcd` or `wpa_supplicant` were enabled, they are kept from starting at the next boot, since they conflict with NetworkManager. Wi-Fi networks must then be connected again through Serpantinum or `nmcli`. Display managers being replaced keep running until you reboot.

PipeWire is configured system-wide to launch WirePlumber and `pipewire-pulse`, with ALSA routed through it. Sessions started from SDDM get a D-Bus session bus and PipeWire automatically. If you start your compositor from a TTY instead, launch it with `dbus-run-session` and start `pipewire` from its autostart.

## Arch Linux and derivatives

Arch Linux and its derivatives (EndeavourOS, Manjaro, CachyOS, Garuda, Artix and others) are supported on systemd, OpenRC and other init systems.

## Build from source on Arch

Arch-based distributions can build Serpantinum as a native package from this repository instead of running the installer script. The package installs the shell system-wide and pulls in every runtime dependency the installer would. The parts of the installer that change your home directory, services, or login screen are not done by a package, so you run them yourself afterwards.

The repository contains two PKGBUILDs in `packaging/aur`, and they conflict with each other:

| Package | Builds |
| --- | --- |
| `serpantinum` | The latest tagged release |
| `serpantinum-git` | The latest commit on `master` |

Install the build tools:

```bash
sudo pacman -S --needed base-devel git
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
| Install [serpantinum-audio](/audio) | Done, `serpantinum-audio` in `/usr/bin` |
| Install [serpantinum-gamma](/gamma) | Done, `serpantinum-gamma` in `/usr/bin` |
| Install [serpantinum-core](/core) | Done, `serpantinum-core` in `/usr/bin` |
| Lock screen PAM service | Done, `/etc/pam.d/serpantinum` |
| SDDM theme files | Done, in `/usr/share/sddm/themes/serpantinum` for packages with the new greeter |
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
systemctl --user enable --now pipewire wireplumber pipewire-pulse
sudo systemctl enable --now NetworkManager power-profiles-daemon
```

On OpenRC, dinit, runit, or s6, enable `NetworkManager` and `power-profiles-daemon` with your init system's tools, and make sure PipeWire and WirePlumber start with your session.

#### 6. Qt icon theme

```bash
for qt in qt6ct; do
    mkdir -p "$cfg/$qt"
    [ -f "$cfg/$qt/$qt.conf" ] || printf '[Appearance]\nicon_theme=Adwaita\n' > "$cfg/$qt/$qt.conf"
done

if [ -z "$QT_QPA_PLATFORMTHEME" ] && ! grep -rqs '^QT_QPA_PLATFORMTHEME=' "$cfg/environment.d"; then
    mkdir -p "$cfg/environment.d"
    printf 'QT_QPA_PLATFORMTHEME=qt6ct\n' > "$cfg/environment.d/serpantinum-qt.conf"
fi
```

If you already have a `qt6ct.conf`, set `icon_theme=Adwaita` under `[Appearance]` yourself. Log out and back in for the environment variable to apply.

#### 7. SDDM login screen (optional)

The package ships the Serpantinum theme. Tagged releases before the new greeter ship the Material You theme, which the same setup below detects. Install the Qt 6 greeter dependencies and select the theme:

```bash
sudo pacman -S --needed sddm qt6-declarative qt6-svg qt6-multimedia

theme=serpantinum
[ -d /usr/share/sddm/themes/serpantinum ] || theme=material-you

sudo mkdir -p /etc/sddm.conf.d
sudo tee /etc/sddm.conf.d/20-serpantinum.conf > /dev/null <<CONF
[Theme]
Current=$theme
ThemeDir=/usr/share/sddm/themes

[General]
InputMethod=
GreeterEnvironment=QML_XHR_ALLOW_FILE_READ=1
CONF
```

`/etc/sddm.conf` takes precedence over drop-ins. If it already sets `[Theme] Current` or `[General] GreeterEnvironment`, update those settings there as well. Preserve any other variables in your comma-separated `GreeterEnvironment`. To run the greeter on Wayland with KWin installed, use:

```ini
[General]
DisplayServer=wayland
GreeterEnvironment=QML_XHR_ALLOW_FILE_READ=1,QT_WAYLAND_DISABLE_WINDOWDECORATION=1

[Wayland]
CompositorCommand=kwin_wayland --no-global-shortcuts --no-lockscreen --locale1
```

For packages with the Serpantinum theme, run the following as the desktop user to export appearance settings before logging out:

```bash
profile=$(id -u)
state_dir=/var/lib/serpantinum-greeter/profiles/$profile
sudo install -d -m 0755 -o root -g root /var/lib/serpantinum-greeter/profiles
sudo install -d -m 0755 -o "$profile" -g "$(id -g)" "$state_dir"
SERP_GREETER_STATE="$state_dir" python -I /usr/lib/serpantinum/greeter-sync.py
```

Set `profile` under `[General]` in `/usr/share/sddm/themes/serpantinum/theme.conf.user` to the number printed by `id -u`. SDDM reads this account’s exported palette, wallpaper, lock-screen layout, and other appearance settings while it runs as its own user.

On systemd, enable a user timer to refresh the export automatically:

```bash
cfg="${XDG_CONFIG_HOME:-$HOME/.config}"
mkdir -p "$cfg/systemd/user"
cat > "$cfg/systemd/user/serpantinum-greeter-sync.service" <<EOF
[Unit]
Description=Export Serpantinum appearance for SDDM

[Service]
Type=oneshot
Environment=SERP_GREETER_STATE=$state_dir
ExecStart=/usr/bin/python -I /usr/lib/serpantinum/greeter-sync.py
EOF

cat > "$cfg/systemd/user/serpantinum-greeter-sync.timer" <<'EOF'
[Unit]
Description=Refresh Serpantinum login screen appearance

[Timer]
OnStartupSec=2s
OnUnitInactiveSec=5s

[Install]
WantedBy=timers.target
EOF

systemctl --user daemon-reload
systemctl --user enable --now serpantinum-greeter-sync.timer
```

On other init systems, schedule the same export command in the desktop session to refresh the snapshot. The last export remains available before the next login.

For live hardware readings at the login screen on systemd, create the collector’s system service and timer:

```bash
sudo tee /etc/systemd/system/serpantinum-greeter-metrics.service > /dev/null <<'EOF'
[Unit]
Description=Collect hardware readings for the Serpantinum login screen

[Service]
Type=oneshot
User=sddm
Group=sddm
RuntimeDirectory=serpantinum-greeter-system
RuntimeDirectoryPreserve=yes
NoNewPrivileges=yes
ProtectHome=yes
ProtectSystem=strict
ExecStart=/usr/bin/python -I /usr/lib/serpantinum/greeter-metrics.py
EOF

sudo tee /etc/systemd/system/serpantinum-greeter-metrics.timer > /dev/null <<'EOF'
[Unit]
Description=Refresh Serpantinum login screen hardware readings

[Timer]
OnBootSec=3s
OnUnitInactiveSec=15s

[Install]
WantedBy=timers.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now serpantinum-greeter-metrics.timer
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

Package upgrades keep an existing Material You selection working. To switch to Serpantinum and configure appearance sync, repeat [the SDDM setup](#7-sddm-login-screen-optional).

Removing the package leaves everything in your home directory alone:

```bash
sudo pacman -Rns serpantinum
```

Delete `~/.config/serpantinum`, `~/.local/state/serpantinum`, and `~/.cache/serpantinum` yourself if you also want your settings gone.
