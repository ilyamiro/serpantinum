#!/usr/bin/env bash

AUDIO_REPO="ilyamiro/serpantinum-audio"
AUDIO_PREFIX="/usr/local"

audio_release_json() {
    curl -fsSL --connect-timeout 15 --retry 3 "https://api.github.com/repos/$AUDIO_REPO/releases/latest"
}

audio_installed_version() {
    command -v serpantinum-audio >/dev/null 2>&1 || return 0
    serpantinum-audio version 2>/dev/null | awk '{print $2}'
}

audio_arch() {
    case "$(uname -m)" in
        x86_64|amd64) echo "x86_64" ;;
        aarch64|arm64) echo "aarch64" ;;
        *) return 1 ;;
    esac
}

audio_install_prebuilt() {
    local json="$1" work="$2" arch tarball_url sums_url archive

    arch="$(audio_arch)" || return 1
    tarball_url="$(jq -r --arg re "-${arch}-linux\\.tar\\.gz$" '[.assets[] | select(.name | test($re))][0].browser_download_url // empty' <<< "$json")"
    sums_url="$(jq -r '[.assets[] | select(.name == "SHA256SUMS")][0].browser_download_url // empty' <<< "$json")"
    [ -n "$tarball_url" ] && [ -n "$sums_url" ] || return 1

    archive="$work/${tarball_url##*/}"
    curl -fsSL --connect-timeout 15 --retry 3 "$tarball_url" -o "$archive" || return 1
    curl -fsSL --connect-timeout 15 --retry 3 "$sums_url" -o "$work/SHA256SUMS" || return 1
    if ! (cd "$work" && grep -F " ${archive##*/}" SHA256SUMS | sha256sum -c --quiet -); then
        echo -e "\e[31m[ FAILED ]\e[0m $(t "installer.audio.checksum_failed")"
        return 1
    fi

    mkdir -p "$work/stage"
    tar -xzf "$archive" -C "$work/stage" || return 1
    "$work/stage/usr/bin/serpantinum-audio" version >/dev/null 2>&1 || return 1

    sudo install -Dm755 "$work/stage/usr/bin/serpantinum-audio" "$AUDIO_PREFIX/bin/serpantinum-audio" || return 1
    if [ -f "$work/stage/usr/share/licenses/serpantinum-audio/LICENSE" ]; then
        sudo install -Dm644 "$work/stage/usr/share/licenses/serpantinum-audio/LICENSE" "$AUDIO_PREFIX/share/licenses/serpantinum-audio/LICENSE" || return 1
    fi
}

audio_build_tools() {
    [ ${#PM_AUDIO_BUILD_PKGS[@]} -gt 0 ] || return 0
    local missing=() pkg
    mapfile -t missing < <(pm_missing_pkgs "${PM_AUDIO_BUILD_PKGS[@]}")
    for pkg in "${missing[@]}"; do
        [ -n "$pkg" ] || continue
        pm_install_pkg "$pkg" 1 || return 1
    done
}

audio_build_from_source() {
    local json="$1" work="$2" src_url src_dir

    src_url="$(jq -r '.tarball_url // empty' <<< "$json")"
    [ -n "$src_url" ] || return 1

    echo -e "\e[36m[ INFO ]\e[0m $(t "installer.audio.building")"
    audio_build_tools || return 1

    curl -fsSL --connect-timeout 15 --retry 3 "$src_url" -o "$work/source.tar.gz" || return 1
    mkdir -p "$work/source"
    tar -xzf "$work/source.tar.gz" -C "$work/source" --strip-components=1 || return 1
    src_dir="$work/source"

    make -C "$src_dir" >/dev/null || return 1
    "$src_dir/serpantinum-audio" version >/dev/null 2>&1 || return 1
    sudo make -C "$src_dir" install PREFIX="$AUDIO_PREFIX" >/dev/null
}

audio_restart_if_running() {
    command -v serpantinum-audio >/dev/null 2>&1 || return 0
    serpantinum-audio ctl ping >/dev/null 2>&1 || return 0
    serpantinum-audio ctl quit >/dev/null 2>&1 || true
    sleep 0.5
    serpantinum-audio start >/dev/null 2>&1 || true
}

hand_over_from_easyeffects() {
    command -v serpantinum-audio >/dev/null 2>&1 || return 0
    bash "$SERPANTINUM_DIR/scripts/migrate_easyeffects.sh" 2>/dev/null || true
    serpantinum-audio start >/dev/null 2>&1 || true
}

install_audio_daemon() {
    local current json tag work

    echo -e "\n\e[36m[ INFO ]\e[0m $(t "installer.audio.installing")"
    current="$(audio_installed_version)"

    if ! json="$(audio_release_json)" || [ -z "$json" ]; then
        echo -e "\e[33m[ WARN ]\e[0m $(t "installer.audio.download_failed")"
        [ -n "$current" ] || FAILED_PKGS+=("serpantinum-audio")
        return 0
    fi
    tag="$(jq -r '.tag_name // empty' <<< "$json")"
    if [ -z "$tag" ]; then
        echo -e "\e[33m[ WARN ]\e[0m $(t "installer.audio.download_failed")"
        [ -n "$current" ] || FAILED_PKGS+=("serpantinum-audio")
        return 0
    fi

    if [ -n "$current" ] && [ "${tag#v}" = "$current" ]; then
        echo -e "\e[32m  $(t "installer.audio.up_to_date" "version=$current")\e[0m"
        return 0
    fi

    local cache="${XDG_CACHE_HOME:-$HOME/.cache}"
    mkdir -p "$cache"
    work="$(mktemp -d "$cache/serpantinum-audio.XXXXXX")"

    if audio_install_prebuilt "$json" "$work" || audio_build_from_source "$json" "$work"; then
        hash -r
        echo -e "\e[32m[ OK ] $(t "installer.audio.installed" "version=${tag#v}")\e[0m"
        audio_restart_if_running
    else
        echo -e "\e[31m[ FAILED ] $(t "installer.audio.install_failed")\e[0m"
        FAILED_PKGS+=("serpantinum-audio")
    fi
    rm -rf "$work"
}
