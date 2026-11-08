#!/usr/bin/env bash

QUERY="$1"
SESSION_ID="${2:-0}"
SCRIPT_DIR="$(dirname "$(realpath "$0")")"

source "$SCRIPT_DIR/../caching.sh"
qs_ensure_cache "wallpaper"

CACHE_DIR="$QS_CACHE_WALLPAPER"
SEARCH_DIR="$CACHE_DIR/search_thumbs"
MAP_FILE="$CACHE_DIR/search_map.txt"
CONTROL_FILE="$QS_RUN_WALLPAPER/ddg_search_control"
PAUSE_TIMEOUT=600

mkdir -p "$SEARCH_DIR"

python3 -u "$SCRIPT_DIR/get_ddg_links.py" "$QUERY" | while IFS='|' read -r thumb_url full_url; do
    state=$(cat "$CONTROL_FILE" 2>/dev/null | tr -d '[:space:]')
    
    if [[ "$state" == "stop" ]]; then 
        exit 0 
    fi
    
    paused_at=$SECONDS
    while [[ "$state" == "pause" ]]; do
        (( SECONDS - paused_at >= PAUSE_TIMEOUT )) && exit 0
        sleep 1
        state=$(cat "$CONTROL_FILE" 2>/dev/null | tr -d '[:space:]')
    done

    if [ -z "$thumb_url" ] || [ -z "$full_url" ]; then continue; fi

    target_headers=$(curl -s -I -L -m 3 -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" "$full_url")
    target_type=$(echo "$target_headers" | grep -i "content-type:" | tail -n 1 | tr -d '\r')

    if [[ ! "$target_type" =~ "image/" ]]; then
        continue
    fi

    uuid=$(date +%s%N)
    ext="${full_url##*.}"
    ext="${ext%%\?*}"
    ext=$(echo "$ext" | tr '[:upper:]' '[:lower:]')
    if [[ ! "$ext" =~ ^(jpg|jpeg|png|webp|gif)$ ]]; then ext="jpg"; fi

    is_webp=0
    if [[ "$ext" == "webp" ]]; then
        is_webp=1
        ext="jpg"
    fi

    filename="ddg_${SESSION_ID}_${uuid}.${ext}"
    filepath="$SEARCH_DIR/$filename"
    tmppath="${filepath}.tmp"

    curl -s -L -m 5 -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" "$thumb_url" -o "$tmppath"

    state=$(cat "$CONTROL_FILE" 2>/dev/null | tr -d '[:space:]')
    if [[ "$state" == "stop" ]]; then 
        rm -f "$tmppath"
        exit 0 
    fi

    if [ -s "$tmppath" ]; then
        actual_mime=$(file -b --mime-type "$tmppath")
        
        if [[ ! "$actual_mime" =~ ^image/ ]]; then
            rm -f "$tmppath"
        else
            if [[ "$actual_mime" == "image/webp" ]] || [ $is_webp -eq 1 ]; then
                if command -v magick >/dev/null 2>&1; then
                    magick "$tmppath" "$filepath" 2>/dev/null || mv "$tmppath" "$filepath"
                elif command -v ffmpeg >/dev/null 2>&1; then
                    ffmpeg -y -i "$tmppath" "$filepath" >/dev/null 2>&1 || mv "$tmppath" "$filepath"
                else
                    mv "$tmppath" "$filepath"
                fi
                rm -f "$tmppath"
            else
                mv "$tmppath" "$filepath"
            fi
            echo "$filename|$full_url" >> "$MAP_FILE"
        fi
    else
        rm -f "$tmppath"
    fi
done
