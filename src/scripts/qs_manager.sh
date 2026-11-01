#!/usr/bin/env bash

if [[ "${BASH_SOURCE[0]}" == */* ]]; then
    SCRIPT_DIR="$(cd -- "${BASH_SOURCE[0]%/*}" 2>/dev/null && pwd -P)"
else
    SCRIPT_DIR="$(pwd -P)"
fi

source "$SCRIPT_DIR/caching.sh" 2>/dev/null || true
source "$SCRIPT_DIR/config.sh" 2>/dev/null || true
source "$SCRIPT_DIR/i18n.sh" 2>/dev/null || true

ACTION="$1"
TARGET="$2"
SUBTARGET="$3"

send_qs_ipc() {
    if [[ -n "$MAIN_QML" ]]; then
        quickshell -p "$MAIN_QML" ipc call main handleCommand "$@" >/dev/null 2>&1
    else
        quickshell ipc call main handleCommand "$@" >/dev/null 2>&1
    fi
}

log_widget_launch() {
    local target="$1"
    [[ -z "$target" ]] && return

    local rank_script="$SCRIPT_DIR/../quickshell/launcher/app_rank.py"
    [[ -f "$rank_script" ]] || rank_script="$HOME/.config/quickshell/launcher/app_rank.py"

    local app_name="$target"
    if command -v t &>/dev/null; then
        case "$target" in
            wallpaper) app_name="$(t "widgets.wallpaper.name")" ;;
            network) app_name="$(t "widgets.network.name")" ;;
            volume) app_name="$(t "widgets.volume.name")" ;;
            settings) app_name="$(t "widgets.guide.name")" ;;
            calendar) app_name="$(t "widgets.calendar.name")" ;;
            music) app_name="$(t "widgets.music.name")" ;;
            notifications) app_name="$(t "widgets.notifications.name")" ;;
            system) app_name="$(t "widgets.system.name")" ;;
        esac
    fi

    if [[ -f "$rank_script" ]]; then
        python3 "$rank_script" --log-launch --name "$target" >/dev/null 2>&1 &
        if [[ -n "$app_name" && "$app_name" != "$target" && "$app_name" != "widgets."* ]]; then
            python3 "$rank_script" --log-launch --name "$app_name" >/dev/null 2>&1 &
        fi
    fi
}

if [[ "$ACTION" == "workspace" ]]; then
    if [[ "$2" =~ ^[0-9]+$ ]]; then
        ACTION="$2"
        TARGET="$3"
        SUBTARGET="$4"
    elif [[ "$3" =~ ^[0-9]+$ ]]; then
        ACTION="$3"
        TARGET="$2"
        SUBTARGET="$4"
    elif [[ "$4" =~ ^[0-9]+$ ]]; then
        ACTION="$4"
        TARGET="$2"
        SUBTARGET="$3"
    else
        ACTION="$2"
        TARGET="$3"
        SUBTARGET="$4"
    fi
fi

if [[ "$ACTION" =~ ^[0-9]+$ ]]; then
    if (( ACTION < 1 )); then
        exit 0
    fi

    DE="${XDG_CURRENT_DESKTOP:-${DESKTOP_SESSION:-}}"
    DE="${DE,,}"

    if [[ "$DE" == *"niri"* ]] || [[ -n "${NIRI_SOCKET:-}" ]]; then
        if [[ "$TARGET" == "move" ]]; then
            niri msg action move-window-to-workspace "$ACTION" >/dev/null 2>&1 &
        else
            niri msg action focus-workspace "$ACTION" >/dev/null 2>&1 &
        fi
    elif [[ "$DE" == *"mango"* ]] || [[ -n "${MANGO_INSTANCE_SIGNATURE:-}" ]]; then
        if [[ "$TARGET" == "move" ]]; then
            { mmsg dispatch "tag,$ACTION" && mmsg dispatch "view,$ACTION"; } >/dev/null 2>&1 &
        else
            mmsg dispatch "view,$ACTION" >/dev/null 2>&1 &
        fi
    elif [[ "$DE" == *"sway"* ]] || [[ -n "${SWAYSOCK:-}" ]]; then
        if [[ "$TARGET" == "move" ]]; then
            swaymsg move container to workspace number "$ACTION" >/dev/null 2>&1 &
        else
            swaymsg workspace number "$ACTION" >/dev/null 2>&1 &
        fi
    else
        if [[ "$TARGET" == "move" ]]; then
            hyprctl dispatch movetoworkspace "$ACTION" >/dev/null 2>&1 || hyprctl dispatch 'hl.dsp.window.move({ workspace = "'"$ACTION"'" })' >/dev/null 2>&1 &
        else
            hyprctl dispatch workspace "$ACTION" >/dev/null 2>&1 || hyprctl dispatch 'hl.dsp.focus({ workspace = "'"$ACTION"'" })' >/dev/null 2>&1 &
        fi
    fi

    send_qs_ipc "close" "" "" &

    exit 0
fi

SRC_DIR="${WALLPAPER_DIR:-${srcdir:-$HOME/Pictures/Wallpapers}}"
THUMB_DIR="$QS_CACHE_WALLPAPER/thumbs"
PREP_LOCK="$QS_RUN_DIR/wallpaper_prep.lock"

export MAGICK_THREAD_LIMIT=1

QS_NETWORK_CACHE="$QS_CACHE_NETWORK"
NETWORK_MODE_FILE="$QS_NETWORK_CACHE/mode"


MANIFEST="$THUMB_DIR/.manifest"

build_manifest() {
    find "$THUMB_DIR" -maxdepth 1 -type f ! -name '.source_dir' ! -name '.manifest' \
        -printf "%f\n" | sort > "$MANIFEST"
}

handle_wallpaper_prep() {
    [[ -d "$THUMB_DIR" ]] || mkdir -p "$THUMB_DIR"

    (
        if [[ -f "$PREP_LOCK" ]]; then
            if kill -0 "$(cat "$PREP_LOCK")" 2>/dev/null; then
                exit 0
            fi
        fi
        echo $BASHPID > "$PREP_LOCK"

        export THUMB_DIR SRC_DIR MANIFEST MAGICK_THREAD_LIMIT=1

        THUMB_SOURCE_FILE="$THUMB_DIR/.source_dir"
        if [[ -f "$THUMB_SOURCE_FILE" ]]; then
            read -r CACHED_SRC < "$THUMB_SOURCE_FILE"
            if [[ "$CACHED_SRC" != "$SRC_DIR" ]]; then
                find "$THUMB_DIR" -maxdepth 1 -type f \
                    ! -name '.source_dir' ! -name '.manifest' -delete
                echo "$SRC_DIR" > "$THUMB_SOURCE_FILE"
                > "$MANIFEST"
            fi
        else
            echo "$SRC_DIR" > "$THUMB_SOURCE_FILE"
            > "$MANIFEST"
        fi

        [[ ! -f "$MANIFEST" ]] && build_manifest

        SRC_LIST=$(mktemp)
        find "$SRC_DIR" -maxdepth 1 -type f \
            \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \
               -o -iname "*.gif" -o -iname "*.mp4" -o -iname "*.mkv" \
               -o -iname "*.mov" -o -iname "*.webm" \) \
            -printf "%f\n" | sort > "$SRC_LIST"

        comm -23 <(sed 's/^000_//' "$MANIFEST" | sort) "$SRC_LIST" | while read -r orphan; do
            rm -f "$THUMB_DIR/$orphan" "$THUMB_DIR/000_$orphan"
            sed -i "/^${orphan}$/d;/^000_${orphan}$/d" "$MANIFEST"
        done

        while IFS= read -r filename; do
            img="$SRC_DIR/$filename"
            [[ -f "$img" ]] || continue

            extension="${filename##*.}"

            if [[ "${extension,,}" == "webp" ]]; then
                new_img="${img%.*}.jpg"
                magick "$img" "$new_img" && rm -f "$img"
                img="$new_img"
                filename="$(basename "$img")"
                extension="jpg"
            fi

            if [[ "${extension,,}" =~ ^(mp4|mkv|mov|webm)$ ]]; then
                thumb="$THUMB_DIR/000_$filename"
                [[ -f "$THUMB_DIR/$filename" ]] && rm -f "$THUMB_DIR/$filename"
                if [[ ! -f "$thumb" ]]; then
                    ffmpeg -y -ss 00:00:05 -i "$img" -vframes 1 \
                        -threads 1 -f image2 -q:v 2 "$thumb" >/dev/null 2>&1 || rm -f "$thumb"
                    [[ -f "$thumb" ]] && echo "000_$filename" >> "$MANIFEST"
                fi
            else
                thumb="$THUMB_DIR/$filename"
                if [[ ! -f "$thumb" ]]; then
                    magick "$img" -resize x420 -quality 70 "$thumb" >/dev/null 2>&1 || rm -f "$thumb"
                    [[ -f "$thumb" ]] && echo "$filename" >> "$MANIFEST"
                fi
            fi
        done < <(comm -23 "$SRC_LIST" <(sed 's/^000_//' "$MANIFEST" | sort))

        rm -f "$SRC_LIST" "$PREP_LOCK"
    ) </dev/null >/dev/null 2>&1 &
}

if [[ "$ACTION" == "close" ]]; then
    send_qs_ipc "close" "" ""
    exit 0
fi

if [[ "$ACTION" == "guide" || "$ACTION" == "settings" ]]; then
    [[ "$ACTION" == "guide" ]] && echo "qs_manager: 'guide' is deprecated, use 'settings' instead" >&2
    SUBTARGET="$TARGET"
    TARGET="settings"
    ACTION="open"
fi

if [[ ( "$ACTION" == "open" || "$ACTION" == "toggle" ) && ( "$TARGET" == "settings" || "$TARGET" == "guide" ) ]]; then
    [[ "$TARGET" == "guide" ]] && echo "qs_manager: 'guide' is deprecated, use 'settings' instead" >&2
    log_widget_launch "settings" &
    exec bash "$SCRIPT_DIR/settings.sh" "$ACTION" "$SUBTARGET"
fi

if [[ "$ACTION" == "open" || "$ACTION" == "toggle" ]]; then
    log_widget_launch "$TARGET" &
    case "$TARGET" in
        network)
            [[ -d "$QS_NETWORK_CACHE" ]] || mkdir -p "$QS_NETWORK_CACHE"
            [[ -n "$SUBTARGET" ]] && echo "$SUBTARGET" > "$NETWORK_MODE_FILE"
            ;;
        wallpaper)
            handle_wallpaper_prep
            SUBTARGET=""
            ;;
    esac
    send_qs_ipc "$ACTION" "$TARGET" "$SUBTARGET"
    exit 0
fi
