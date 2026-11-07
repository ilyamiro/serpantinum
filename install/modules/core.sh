#!/usr/bin/env bash

CORE_REPO="ilyamiro/serpantinum-core"
CORE_PREFIX="/usr/local"

core_release_json() {
    curl -fsSL --connect-timeout 15 --retry 3 "https://api.github.com/repos/$CORE_REPO/releases/latest"
}

core_installed_version() {
    command -v serpantinum-core >/dev/null 2>&1 || return 0
    serpantinum-core --version 2>/dev/null | awk '{print $2}'
}

core_install_prebuilt() {
    local json="$1" work="$2" tarball_url sums_url archive

    tarball_url="$(jq -r '[.assets[] | select(.name | test("-x86_64-linux\\.tar\\.gz$"))][0].browser_download_url // empty' <<< "$json")"
    sums_url="$(jq -r '[.assets[] | select(.name == "SHA256SUMS")][0].browser_download_url // empty' <<< "$json")"
    [ -n "$tarball_url" ] && [ -n "$sums_url" ] || return 1

    archive="$work/${tarball_url##*/}"
    curl -fsSL --connect-timeout 15 --retry 3 "$tarball_url" -o "$archive" || return 1
    curl -fsSL --connect-timeout 15 --retry 3 "$sums_url" -o "$work/SHA256SUMS" || return 1
    if ! (cd "$work" && grep -F " ${archive##*/}" SHA256SUMS | sha256sum -c --quiet -); then
        echo -e "\e[31m[ FAILED ]\e[0m $(t "installer.core.checksum_failed")"
        return 1
    fi

    mkdir -p "$work/stage"
    tar -xzf "$archive" -C "$work/stage" || return 1
    "$work/stage/usr/bin/serpantinum-core" --version >/dev/null 2>&1 || return 1

    sudo install -Dm755 "$work/stage/usr/bin/serpantinum-core" "$CORE_PREFIX/bin/serpantinum-core" || return 1
    if [ -f "$work/stage/usr/share/licenses/serpantinum-core/LICENSE" ]; then
        sudo install -Dm644 "$work/stage/usr/share/licenses/serpantinum-core/LICENSE" "$CORE_PREFIX/share/licenses/serpantinum-core/LICENSE" || return 1
    fi
}

install_core_daemon() {
    local current json tag work

    echo -e "\n\e[36m[ INFO ]\e[0m $(t "installer.core.installing")"
    current="$(core_installed_version)"

    if [ "$(uname -m)" != "x86_64" ]; then
        echo -e "\e[33m[ WARN ]\e[0m $(t "installer.core.unsupported_arch")"
        [ -n "$current" ] || FAILED_PKGS+=("serpantinum-core")
        return 0
    fi

    if ! json="$(core_release_json)" || [ -z "$json" ]; then
        echo -e "\e[33m[ WARN ]\e[0m $(t "installer.core.download_failed")"
        [ -n "$current" ] || FAILED_PKGS+=("serpantinum-core")
        return 0
    fi
    tag="$(jq -r '.tag_name // empty' <<< "$json")"
    if [ -z "$tag" ]; then
        echo -e "\e[33m[ WARN ]\e[0m $(t "installer.core.download_failed")"
        [ -n "$current" ] || FAILED_PKGS+=("serpantinum-core")
        return 0
    fi

    if [ -n "$current" ] && [ "${tag#v}" = "$current" ]; then
        echo -e "\e[32m  $(t "installer.core.up_to_date" "version=$current")\e[0m"
        return 0
    fi

    local cache="${XDG_CACHE_HOME:-$HOME/.cache}"
    mkdir -p "$cache"
    work="$(mktemp -d "$cache/serpantinum-core.XXXXXX")"

    if core_install_prebuilt "$json" "$work"; then
        hash -r
        echo -e "\e[32m[ OK ] $(t "installer.core.installed" "version=${tag#v}")\e[0m"
        restart_daemon_if_running serpantinum-core '(^|/)serpantinum-core$' quit
    else
        echo -e "\e[31m[ FAILED ] $(t "installer.core.install_failed")\e[0m"
        FAILED_PKGS+=("serpantinum-core")
    fi
    rm -rf "$work"
}
