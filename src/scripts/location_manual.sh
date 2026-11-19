#!/usr/bin/env bash

source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/config.sh"

lat="$1"
lon="$2"

if [[ -z "$lat" || -z "$lon" ]]; then
    exit 1
fi

now=$(date +%s)
lang="$(get_setting "general" '{}' | jq -r '.language // "en"' 2>/dev/null)"
[ -z "$lang" ] && lang="en"
[ "$lang" = "ua" ] && lang="uk"
bdc="$(curl -sL --max-time 10 "https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=${lat}&longitude=${lon}&localityLanguage=${lang}")"

city=""
country=""
code=""
region=""
if echo "$bdc" | jq -e '.city or .locality or .principalSubdivision' >/dev/null 2>&1; then
    city="$(echo "$bdc" | jq -r '.city // .locality // .principalSubdivision // ""')"
    country="$(echo "$bdc" | jq -r '.countryName // ""')"
    code="$(echo "$bdc" | jq -r '.countryCode // "" | ascii_upcase')"
    region="$(echo "$bdc" | jq -r '.principalSubdivision // ""')"
fi

# BigDataCloud is unreachable on some networks. Fall back to Nominatim so the
# calendar and weather widgets still have a place name to show.
if [ -z "$city" ]; then
    nom="$(curl -sL --max-time 10 -A "serpantinum/1.0" "https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=${lat}&lon=${lon}&accept-language=${lang}")"
    if echo "$nom" | jq -e '.address' >/dev/null 2>&1; then
        city="$(echo "$nom" | jq -r '.address.city // .address.town // .address.village // .address.municipality // ""')"
        region="$(echo "$nom" | jq -r '.address.state // .address.county // ""')"
        country="$(echo "$nom" | jq -r '.address.country // ""')"
        code="$(echo "$nom" | jq -r '.address.country_code // "" | ascii_upcase')"
    fi
fi

tz_req="$(curl -s --max-time 10 "https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}&timezone=auto")"
tz="$(echo "$tz_req" | jq -r '.timezone // empty' 2>/dev/null)"
if [ -z "$tz" ]; then
    # Same reachability workaround as weather.sh.
    tz_req="$(curl -s --max-time 10 --connect-to api.open-meteo.com:443:open-meteo.com:443 "https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}&timezone=auto")"
    tz="$(echo "$tz_req" | jq -r '.timezone // empty' 2>/dev/null)"
fi
if [ -z "$tz" ]; then
    existing_tz="$(get_setting "general" '{}' | jq -r '.location.timezone // empty' 2>/dev/null)"
    tz="${existing_tz:-UTC}"
fi

json="$(jq -n \
    --arg lat "$lat" \
    --arg lon "$lon" \
    --arg city "$city" \
    --arg region "$region" \
    --arg country "$country" \
    --arg code "$code" \
    --arg tz "$tz" \
    --argjson ts "$now" \
    '{
        latitude: ($lat|tonumber),
        longitude: ($lon|tonumber),
        city: $city,
        region: $region,
        country_name: $country,
        country_code: $code,
        timezone: $tz,
        source: "manual",
        updated_at: $ts
    }')"

gen="$(get_setting "general" '{}')"
updated="$(echo "$gen" | jq --argjson loc "$json" '.location = $loc')"
set_setting "general" "$updated"
"$(dirname "$(realpath "${BASH_SOURCE[0]}")")/weather.sh" --getdata >/dev/null 2>&1 &
