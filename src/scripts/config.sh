#!/usr/bin/env bash

declare -F qs_ensure_cache >/dev/null || source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/caching.sh"

CONFIG_SETTINGS_JSON="${QS_SETTINGS:-$HOME/.config/serpantinum/settings.json}"

_config_ensure_settings() {
    local dir
    dir="$(dirname "$CONFIG_SETTINGS_JSON")"
    [[ -d "$dir" ]] || mkdir -p "$dir"
    [[ -s "$CONFIG_SETTINGS_JSON" ]] || echo '{}' > "$CONFIG_SETTINGS_JSON"
}

get_setting() {
    local key="$1"
    local fallback="${2:-}"
    _config_ensure_settings
    local val
    val="$(jq -r --arg k "$key" 'if has($k) then .[$k] else "__MISSING__" end' "$CONFIG_SETTINGS_JSON" 2>/dev/null)"
    if [[ "$val" == "__MISSING__" || "$val" == "null" ]]; then
        printf '%s' "$fallback"
    else
        printf '%s' "$val"
    fi
}

set_setting() {
    local key="$1"
    local value="$2"
    _config_ensure_settings

    local json_value
    if echo "$value" | jq -e . > /dev/null 2>&1; then
        json_value="$value"
    else
        json_value="$(jq -Rn --arg v "$value" '$v')"
    fi

    local tmp="${CONFIG_SETTINGS_JSON}.tmp"
    if jq --arg k "$key" --argjson v "$json_value" '. + {($k): $v}' "$CONFIG_SETTINGS_JSON" > "$tmp" 2>/dev/null; then
        if jq -e . "$tmp" > /dev/null 2>&1; then
            mv "$tmp" "$CONFIG_SETTINGS_JSON"
        fi
    fi
}

update_settings_bulk() {
    local json_obj="$1"
    _config_ensure_settings
    local tmp="${CONFIG_SETTINGS_JSON}.tmp"
    if jq --argjson patch "$json_obj" '. + $patch' "$CONFIG_SETTINGS_JSON" > "$tmp" 2>/dev/null; then
        if jq -e . "$tmp" > /dev/null 2>&1; then
            mv "$tmp" "$CONFIG_SETTINGS_JSON"
        fi
    fi
}
