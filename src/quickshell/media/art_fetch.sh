#!/usr/bin/env bash

source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/caching.sh"
qs_ensure_cache "music"

TMP_DIR="$QS_RUN_MUSIC/covers"
DEVICE_CACHE="$QS_RUN_MUSIC/device_cache.json"

mkdir -p "$TMP_DIR"

PLAYER_ID="$1"
RAW_URL="$2"
TITLE="$3"
ARTIST="$4"

CLEAN_URL="$RAW_URL"
if [[ "$RAW_URL" == file://* ]]; then
    CLEAN_URL="${RAW_URL#file://}"
    CLEAN_URL="$(printf '%b' "${CLEAN_URL//%/\\x}")"
fi

if [[ "$RAW_URL" == http* ]]; then
    HASH_KEY="$CLEAN_URL"
    if [[ "$HASH_KEY" =~ (googleusercontent\.com|ggpht\.com) ]]; then
        HASH_KEY="${HASH_KEY%%\=*}"
    elif [[ "$HASH_KEY" =~ (vi|vi_webp)/([^/?&#]+) ]]; then
        HASH_KEY="yt_${BASH_REMATCH[2]}"
    elif [[ "$HASH_KEY" =~ ab67([0-9a-f]{4})0000[0-9a-f]{4}([0-9a-f]+) ]]; then
        HASH_KEY="sp_${BASH_REMATCH[2]}"
    else
        HASH_KEY="${TITLE}_${ARTIST}_${CLEAN_URL}"
    fi
    trackHash=$(echo -n "${HASH_KEY}" | md5sum | cut -d" " -f1)
elif [ -n "$CLEAN_URL" ] && [ -f "$CLEAN_URL" ]; then
    file_sig=$(stat -c "%Y_%s" "$CLEAN_URL" 2>/dev/null || stat -f "%m_%z" "$CLEAN_URL" 2>/dev/null || echo "0_0")
    trackHash=$(echo -n "${PLAYER_ID}_${TITLE}_${ARTIST}_${CLEAN_URL}_${file_sig}" | md5sum | cut -d" " -f1)
elif [ -n "$TITLE" ] || [ -n "$ARTIST" ]; then
    trackHash=$(echo -n "${PLAYER_ID}_${TITLE}_${ARTIST}" | md5sum | cut -d" " -f1)
elif [ -n "$CLEAN_URL" ]; then
    trackHash=$(echo -n "${PLAYER_ID}_${CLEAN_URL}" | md5sum | cut -d" " -f1)
else
    trackHash=""
fi

FINAL_ART=""
COLOR_PATH=""
TEXT_PATH=""

if [ -n "$trackHash" ]; then
    FINAL_ART="$TMP_DIR/${trackHash}_art.jpg"
    COLOR_PATH="$TMP_DIR/${trackHash}_grad.txt"
    TEXT_PATH="$TMP_DIR/${trackHash}_text.txt"
fi

DISPLAY_ART=""
DISPLAY_GRAD="linear-gradient(45deg, #cba6f7, #89b4fa, #f38ba8, #cba6f7)"
DISPLAY_TEXT="#cdd6f4"
IS_PLACEHOLDER=true

CACHE_VALID=false
if [ -n "$FINAL_ART" ] && [ -f "$FINAL_ART" ] && [ -s "$FINAL_ART" ]; then
    DISPLAY_ART="$FINAL_ART"
    IS_PLACEHOLDER=false
    [ -f "$COLOR_PATH" ] && [ -s "$COLOR_PATH" ] && DISPLAY_GRAD=$(cat "$COLOR_PATH")
    [ -f "$TEXT_PATH" ] && [ -s "$TEXT_PATH" ] && DISPLAY_TEXT=$(cat "$TEXT_PATH")

    if [[ "$RAW_URL" == http* ]]; then
        curW=$(identify -format "%w" "$FINAL_ART" 2>/dev/null)
        [[ "$curW" =~ ^[0-9]+$ ]] || curW=0
        if [ "$curW" -ge 400 ]; then
            CACHE_VALID=true
        fi
    else
        CACHE_VALID=true
    fi
fi

if ! $CACHE_VALID && [ -n "$trackHash" ]; then
    tempArt="$TMP_DIR/${trackHash}_temp_art.$$"
    downloadOk=false

    if [[ "$RAW_URL" == http* ]]; then
        declare -a candidates=()
        if [[ "$RAW_URL" =~ (googleusercontent\.com|ggpht\.com) ]]; then
            base="${RAW_URL%%\=*}"
            candidates=(
                "${base}=w1200-h1200-l90-rj"
                "${base}=s1200"
                "${base}=s0"
                "$RAW_URL"
            )
        elif [[ "$RAW_URL" =~ (vi|vi_webp)/([^/?&#]+) ]]; then
            vid="${BASH_REMATCH[2]}"
            candidates=(
                "https://i.ytimg.com/vi/${vid}/maxresdefault.jpg"
                "https://i.ytimg.com/vi/${vid}/sddefault.jpg"
                "https://i.ytimg.com/vi/${vid}/hq720.jpg"
                "https://i.ytimg.com/vi/${vid}/hqdefault.jpg"
                "$RAW_URL"
            )
        elif [[ "$RAW_URL" =~ ytimg\.com ]]; then
            candidates=(
                "$(echo "$RAW_URL" | sed -E 's/(default|hqdefault|mqdefault|sddefault|hq720)\.(jpg|webp)/maxresdefault.jpg/')"
                "$(echo "$RAW_URL" | sed -E 's/(default|hqdefault|mqdefault|sddefault|hq720)\.(jpg|webp)/sddefault.jpg/')"
                "$(echo "$RAW_URL" | sed -E 's/(default|hqdefault|mqdefault|sddefault|hq720)\.(jpg|webp)/hq720.jpg/')"
                "$(echo "$RAW_URL" | sed -E 's/(default|hqdefault|mqdefault|sddefault|hq720)\.(jpg|webp)/hqdefault.jpg/')"
                "$RAW_URL"
            )
        elif [[ "$RAW_URL" =~ scdn\.co ]]; then
            candidates=(
                "$(echo "$RAW_URL" | sed -E 's/ab67([0-9a-f]{4})0000[0-9a-f]{4}/ab67\10000b273/')"
                "$(echo "$RAW_URL" | sed -E 's/ab67([0-9a-f]{4})0000[0-9a-f]{4}/ab67\100001e02/')"
                "$RAW_URL"
            )
        elif [[ "$RAW_URL" =~ sndcdn\.com ]]; then
            candidates=(
                "$(echo "$RAW_URL" | sed -E 's/-(large|t[0-9]+x[0-9]+|mini|tiny|small|badge|crop)\.([a-zA-Z0-9]+)$/-original.\2/')"
                "$(echo "$RAW_URL" | sed -E 's/-(large|t[0-9]+x[0-9]+|mini|tiny|small|badge|crop)\.([a-zA-Z0-9]+)$/-t500x500.\2/')"
                "$RAW_URL"
            )
        elif [[ "$RAW_URL" =~ mzstatic\.com ]]; then
            candidates=(
                "$(echo "$RAW_URL" | sed -E 's/[0-9]+x[0-9]+[a-z0-9-]*\.(jpg|jpeg|png|webp)/1400x1400bb.\1/')"
                "$(echo "$RAW_URL" | sed -E 's/[0-9]+x[0-9]+[a-z0-9-]*\.(jpg|jpeg|png|webp)/1000x1000bb.\1/')"
                "$RAW_URL"
            )
        elif [[ "$RAW_URL" =~ dzcdn\.net ]]; then
            candidates=(
                "$(echo "$RAW_URL" | sed -E 's/[0-9]+x[0-9]+-000000/1000x1000-000000/')"
                "$(echo "$RAW_URL" | sed -E 's/[0-9]+x[0-9]+-000000/500x500-000000/')"
                "$RAW_URL"
            )
        elif [[ "$RAW_URL" =~ bcbits\.com ]]; then
            candidates=(
                "$(echo "$RAW_URL" | sed -E 's/_[0-9]+\.jpg$/_10.jpg/')"
                "$(echo "$RAW_URL" | sed -E 's/_[0-9]+\.jpg$/_0.jpg/')"
                "$RAW_URL"
            )
        elif [[ "$RAW_URL" =~ resources\.tidal\.com ]]; then
            candidates=(
                "$(echo "$RAW_URL" | sed -E 's/[0-9]+x[0-9]+\.jpg$/1280x1280.jpg/')"
                "$(echo "$RAW_URL" | sed -E 's/[0-9]+x[0-9]+\.jpg$/640x640.jpg/')"
                "$RAW_URL"
            )
        elif [[ "$RAW_URL" =~ (amazon\.com|media-amazon\.com|images-amazon\.com) ]]; then
            candidates=(
                "$(echo "$RAW_URL" | sed -E 's/\._[A-Z0-9_,]+_\./._SL1400_./')"
                "$RAW_URL"
            )
        else
            candidates=("$RAW_URL")
        fi

        for cand in "${candidates[@]}"; do
            [ -z "$cand" ] && continue
            httpCode=$(curl -s -L --max-time 4 -o "$tempArt" -w "%{http_code}" "$cand" 2>/dev/null)
            if [[ "$httpCode" =~ ^2[0-9][0-9]$ ]] && [ -s "$tempArt" ]; then
                dims=$(identify -format "%wx%h" "$tempArt" 2>/dev/null)
                if [ -n "$dims" ]; then
                    if [[ "$cand" =~ ytimg\.com ]] && [ "$dims" = "120x90" ]; then
                        rm -f "$tempArt"
                        continue
                    fi
                    downloadOk=true
                    break
                fi
            fi
            rm -f "$tempArt"
        done
    elif [ -n "$CLEAN_URL" ] && [ -f "$CLEAN_URL" ]; then
        if identify "$CLEAN_URL" >/dev/null 2>&1; then
            cp "$CLEAN_URL" "$tempArt" 2>/dev/null && downloadOk=true
        elif command -v ffmpeg >/dev/null 2>&1; then
            ffmpeg -y -i "$CLEAN_URL" -an -vcodec copy "$tempArt" >/dev/null 2>&1
            if [ -s "$tempArt" ] && identify "$tempArt" >/dev/null 2>&1; then
                downloadOk=true
            else
                rm -f "$tempArt"
            fi
        fi

        if ! $downloadOk; then
            dir=$(dirname "$CLEAN_URL")
            for img in "$dir/cover.jpg" "$dir/cover.png" "$dir/folder.jpg" "$dir/front.jpg" "$dir/album.jpg" "$dir/Cover.jpg" "$dir/Folder.jpg"; do
                if [ -f "$img" ] && identify "$img" >/dev/null 2>&1; then
                    cp "$img" "$tempArt" 2>/dev/null && downloadOk=true
                    break
                fi
            done
        fi
    fi

    if $downloadOk && [ -s "$tempArt" ]; then
        colors=$(convert "$tempArt" -resize 50x50 -alpha off +dither -quantize RGB -colors 3 -depth 8 -format "%c" histogram:info: 2>/dev/null | grep -E -o '#[0-9A-Fa-f]{6}' | head -n 3 | tr '\n' ' ')
        read -r -a color_array <<< "$colors"

        c1=${color_array[0]:-#cba6f7}
        c2=${color_array[1]:-$c1}
        c3=${color_array[2]:-$c1}

        echo "linear-gradient(45deg, $c1, $c2, $c3, $c1)" > "$COLOR_PATH"

        hex="${c1#\#}"
        r=$((16#${hex:0:2}))
        g=$((16#${hex:2:2}))
        b=$((16#${hex:4:2}))

        brightness=$(( (299*r + 587*g + 114*b) / 1000 ))

        if [ "$brightness" -lt 70 ]; then
            textColor="#ffffff"
        elif [ "$brightness" -lt 120 ]; then
            textColor="#fafafa"
        elif [ "$brightness" -lt 170 ]; then
            textColor="#f2f2f2"
        elif [ "$brightness" -lt 210 ]; then
            textColor="#e8e8e8"
        elif [ "$brightness" -lt 235 ]; then
            textColor="#444444"
        else
            textColor="#1e1e2e"
        fi

        echo "$textColor" > "$TEXT_PATH"

        mv -f "$tempArt" "$FINAL_ART"

        DISPLAY_ART="$FINAL_ART"
        DISPLAY_GRAD="linear-gradient(45deg, $c1, $c2, $c3, $c1)"
        DISPLAY_TEXT="$textColor"
        IS_PLACEHOLDER=false

        (cd "$TMP_DIR" 2>/dev/null && ls -1t -- *_art.jpg 2>/dev/null | tail -n +35 | while read -r f; do
            h="${f%_art.jpg}"
            rm -f "${h}_art.jpg" "${h}_grad.txt" "${h}_text.txt"
        done) >/dev/null 2>&1
    else
        rm -f "$tempArt"
    fi
fi

NOW_TS=$(date +%s)
DEVICE_CACHE_OK=false
if [ -f "$DEVICE_CACHE" ]; then
    CACHE_TS=$(jq -r '.ts // 0' "$DEVICE_CACHE" 2>/dev/null)
    [[ "$CACHE_TS" =~ ^[0-9]+$ ]] || CACHE_TS=0
    [ $((NOW_TS - CACHE_TS)) -lt 5 ] && DEVICE_CACHE_OK=true
fi

if $DEVICE_CACHE_OK; then
    DEV_ICON=$(jq -r '.icon' "$DEVICE_CACHE")
    DEV_NAME=$(jq -r '.name' "$DEVICE_CACHE")
else
    WP_INSPECT=$(timeout 0.4 wpctl inspect @DEFAULT_AUDIO_SINK@ 2>/dev/null)
    NODE_NAME=$(echo "$WP_INSPECT" | awk -F'"' '/node\.name/ {print $2; exit}')
    NODE_DESC=$(echo "$WP_INSPECT" | awk -F'"' '/node\.description/ {print $2; exit}')

    DEV_ICON="󰓃"; DEV_NAME="Speaker"
    if [[ "$NODE_NAME" == *"bluez"* ]]; then
        DEV_ICON="󰂯"
        DEV_NAME="${NODE_DESC:-Bluetooth Audio}"
    elif [[ "$NODE_NAME" == *"usb"* ]]; then
        DEV_NAME="USB Audio"
    elif [[ "$NODE_NAME" == *"pci"* ]]; then
        DEV_NAME="Speaker"
    elif [ -n "$NODE_DESC" ]; then
        DEV_NAME="$NODE_DESC"
    fi

    jq -n -c --arg icon "$DEV_ICON" --arg name "$DEV_NAME" --argjson ts "$NOW_TS" \
        '{icon: $icon, name: $name, ts: $ts}' > "$DEVICE_CACHE" 2>/dev/null
fi

ART_WIDTH=0
if [ -n "$DISPLAY_ART" ]; then
    ART_WIDTH=$(identify -format "%w" "$DISPLAY_ART" 2>/dev/null)
    [[ "$ART_WIDTH" =~ ^[0-9]+$ ]] || ART_WIDTH=0
fi

jq -n -c \
    --argjson artWidth "$ART_WIDTH" \
    --arg grad "$DISPLAY_GRAD" \
    --arg txtColor "$DISPLAY_TEXT" \
    --arg devIcon "$DEV_ICON" \
    --arg devName "$DEV_NAME" \
    --arg finalArt "$DISPLAY_ART" \
    --arg trackHash "$trackHash" \
    --arg playerId "$PLAYER_ID" \
    --arg title "$TITLE" \
    --arg artist "$ARTIST" \
    --arg rawUrl "$RAW_URL" \
    --argjson isPlaceholder "$IS_PLACEHOLDER" \
    '{
        grad: $grad,
        textColor: $txtColor,
        deviceIcon: $devIcon,
        deviceName: $devName,
        artUrl: $finalArt,
        artWidth: $artWidth,
        trackHash: $trackHash,
        playerId: $playerId,
        title: $title,
        artist: $artist,
        rawUrl: $rawUrl,
        isPlaceholder: $isPlaceholder
    }'
