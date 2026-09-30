#!/usr/bin/env bash

source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/caching.sh" 2>/dev/null || true
source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/config.sh" 2>/dev/null || true

I18N_DIR="${I18N_DIR:-"${SERPANTINUM_DIR:-"$(dirname "$(dirname "$(realpath "${BASH_SOURCE[0]}")")")"}/assets/languages"}"

detect_system_language() {
    local locale="${LC_ALL:-${LC_MESSAGES:-${LANG:-}}}"
    local lang="${locale%%[_.@]*}"
    lang="${lang,,}"

    # Ukrainian ships as ua.json, not the ISO 639-1 "uk"
    [[ "$lang" == "uk" ]] && lang="ua"

    if [[ -n "$lang" && -f "${I18N_DIR}/${lang}.json" ]]; then
        printf '%s' "$lang"
    else
        printf 'en'
    fi
}

get_current_language() {
    local lang=""
    if command -v get_setting &>/dev/null; then
        lang="$(get_setting "general" '{}' | jq -r '.language // empty' 2>/dev/null)"
    fi

    if [[ -z "$lang" || "$lang" == "null" ]]; then
        detect_system_language
    else
        printf '%s' "$lang"
    fi
}

t() {
    local manual_lang=""
    local key=""
    local -a args=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -l|--lang)
                manual_lang="$2"
                shift 2
                ;;
            --lang=*)
                manual_lang="${1#*=}"
                shift
                ;;
            -l=*)
                manual_lang="${1#*=}"
                shift
                ;;
            *)
                if [[ -z "$key" ]]; then
                    key="$1"
                else
                    args+=("$1")
                fi
                shift
                ;;
        esac
    done

    if [[ -z "$key" ]]; then
        return
    fi

    local lang=""
    if [[ -n "$manual_lang" && -f "${I18N_DIR}/${manual_lang}.json" ]]; then
        lang="$manual_lang"
    else
        lang="$(get_current_language)"
    fi

    local translated=""
    local i18n_file="${I18N_DIR}/${lang}.json"

    if [[ -f "$i18n_file" ]]; then
        translated="$(jq -r --arg k "$key" '
            ($k | split(".")) as $path |
            getpath($path) | strings
        ' "$i18n_file" 2>/dev/null)"
    fi

    if [[ -z "$translated" && "$lang" != "en" && -f "${I18N_DIR}/en.json" ]]; then
        translated="$(jq -r --arg k "$key" '
            ($k | split(".")) as $path |
            getpath($path) | strings
        ' "${I18N_DIR}/en.json" 2>/dev/null)"
    fi

    if [[ -z "$translated" ]]; then
        printf '%s' "$key"
        return
    fi

    local arg k v
    for arg in "${args[@]}"; do
        k="${arg%%=*}"
        v="${arg#*=}"
        translated="${translated//\{$k\}/$v}"
    done

    printf '%s' "$translated"
}
