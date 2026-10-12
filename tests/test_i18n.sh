#!/usr/bin/env bash

setup() {
    export HOME="$TEST_TMP/home"
    mkdir -p "$HOME"
    export I18N_DIR="$PROJECT_ROOT/src/assets/languages"
    unset LC_ALL LC_MESSAGES
    source "$PROJECT_ROOT/src/scripts/i18n.sh"
    # No settings file in the test home: language comes from the locale.
    unset -f get_setting
}

test_detects_language_from_locale() {
    assert_eq "ru" "$(LANG=ru_RU.UTF-8 detect_system_language)"
    assert_eq "de" "$(LANG=de_DE.UTF-8 detect_system_language)"
}

test_ukrainian_maps_to_ua() {
    assert_eq "ua" "$(LANG=uk_UA.UTF-8 detect_system_language)"
}

test_traditional_chinese_locales() {
    assert_eq "zh_tw" "$(LANG=zh_TW.UTF-8 detect_system_language)"
    assert_eq "zh_tw" "$(LANG=zh_HK.UTF-8 detect_system_language)"
    assert_eq "zh" "$(LANG=zh_CN.UTF-8 detect_system_language)"
}

test_unknown_locale_falls_back_to_english() {
    assert_eq "en" "$(LANG=xx_XX.UTF-8 detect_system_language)"
    assert_eq "en" "$(LANG=C detect_system_language)"
    assert_eq "en" "$(LANG= detect_system_language)"
}

test_lc_all_overrides_lang() {
    # bash warns when the locale is not generated on the machine; irrelevant here.
    assert_eq "fr" "$(LANG=de_DE.UTF-8 LC_ALL=fr_FR.UTF-8 detect_system_language 2>/dev/null)"
}

test_translates_with_placeholders() {
    assert_eq "Installing kitty..." "$(t --lang en "installer.deps.installing_pkg" "pkg=kitty")"
}

test_missing_key_falls_back_to_english() {
    local tmp_dir="$TEST_TMP/languages"
    mkdir -p "$tmp_dir"
    cp "$I18N_DIR/en.json" "$tmp_dir/en.json"
    echo '{"installer": {}}' > "$tmp_dir/xx.json"
    I18N_DIR="$tmp_dir"
    assert_eq "Exit" "$(t --lang xx "installer.ui.menu_exit")"
}

test_unknown_key_returns_key() {
    assert_eq "installer.nope.missing" "$(t --lang en "installer.nope.missing")"
}

test_all_language_files_are_valid_json() {
    local file
    for file in "$I18N_DIR"/*.json; do
        jq empty "$file" 2>/dev/null || fail "invalid JSON: $(basename "$file")"
    done
}

test_installer_keys_exist_in_english() {
    local key missing=()
    while IFS= read -r key; do
        [[ -z "$key" ]] && continue
        [[ "$(t --lang en "$key")" == "$key" ]] && missing+=("$key")
    done <<< "$(grep -rhoE 't "installer\.[a-z_.]+"' "$PROJECT_ROOT/install" | sed -E 's/^t "(.*)"$/\1/' | sort -u)"
    [[ ${#missing[@]} -eq 0 ]] || fail "keys missing from en.json: ${missing[*]}"
}
