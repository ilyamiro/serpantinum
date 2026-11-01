#!/usr/bin/env bash

SKI_REPO="ilyamiro/Ski"
SKI_PREFIX="/usr/local"

ski_release_json() {
    curl -fsSL --connect-timeout 15 --retry 3 "https://api.github.com/repos/$SKI_REPO/releases/latest"
}

ski_version_stamp() {
    echo "${XDG_STATE_HOME:-$HOME/.local/state}/serpantinum/ski-version"
}

ski_installed_version() {
    command -v ski >/dev/null 2>&1 || return 0
    cat "$(ski_version_stamp)" 2>/dev/null || true
}

ski_stage_install() {
    local stage="$1" prefix="$2" name

    sudo install -Dm755 "$stage/usr/bin/ski" "$prefix/bin/ski" || return 1
    sudo install -Dm644 "$stage/usr/share/applications/ski.desktop" "$prefix/share/applications/ski.desktop" || return 1
    sudo install -Dm644 "$stage/usr/share/icons/hicolor/scalable/apps/ski.svg" "$prefix/share/icons/hicolor/scalable/apps/ski.svg" || return 1
    sudo install -Dm644 "$stage/usr/share/xdg-desktop-portal/portals/ski.portal" "$prefix/share/xdg-desktop-portal/portals/ski.portal" || return 1
    sudo install -d "$prefix/share/dbus-1/services" || return 1
    for name in org.freedesktop.impl.portal.desktop.ski org.freedesktop.FileManager1; do
        sed "s|/usr/bin/ski|$prefix/bin/ski|" "$stage/usr/share/dbus-1/services/$name.service" \
            | sudo tee "$prefix/share/dbus-1/services/$name.service" >/dev/null || return 1
    done
    sudo install -Dm644 "$stage/usr/share/licenses/ski/LICENSE" "$prefix/share/licenses/ski/LICENSE" || return 1
}

install_ski() {
    local current
    current="$(ski_installed_version)"

    echo -e "\n\e[36m[ INFO ]\e[0m $(t "installer.ski.installing")"

    local json tag tarball_url sums_url
    if ! json="$(ski_release_json)" || [ -z "$json" ]; then
        echo -e "\e[33m[ WARN ]\e[0m $(t "installer.ski.download_failed")"
        return 0
    fi
    tag="$(jq -r '.tag_name // empty' <<< "$json")"
    tarball_url="$(jq -r '[.assets[] | select(.name | test("x86_64-linux\\.tar\\.gz$"))][0].browser_download_url // empty' <<< "$json")"
    sums_url="$(jq -r '[.assets[] | select(.name == "SHA256SUMS")][0].browser_download_url // empty' <<< "$json")"

    if [ -z "$tag" ] || [ -z "$tarball_url" ]; then
        echo -e "\e[33m[ WARN ]\e[0m $(t "installer.ski.download_failed")"
        return 0
    fi

    if [ -n "$current" ] && [ "${tag#v}" = "$current" ]; then
        echo -e "\e[32m  $(t "installer.ski.up_to_date" "version=$current")\e[0m"
        return 0
    fi

    if [ "$(uname -m)" != "x86_64" ]; then
        echo -e "\e[33m[ WARN ]\e[0m $(t "installer.ski.unsupported_arch")"
        return 0
    fi

    local cache="${XDG_CACHE_HOME:-$HOME/.cache}" work
    mkdir -p "$cache"
    work="$(mktemp -d "$cache/serpantinum-ski.XXXXXX")"
    local archive="$work/${tarball_url##*/}"

    if ! curl -fL# --connect-timeout 15 --retry 3 "$tarball_url" -o "$archive"; then
        echo -e "\e[33m[ WARN ]\e[0m $(t "installer.ski.download_failed")"
        rm -rf "$work"
        return 0
    fi

    if [ -n "$sums_url" ] && curl -fsSL --connect-timeout 15 --retry 3 "$sums_url" -o "$work/SHA256SUMS"; then
        if ! (cd "$work" && grep -F " ${archive##*/}" SHA256SUMS | sha256sum -c --quiet -); then
            echo -e "\e[31m[ FAILED ]\e[0m $(t "installer.ski.checksum_failed")"
            rm -rf "$work"
            return 0
        fi
    fi

    mkdir -p "$work/stage"
    if ! tar -xzf "$archive" -C "$work/stage"; then
        echo -e "\e[33m[ WARN ]\e[0m $(t "installer.ski.download_failed")"
        rm -rf "$work"
        return 0
    fi

    if ski_stage_install "$work/stage" "$SKI_PREFIX"; then
        mkdir -p "$(dirname "$(ski_version_stamp)")"
        printf '%s\n' "${tag#v}" > "$(ski_version_stamp)"
        echo -e "\e[32m[ OK ] $(t "installer.ski.installed" "version=${tag#v}")\e[0m"
    else
        echo -e "\e[31m[ FAILED ] $(t "installer.ski.install_failed")\e[0m"
        FAILED_PKGS+=("ski")
    fi
    rm -rf "$work"

    command -v update-desktop-database >/dev/null 2>&1 && sudo update-desktop-database "$SKI_PREFIX/share/applications" >/dev/null 2>&1 || true
    command -v gtk-update-icon-cache >/dev/null 2>&1 && sudo gtk-update-icon-cache -qf "$SKI_PREFIX/share/icons/hicolor" >/dev/null 2>&1 || true
}

ski_set_portal_preference() {
    local conf_dir="${XDG_CONFIG_HOME:-$HOME/.config}/xdg-desktop-portal"
    local conf="$conf_dir/portals.conf"
    local key="org.freedesktop.impl.portal.FileChooser"

    mkdir -p "$conf_dir"
    if [ ! -f "$conf" ]; then
        printf '[preferred]\n%s=ski\n' "$key" > "$conf"
    elif grep -q "^$key=" "$conf"; then
        sed -i "s|^$key=.*|$key=ski|" "$conf"
    elif grep -q '^\[preferred\]' "$conf"; then
        sed -i "/^\[preferred\]/a $key=ski" "$conf"
    else
        printf '\n[preferred]\n%s=ski\n' "$key" >> "$conf"
    fi
}

ski_set_dock_entry() {
    local settings="${XDG_CONFIG_HOME:-$HOME/.config}/serpantinum/settings.json"
    [ -s "$settings" ] || return 0
    command -v jq >/dev/null 2>&1 || return 0

    local updated
    updated="$(jq '
        if (.dock.apps // null) == null then .
        else .dock.apps |= map(
            if ((.desktop_id // "") | test("^org\\.gnome\\.Nautilus(\\.desktop)?$"))
            then .desktop_id = "ski" | .icon = "ski"
            else . end)
        end' "$settings" 2>/dev/null)"
    [ -n "$updated" ] && printf '%s\n' "$updated" > "$settings"
}

configure_ski_defaults() {
    command -v ski >/dev/null 2>&1 || return 0

    if command -v xdg-mime >/dev/null 2>&1; then
        xdg-mime default ski.desktop inode/directory 2>/dev/null || true
    fi

    ski_set_portal_preference

    local env_dir="${XDG_CONFIG_HOME:-$HOME/.config}/environment.d"
    mkdir -p "$env_dir"
    printf 'GTK_USE_PORTAL=1\n' > "$env_dir/serpantinum-portal.conf"

    ski_set_dock_entry
}
