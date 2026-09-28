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
            guide) app_name="$(t "widgets.guide.name")" ;;
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
    elif [[ "$DE" == *"sway"* ]] || [[ -n "${SWAYSOCK:-}" ]]; then
        if [[ "$TARGET" == "move" ]]; then
            swaymsg move container to workspace number "$ACTION" >/dev/null 2>&1 &
        else
            swaymsg workspace number "$ACTION" >/dev/null 2>&1 &
        fi
    else
        # With per-monitor groups the keybind number is an index inside the current
        # monitor's own block, not an absolute workspace. Without the offset every
        # bind addresses the first monitor's block and drags focus to that screen.
        TARGET_WS="$ACTION"
        WS_GROUPS_PER_MONITOR=false
        if command -v _config_ensure_settings &>/dev/null; then
            _config_ensure_settings
        fi
        if [[ -n "$CONFIG_SETTINGS_JSON" && -f "$CONFIG_SETTINGS_JSON" ]]; then
            WS_GROUPS_PER_MONITOR="$(jq -r '.bar.workspaceGroupsPerMonitor // false' "$CONFIG_SETTINGS_JSON" 2>/dev/null)"
        fi

        if [[ "$WS_GROUPS_PER_MONITOR" == "true" ]]; then
            # The block size is the configured count, matching the widget's stride.
            # Same lookup order and 2-10 clamp as the widgets' groupSize.
            GROUP_SIZE="$(jq -r '.bar.workspaceCount // .general.workspaceCount // .workspaceCount // 8' "$CONFIG_SETTINGS_JSON" 2>/dev/null)"
            if [[ ! "$GROUP_SIZE" =~ ^[0-9]+$ ]]; then
                GROUP_SIZE=8
            fi
            (( GROUP_SIZE < 2 )) && GROUP_SIZE=2
            (( GROUP_SIZE > 10 )) && GROUP_SIZE=10

            # The monitor comes from the cursor, not from "focused". With an empty
            # workspace on the second screen the keyboard focus stays on the last
            # window, so "focused" still names the other monitor while the cursor
            # is already here - switching would then happen on the screen you are
            # not looking at. Falls back to "focused" if the position is unknown.
            CURSOR_POS="$(hyprctl cursorpos 2>/dev/null | tr -d ' ')"
            CURSOR_X="${CURSOR_POS%%,*}"
            CURSOR_Y="${CURSOR_POS##*,}"
            [[ "$CURSOR_X" =~ ^-?[0-9]+$ ]] || CURSOR_X=null
            [[ "$CURSOR_Y" =~ ^-?[0-9]+$ ]] || CURSOR_Y=null

            # Same ordering as the bar widget: left to right, y breaking ties.
            # Extents are divided by scale because x/y are in logical coordinates.
            MON_INFO="$(hyprctl monitors -j 2>/dev/null | jq -c \
                --argjson x "$CURSOR_X" --argjson y "$CURSOR_Y" '
                ([ .[] | select(.disabled != true) ] | sort_by(.x, .y)) as $mons
                | ( ( ( $mons | to_entries
                        | map(select($x >= .value.x and $x < (.value.x + .value.width / .value.scale)
                                  and $y >= .value.y and $y < (.value.y + .value.height / .value.scale)))
                        | .[0].key )
                      // ( $mons | map(.focused) | index(true) )
                      // 0 ) as $i
                    | { i: $i, mon: $mons[$i].name, names: [ $mons[].name ] } )
            ' 2>/dev/null)"
            MON_INDEX="$(jq -r '.i // empty' <<<"$MON_INFO" 2>/dev/null)"
            MON_NAME="$(jq -r '.mon // empty' <<<"$MON_INFO" 2>/dev/null)"
            MON_NAMES_LUA="$(jq -r '"{ " + (.names | map(tojson) | join(", ")) + " }"' <<<"$MON_INFO" 2>/dev/null)"
            if [[ "$MON_INDEX" =~ ^[0-9]+$ && -n "$MON_NAME" ]]; then
                TARGET_WS=$(( ACTION + MON_INDEX * GROUP_SIZE ))

                # One Lua dispatch, same logic as bar/WorkspaceGroups.js switchLua:
                # a workspace of this block living on another screen is brought
                # here instead of dragging the focus over there, and the switch
                # happens on the monitor under the cursor, not the one that still
                # holds keyboard focus (a new workspace is created on the latter).
                MON_NAME_LUA="$(jq -rn --arg m "$MON_NAME" '$m | tojson')"
                if [[ "$TARGET" == "move" ]]; then
                    ACT_LUA='if win then hl.dispatch(hl.dsp.window.move({ workspace = tostring(id), window = "address:" .. win.address })) end '
                else
                    ACT_LUA='hl.dispatch(hl.dsp.focus({ monitor = mon })); hl.dispatch(hl.dsp.focus({ workspace = tostring(id) })); '
                fi
                LUA="function() local names = $MON_NAMES_LUA; local size = $GROUP_SIZE; \
local function groupOf(n) for i, v in ipairs(names) do if v == n then return i end end end \
local function monOf(id) local w = hl.get_workspace(id); return w and w.monitor and w.monitor.name end \
local function bring(id, mon) local on = monOf(id); if not on or on == mon then return end \
local om = hl.get_monitor(on); local ow = om and om.active_workspace; local oi = groupOf(on); \
if ow and ow.id == id and oi then local first = (oi - 1) * size + 1; local fon = monOf(first); \
if first ~= id and (not fon or fon == on) then hl.dispatch(hl.dsp.focus({ monitor = on })); \
hl.dispatch(hl.dsp.focus({ workspace = tostring(first) })); end end \
on = monOf(id); if on and on ~= mon then hl.dispatch(hl.dsp.workspace.move({ workspace = tostring(id), monitor = mon })); end end \
local mon = $MON_NAME_LUA; local id = $TARGET_WS; local win = hl.get_active_window(); bring(id, mon); ${ACT_LUA}\
if monOf(id) and monOf(id) ~= mon then hl.dispatch(hl.dsp.workspace.move({ workspace = tostring(id), monitor = mon })); end end"
                hyprctl dispatch "$LUA" >/dev/null 2>&1 &
                send_qs_ipc "close" "" "" &
                exit 0
            fi
        fi

        if [[ "$TARGET" == "move" ]]; then
            hyprctl dispatch movetoworkspace "$TARGET_WS" >/dev/null 2>&1 || hyprctl dispatch 'hl.dsp.window.move({ workspace = "'"$TARGET_WS"'" })' >/dev/null 2>&1 &
        else
            hyprctl dispatch workspace "$TARGET_WS" >/dev/null 2>&1 || hyprctl dispatch 'hl.dsp.focus({ workspace = "'"$TARGET_WS"'" })' >/dev/null 2>&1 &
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

QS_GUIDE_CACHE="$QS_CACHE_GUIDE"
GUIDE_MODE_FILE="$QS_GUIDE_CACHE/last_tab.txt"

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

if [[ "$ACTION" == "open" || "$ACTION" == "toggle" ]]; then
    log_widget_launch "$TARGET" &
    case "$TARGET" in
        network)
            [[ -d "$QS_NETWORK_CACHE" ]] || mkdir -p "$QS_NETWORK_CACHE"
            [[ -n "$SUBTARGET" ]] && echo "$SUBTARGET" > "$NETWORK_MODE_FILE"
            ;;
        guide)
            [[ -d "$QS_GUIDE_CACHE" ]] || mkdir -p "$QS_GUIDE_CACHE"
            [[ -n "$SUBTARGET" ]] && echo "$SUBTARGET" > "$GUIDE_MODE_FILE"
            ;;
        wallpaper)
            handle_wallpaper_prep
            SUBTARGET=""
            ;;
    esac
    send_qs_ipc "$ACTION" "$TARGET" "$SUBTARGET"
    exit 0
fi
