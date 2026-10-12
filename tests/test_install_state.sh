#!/usr/bin/env bash

setup() {
    export HOME="$TEST_TMP/home"
    mkdir -p "$HOME"
    source "$PROJECT_ROOT/install/modules/state.sh"
}

test_fresh_when_nothing_installed() {
    assert_eq "fresh" "$(detect_install_state)"
}

test_current_when_version_marker_exists() {
    mkdir -p "$HOME/.local/state/serpantinum"
    touch "$HOME/.local/state/serpantinum/version"
    assert_eq "current" "$(detect_install_state)"
}

test_legacy_markers() {
    local marker
    for marker in \
        ".local/state/imperative-dots-version" \
        ".config/hypr/scripts/settings_watcher.sh" \
        ".config/hypr/settings.json"; do
        rm -rf "$HOME" && mkdir -p "$HOME/$(dirname "$marker")"
        touch "$HOME/$marker"
        assert_eq "legacy" "$(detect_install_state)" "$marker"
    done
}

test_current_wins_over_legacy() {
    mkdir -p "$HOME/.local/state/serpantinum"
    touch "$HOME/.local/state/serpantinum/version" "$HOME/.local/state/imperative-dots-version"
    assert_eq "current" "$(detect_install_state)"
}
