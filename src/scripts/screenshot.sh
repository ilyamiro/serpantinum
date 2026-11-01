#!/usr/bin/env bash

EDIT_MODE=false
FULL_MODE=false
RECORD_MODE=false
SCAN_QR_MODE=false
OCR_MODE=false
GEOMETRY=""
SOURCE_IMG=""
CROP_RECT=""
LOGICAL_SIZE=""
DESK_VOL="1.0"
DESK_MUTE="false"
MIC_VOL="1.0"
MIC_MUTE="false"
MIC_DEVICE=""
VIDEO_BACKEND="gpu-screen-recorder"
TARGET_MON=""

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --edit) EDIT_MODE=true; shift ;;
        --full) FULL_MODE=true; shift ;;
        --record) RECORD_MODE=true; shift ;;
        --scan-qr) SCAN_QR_MODE=true; shift ;;
        --ocr) OCR_MODE=true; shift ;;
        --geometry) GEOMETRY="$2"; shift 2 ;;
        --source) SOURCE_IMG="$2"; shift 2 ;;
        --crop) CROP_RECT="$2"; shift 2 ;;
        --logical-size) LOGICAL_SIZE="$2"; shift 2 ;;
        --desk-vol) DESK_VOL="$2"; shift 2 ;;
        --desk-mute) DESK_MUTE="$2"; shift 2 ;;
        --mic-vol) MIC_VOL="$2"; shift 2 ;;
        --mic-mute) MIC_MUTE="$2"; shift 2 ;;
        --mic-dev) MIC_DEVICE="$2"; shift 2 ;;
        --backend) VIDEO_BACKEND="$2"; shift 2 ;;
        --monitor) TARGET_MON="$2"; shift 2 ;;
        *) shift ;;
    esac
done

is_zero_volume() {
    [[ "$1" =~ ^-?[0-9]*\.?[0-9]+$ ]] && awk -v v="$1" 'BEGIN { exit !(v + 0 <= 0) }'
}
if [ "$VIDEO_BACKEND" = "wf-recorder" ]; then
    is_zero_volume "$DESK_VOL" && DESK_MUTE="true"
    is_zero_volume "$MIC_VOL" && MIC_MUTE="true"
fi

export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
source "$SCRIPT_DIR/caching.sh"
source "$SCRIPT_DIR/i18n.sh"
qs_ensure_cache "screenshot"
qs_ensure_cache "recording"

CACHE_DIR="$QS_CACHE_RECORDING"
SAVE_DIR="${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
RECORD_DIR="${XDG_VIDEOS_DIR:-$HOME/Videos}/Recordings"
mkdir -p "$SAVE_DIR" "$RECORD_DIR"

REQUIRED_CMDS=("grim" "satty" "wl-copy" "pactl" "quickshell" "zbarimg" "python3")
MISSING_CMDS=()
for cmd in "${REQUIRED_CMDS[@]}"; do
    if ! command -v "$cmd" &> /dev/null; then
        MISSING_CMDS+=("$cmd")
    fi
done

if [ "$OCR_MODE" = true ] && ! command -v tesseract &> /dev/null; then
    MISSING_CMDS+=("tesseract")
fi

if [ "$RECORD_MODE" = true ]; then
    if ! command -v "$VIDEO_BACKEND" &> /dev/null; then
        MISSING_CMDS+=("$VIDEO_BACKEND")
    fi
fi

if [ ${#MISSING_CMDS[@]} -ne 0 ]; then
    notif_app="$(t "screenshot.notifications.system_app_name")"
    notif_title="$(t "screenshot.notifications.missing_deps_title")"
    notif_body="$(t "screenshot.notifications.missing_deps_body" "cmds=${MISSING_CMDS[*]}")"
    notify-send -u critical -a "$notif_app" "$notif_title" "$notif_body"
    exit 1
fi

if [ -f "$CACHE_DIR/rec_pid" ]; then
    REC_PID=$(cat "$CACHE_DIR/rec_pid" 2>/dev/null)
    FINAL_FILE=$(cat "$CACHE_DIR/final_file" 2>/dev/null)
    
    if [ -n "$REC_PID" ] && kill -0 "$REC_PID" 2>/dev/null; then
        [ -f "$CACHE_DIR/processing.lock" ] && exit 0
        touch "$CACHE_DIR/processing.lock"
        
        kill -SIGINT "$REC_PID" 2>/dev/null
        timeout=30
        while kill -0 "$REC_PID" 2>/dev/null && [ $timeout -gt 0 ]; do
            sleep 0.1
            timeout=$((timeout - 1))
        done
        kill -9 "$REC_PID" 2>/dev/null
        
        if [ -f "$FINAL_FILE" ]; then
            (
                VIDEO_THUMB="$QS_RUN_SCREENSHOT/thumb_$$.png"
                if command -v ffmpeg &> /dev/null; then
                    ffmpeg -ss 00:00:00.500 -i "$FINAL_FILE" -vframes 1 "$VIDEO_THUMB" -y &>/dev/null
                    NOTIF_ICON="$VIDEO_THUMB"
                else
                    NOTIF_ICON=""
                fi
                notif_app="$(t "screenshot.notifications.recorder_app_name")"
                notif_action="$(t "screenshot.notifications.open_folder")"
                notif_title="$(t "screenshot.notifications.recording_saved_title")"
                notif_body="$(t "screenshot.notifications.recording_saved_body" "file=$(basename "$FINAL_FILE")" "folder=$RECORD_DIR")"
                ACTION=$(notify-send -a "$notif_app" -i "$NOTIF_ICON" -h "string:image-path:$NOTIF_ICON" -A "default=$notif_action" "$notif_title" "$notif_body")
                rm -f "$VIDEO_THUMB"
                if [ "$ACTION" = "default" ]; then
                    if command -v ski &> /dev/null; then
                        ski "$RECORD_DIR"
                    else
                        xdg-open "$RECORD_DIR"
                    fi
                fi
            ) &
        else
            notif_app="$(t "screenshot.notifications.recorder_app_name")"
            notif_title="$(t "screenshot.notifications.recording_error_title")"
            notif_body="$(t "screenshot.notifications.recording_error_body")"
            notify-send -a "$notif_app" "$notif_title" "$notif_body"
        fi
        if [ -f "$CACHE_DIR/rec_modules" ]; then
            while read -r mod_id; do
                [ -n "$mod_id" ] && pactl unload-module "$mod_id" 2>/dev/null
            done < "$CACHE_DIR/rec_modules"
            rm -f "$CACHE_DIR/rec_modules"
        fi
        rm -f "$CACHE_DIR/processing.lock" "$CACHE_DIR/rec_pid" "$CACHE_DIR/final_file" "$CACHE_DIR/rec_start_epoch"
        exit 0
    else
        if [ -f "$CACHE_DIR/rec_modules" ]; then
            while read -r mod_id; do
                [ -n "$mod_id" ] && pactl unload-module "$mod_id" 2>/dev/null
            done < "$CACHE_DIR/rec_modules"
            rm -f "$CACHE_DIR/rec_modules"
        fi
        rm -f "$CACHE_DIR/processing.lock" "$CACHE_DIR/rec_pid" "$CACHE_DIR/final_file" "$CACHE_DIR/rec_start_epoch"
    fi
fi

crop_source() {
    local dst="$1" magick_bin img_w img_h x y w h lw lh
    [ -s "$SOURCE_IMG" ] && [ -n "$CROP_RECT" ] && [ -n "$LOGICAL_SIZE" ] || return 1
    if command -v magick &>/dev/null; then magick_bin="magick"
    elif command -v convert &>/dev/null; then magick_bin="convert"
    else return 1; fi
    read -r img_w img_h < <($magick_bin identify -format '%w %h' "$SOURCE_IMG" 2>/dev/null)
    [ -n "$img_w" ] && [ -n "$img_h" ] || return 1
    IFS=', x' read -r x y w h <<< "$CROP_RECT"
    IFS='x' read -r lw lh <<< "$LOGICAL_SIZE"
    local rect
    rect=$(awk -v x="$x" -v y="$y" -v w="$w" -v h="$h" -v lw="$lw" -v lh="$lh" -v iw="$img_w" -v ih="$img_h" 'BEGIN {
        if (lw <= 0 || lh <= 0) exit 1
        sx = iw / lw; sy = ih / lh
        x0 = int(x * sx + 0.5); y0 = int(y * sy + 0.5)
        x1 = int((x + w) * sx + 0.5); y1 = int((y + h) * sy + 0.5)
        if (x0 < 0) x0 = 0; if (y0 < 0) y0 = 0
        if (x1 > iw) x1 = iw; if (y1 > ih) y1 = ih
        if (x1 - x0 < 1 || y1 - y0 < 1) exit 1
        printf "%dx%d+%d+%d", x1 - x0, y1 - y0, x0, y0
    }') || return 1
    $magick_bin "$SOURCE_IMG" -crop "$rect" +repage "$dst" 2>/dev/null && [ -s "$dst" ]
}

capture_region() {
    local dst="$1"
    if crop_source "$dst"; then
        return 0
    fi
    grim -l 0 -g "$GEOMETRY" "$dst"
}

ocr_ui_language() {
    case "$(get_current_language)" in
        ar) echo "ara" ;; az) echo "aze" ;; bg) echo "bul" ;; de) echo "deu" ;; es) echo "spa" ;;
        fa) echo "fas" ;; fr) echo "fra" ;; hi) echo "hin" ;; hy) echo "hye" ;; id) echo "ind" ;;
        it) echo "ita" ;; ja) echo "jpn" ;; ko) echo "kor" ;; nl) echo "nld" ;; pl) echo "pol" ;;
        pt) echo "por" ;; ru) echo "rus" ;; tr) echo "tur" ;; ua) echo "ukr" ;; vi) echo "vie" ;;
        zh) echo "chi_sim" ;; zh_tw) echo "chi_tra" ;;
    esac
}

ocr_candidate_languages() {
    local installed lang
    local -A seen=()
    local ordered=()
    installed="$(tesseract --list-langs 2>/dev/null | tail -n +2 | grep -Ev '^(osd|equ)$|_vert$')"
    for lang in eng "$(ocr_ui_language)" rus chi_sim jpn kor ara hin fas hye ukr bul deu spa fra ita por nld pol tur aze ind vie chi_tra $installed; do
        [ -n "$lang" ] && [ -z "${seen[$lang]}" ] && grep -qx "$lang" <<< "$installed" && { seen[$lang]=1; ordered+=("$lang"); }
    done
    printf '%s\n' "${ordered[@]:0:24}"
}

ocr_score_tsv() {
    python3 -c '
import sys
total = chars = good = native = 0
for i, line in enumerate(sys.stdin):
    p = line.rstrip("\n").split("\t")
    if i == 0 or len(p) < 12 or p[0] != "5" or not p[11]:
        continue
    try:
        conf = float(p[10])
    except ValueError:
        continue
    if conf < 0:
        continue
    n = len(p[11])
    total += conf * n
    chars += n
    if conf >= 70:
        good += n
    if conf >= 85:
        native += sum(1 for ch in p[11] if ord(ch) > 0x24F)
print(sys.argv[1], int(total), chars, good, native)' "$1"
}

ocr_score_language() {
    OMP_THREAD_LIMIT=1 tesseract "$1" stdout -l "$2" -c tessedit_create_tsv=1 2>/dev/null | ocr_score_tsv "$2"
}
export -f ocr_score_tsv ocr_score_language

ocr_pick_languages() {
    awk -v order="$1" '
        BEGIN {
            split("eng deu spa fra ita por nld pol tur aze ind vie", latin, " ")
            for (i in latin) grp[latin[i]] = "lat"
            split("rus ukr bul", cyr, " ")
            for (i in cyr) grp[cyr[i]] = "cyr"
            split("chi_sim chi_tra jpn kor", cjk, " ")
            for (i in cjk) grp[cjk[i]] = "cjk"
            split("ara fas", arab, " ")
            for (i in arab) grp[arab[i]] = "ara"
            kn["lat"] = 1; kn["cyr"] = 1; kn["cjk"] = 1; kn["ara"] = 1
            m = split(order, o, " ")
            for (i = 1; i <= m; i++) pri[o[i]] = i
        }
        { lang[NR] = $1; sum[NR] = $2; chars[NR] = $3; good[NR] = $4; native[NR] = $5; if ($3 > maxchars) maxchars = $3 }
        END {
            for (i = 1; i <= NR; i++) {
                if (chars[i] <= 0) continue
                v[i] = (sum[i] / chars[i]) * sqrt(chars[i] / maxchars)
                g = (lang[i] in grp) ? grp[lang[i]] : "x_" lang[i]
                gr[i] = g
                if (!(g in gv) || v[i] > gv[g]) gv[g] = v[i]
                if (good[i] > gg[g]) gg[g] = good[i]
                if (native[i] > gn[g]) gn[g] = native[i]
                if (gg[g] > maxgood) maxgood = gg[g]
                if (v[i] > top) { top = v[i]; topg = g }
            }
            for (g in gv) {
                rep = ""
                for (i = 1; i <= NR; i++) {
                    if (gr[i] == g && v[i] >= gv[g] - 1 && (rep == "" || pri[lang[i]] < pri[rep])) rep = lang[i]
                }
                if (g == topg || (g in kn && gg[g] >= 4 && gg[g] >= 0.3 * maxgood && (g == "lat" || (gn[g] >= 3 && gn[g] >= 0.2 * maxgood)))) { sel[g] = rep }
            }
            out = ""
            for (pass = 0; pass < 2; pass++) {
                while (1) {
                    bestg = ""
                    for (g in sel) {
                        if (sel[g] == "" || (pass == 0) == (g == "lat")) continue
                        if (bestg == "" || gg[g] > gg[bestg]) bestg = g
                    }
                    if (bestg == "") break
                    out = out (out == "" ? "" : "+") sel[bestg]
                    sel[bestg] = ""
                }
            }
            print out
        }'
}

ocr_run() {
    local img="$1" base="$2" lang="$3" sum chars
    local lang_arg=()
    [ -n "$lang" ] && lang_arg=(-l "$lang")
    OCR_CONF=0
    OCR_CHARS=0
    rm -f "$base.txt" "$base.tsv"
    tesseract "$img" "$base" "${lang_arg[@]}" -c tessedit_create_txt=1 -c tessedit_create_tsv=1 2>/dev/null
    [ -s "$base.tsv" ] || return
    read -r _ sum chars _ < <(ocr_score_tsv "$lang" < "$base.tsv")
    OCR_CHARS="${chars:-0}"
    [ "$OCR_CHARS" -gt 0 ] && OCR_CONF=$((sum / chars))
    rm -f "$base.tsv"
}

ocr_recognize() {
    local img="$1" base="$2" langs=() fast scores use ui lang threshold=88
    mapfile -t langs < <(ocr_candidate_languages)
    if [ "${#langs[@]}" -le 1 ]; then
        ocr_run "$img" "$base" "${langs[0]}"
        return
    fi

    fast="eng"
    ui="$(ocr_ui_language)"
    [ -n "$ui" ] && [ "$ui" != "eng" ] && printf '%s\n' "${langs[@]}" | grep -qx "$ui" && fast="$ui+eng"
    for lang in deu spa fra ita por nld pol tur aze ind vie; do
        [ "$lang" != "$ui" ] && printf '%s\n' "${langs[@]}" | grep -qx "$lang" && threshold=95
    done
    ocr_run "$img" "$base" "$fast"
    [ "$OCR_CHARS" -ge 3 ] && [ "$OCR_CONF" -ge "$threshold" ] && return

    scores=$(printf '%s\n' "${langs[@]}" | xargs -P "$(nproc)" -I{} bash -c 'ocr_score_language "$0" "$1"' "$img" {})
    use="$(ocr_pick_languages "${langs[*]}" <<< "$scores")"
    if [ -z "$use" ]; then
        OCR_CONF=0
        OCR_CHARS=0
        rm -f "$base.txt"
        return
    fi
    if [[ "+$use+" != *"+eng+"* ]] && printf '%s\n' "${langs[@]}" | grep -qx eng; then
        use="$use+eng"
    fi
    ocr_run "$img" "$base" "$use"
}

get_active_monitor() {
    local mon=""
    if command -v hyprctl &>/dev/null; then
        mon=$(hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.focused == true) | .name' 2>/dev/null)
        if [ -z "$mon" ] || [ "$mon" = "null" ]; then
            mon=$(hyprctl activeworkspace -j 2>/dev/null | jq -r '.monitor // empty' 2>/dev/null)
        fi
    fi
    if [ -z "$mon" ] && command -v niri &>/dev/null; then
        mon=$(niri msg -j focused-output 2>/dev/null | jq -r '.name // empty' 2>/dev/null)
        if [ -z "$mon" ] || [ "$mon" = "null" ]; then
            mon=$(niri msg -j outputs 2>/dev/null | jq -r 'to_entries[]? | select(.value.is_focused == true) | .value.name // .key' 2>/dev/null)
        fi
    fi
    if [ -z "$mon" ] && command -v swaymsg &>/dev/null; then
        mon=$(swaymsg -t get_outputs 2>/dev/null | jq -r '.[] | select(.focused == true) | .name' 2>/dev/null)
    fi
    if [ -z "$mon" ] && [ -n "${MANGO_INSTANCE_SIGNATURE:-}" ] && command -v mmsg &>/dev/null; then
        mon=$(mmsg get cursorpos 2>/dev/null | jq -r '.monitor // empty' 2>/dev/null)
    fi
    if [ -z "$mon" ] || [ "$mon" = "null" ]; then
        if [ -f "$SCRIPT_DIR/monitors_detect.sh" ]; then
            mon=$(bash "$SCRIPT_DIR/monitors_detect.sh" 2>/dev/null | head -n 1)
        fi
    fi
    echo "$mon"
}

if [ -z "$TARGET_MON" ]; then
    TARGET_MON=$(get_active_monitor)
fi

if [ "$SCAN_QR_MODE" = false ] && [ "$OCR_MODE" = false ] && [ "$RECORD_MODE" = false ] && [ "$FULL_MODE" = false ] && [ -z "$GEOMETRY" ]; then
    PREFS="$QS_STATE_SCREENSHOT/audio_prefs"
    if [ -f "$PREFS" ]; then
        IFS=',' read -r QS_DESK_VOL QS_DESK_MUTE QS_MIC_VOL QS_MIC_MUTE QS_MIC_DEV < "$PREFS"
    else
        QS_DESK_VOL="1.0"; QS_DESK_MUTE="false"; QS_MIC_VOL="1.0"; QS_MIC_MUTE="false"; QS_MIC_DEV=""
    fi

    CACHE_FILE="$QS_CACHE_SCREENSHOT/geometry"
    VIDEO_CACHE_FILE="$QS_CACHE_SCREENSHOT/geometry_video"
    MODE_CACHE_FILE="$QS_CACHE_SCREENSHOT/video_mode"
    BACKEND_CACHE_FILE="$QS_CACHE_SCREENSHOT/video_backend"
    [ -f "$CACHE_FILE" ] && QS_CACHED_GEOM=$(cat "$CACHE_FILE") || QS_CACHED_GEOM=""
    [ -f "$VIDEO_CACHE_FILE" ] && QS_CACHED_VIDEO_GEOM=$(cat "$VIDEO_CACHE_FILE") || QS_CACHED_VIDEO_GEOM=""
    [ -f "$MODE_CACHE_FILE" ] && QS_CACHED_MODE=$(cat "$MODE_CACHE_FILE") || QS_CACHED_MODE="false"
    [ -f "$BACKEND_CACHE_FILE" ] && QS_CACHED_BACKEND=$(cat "$BACKEND_CACHE_FILE") || QS_CACHED_BACKEND="gpu-screen-recorder"

    if [ "$EDIT_MODE" = true ]; then
        QS_CACHED_MODE="false"
    fi

    if [ "$QS_CACHED_MODE" = "true" ]; then
        FREEZE_IMG=""
    else
        FREEZE_IMG="$QS_RUN_SCREENSHOT/freeze_$$.png"
        if [ -n "$TARGET_MON" ]; then
            grim -o "$TARGET_MON" -l 0 "$FREEZE_IMG" 2>/dev/null || grim -l 0 "$FREEZE_IMG"
        else
            grim -l 0 "$FREEZE_IMG"
        fi
    fi

    QS_AUDIO_PREFS="${QS_DESK_VOL},${QS_DESK_MUTE},${QS_MIC_VOL},${QS_MIC_MUTE},${QS_MIC_DEV}"

    exec quickshell ${MAIN_QML:+-p "$MAIN_QML"} ipc call screenshotOverlay toggle "$FREEZE_IMG" "$EDIT_MODE" "$QS_AUDIO_PREFS" "$QS_CACHED_GEOM" "$QS_CACHED_VIDEO_GEOM" "$QS_CACHED_MODE" "$QS_CACHED_BACKEND" "$TARGET_MON"
fi

if [ "$SCAN_QR_MODE" = true ]; then
    RES_FILE="$QS_RUN_SCREENSHOT/qr_result"
    export DEBUG_LOG="$QS_LOG_DIR/qr_debug.log"
    rm -f "$RES_FILE" "$DEBUG_LOG"
    
    TMP_IMG="$QS_RUN_SCREENSHOT/qr_temp_$$.png"
    capture_region "$TMP_IMG"
    
    export XML_OUT=$(zbarimg --xml -q "$TMP_IMG" 2>>"$DEBUG_LOG")
    if [ -n "$XML_OUT" ]; then
        python3 << 'EOF' > "$RES_FILE"
import os, sys, logging, re
import xml.etree.ElementTree as ET
debug_log = os.environ.get("DEBUG_LOG", "/tmp/qs_qr_debug.log")
logging.basicConfig(filename=debug_log, level=logging.DEBUG, format="%(asctime)s - %(levelname)s - %(message)s")
raw_xml = os.environ.get("XML_OUT", "")
if not raw_xml.strip():
    print("0,0,0,0|||ERROR: Empty output from zbarimg. See log.")
    sys.exit(0)
try:
    xml_clean = re.sub(r'\sxmlns="[^"]+"', '', raw_xml)
    xml_clean = re.sub(r"\sxmlns='[^']+'", '', xml_clean)
    tree = ET.fromstring(xml_clean)
    found_any = False
    for elem in tree.iter():
        if elem.tag.endswith('symbol'):
            found_any = True
            data_text = ''
            min_x, min_y, max_x, max_y = float('inf'), float('inf'), -float('inf'), -float('inf')
            for child in elem:
                if child.tag.endswith('data'):
                    data_text = child.text if child.text else ''
                elif child.tag.endswith('polygon'):
                    pts_str = child.get('points', '')
                    if pts_str:
                        pt_pairs = pts_str.replace('+', '').split(' ')
                        for pair in pt_pairs:
                            if ',' in pair:
                                try:
                                    x_str, y_str = pair.split(',')
                                    x, y = int(x_str), int(y_str)
                                    min_x = min(min_x, x)
                                    max_x = max(max_x, x)
                                    min_y = min(min_y, y)
                                    max_y = max(max_y, y)
                                except ValueError:
                                    pass
            if min_x == float('inf'): min_x, min_y, max_x, max_y = 0, 0, 0, 0
            w, h = max_x - min_x, max_y - min_y
            encoded = data_text.replace('\\', '\\\\').replace('\n', '\\n').replace('\r', '')
            print(f"{int(min_x)},{int(min_y)},{int(w)},{int(h)}|||{encoded}")
    if not found_any: print("0,0,0,0|||NOT_FOUND")
except Exception as e:
    print(f"0,0,0,0|||ERROR: XML Parse failure: {e}. Check log.")
EOF
    else
        echo -e "0,0,0,0|||NOT_FOUND" > "$RES_FILE"
    fi
    rm -f "$TMP_IMG"
    exit 0
fi

if [ "$OCR_MODE" = true ]; then
    notif_app="$(t "screenshot.notifications.screenshot_app_name")"
    source "$SCRIPT_DIR/ocr_langs.sh"
    ocr_use_user_data
    if ! tesseract --list-langs 2>/dev/null | tail -n +2 | grep -qx eng; then
        ocr_install eng && ocr_use_user_data
    fi
    if ! tesseract --list-langs 2>/dev/null | tail -n +2 | grep -qvx osd; then
        notify-send -u critical -a "$notif_app" "$(t "screenshot.notifications.ocr_missing_title")" "$(t "screenshot.notifications.ocr_missing_body")"
        [ -n "$SOURCE_IMG" ] && rm -f "$SOURCE_IMG"
        exit 1
    fi
    TMP_IMG="$QS_RUN_SCREENSHOT/ocr_temp_$$.png"
    capture_region "$TMP_IMG"
    [ -n "$SOURCE_IMG" ] && rm -f "$SOURCE_IMG"

    OCR_BASE="$QS_RUN_SCREENSHOT/ocr_out_$$"
    ocr_recognize "$TMP_IMG" "$OCR_BASE"
    OCR_TEXT="$(cat "$OCR_BASE.txt" 2>/dev/null)"
    rm -f "$TMP_IMG" "$OCR_BASE".*

    notif_action="$(t "screenshot.notifications.ocr_open_settings")"
    notif_hint="$(t "screenshot.notifications.ocr_language_hint")"
    if [ -n "$(printf '%s' "$OCR_TEXT" | tr -d '[:space:]')" ]; then
        printf '%s' "$OCR_TEXT" | wl-copy
        notif_preview=$(printf '%s' "${OCR_TEXT:0:200}" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')
        if [ "$OCR_CONF" -lt 65 ]; then
            ACTION=$(notify-send -a "$notif_app" -A "default=$notif_action" "$(t "screenshot.notifications.ocr_uncertain_title")" "$notif_hint"$'\n'"$notif_preview")
        else
            notify-send -a "$notif_app" "$(t "screenshot.notifications.ocr_copied_title")" "$notif_preview"
        fi
    else
        ACTION=$(notify-send -a "$notif_app" -A "default=$notif_action" "$(t "screenshot.notifications.ocr_empty_title")" "$(t "screenshot.notifications.ocr_empty_body") $notif_hint")
    fi
    [ "$ACTION" = "default" ] && bash "$SCRIPT_DIR/qs_manager.sh" open settings screenshot
    exit 0
fi

time=$(date +'%Y-%m-%d-%H%M%S')
FILENAME="$SAVE_DIR/Screenshot_$time.png"
VID_FILENAME="$RECORD_DIR/Recording_$time.mp4"

if [ "$FULL_MODE" = true ] || [ -n "$GEOMETRY" ]; then
    if [ "$RECORD_MODE" = true ]; then
        if [ "$VIDEO_BACKEND" = "wf-recorder" ]; then
            WF_ARGS=(-f "$VID_FILENAME")
            if [ -n "$GEOMETRY" ]; then
                WF_ARGS+=(-g "$GEOMETRY")
            elif [ -n "$TARGET_MON" ]; then
                WF_ARGS+=(-o "$TARGET_MON")
            fi

            REC_MODS=()
            if [ "$DESK_MUTE" != "true" ] && [ "$MIC_MUTE" != "true" ]; then
                DESK_SINK=$(pactl get-default-sink 2>/dev/null)
                DESK_SOURCE="${DESK_SINK:+$DESK_SINK.monitor}"
                if [ -z "$DESK_SOURCE" ]; then
                    DESK_SOURCE="default_output"
                fi

                if [ -n "$MIC_DEVICE" ] && [ "$MIC_DEVICE" != "null" ]; then
                    MIC_SOURCE="$MIC_DEVICE"
                else
                    MIC_SOURCE=$(pactl get-default-source 2>/dev/null)
                fi
                if [ -z "$MIC_SOURCE" ]; then
                    MIC_SOURCE="default_input"
                fi

                NULL_SINK="qs_rec_mix_$$"
                M_NULL=$(pactl load-module module-null-sink sink_name="$NULL_SINK" sink_properties=device.description="$NULL_SINK" 2>/dev/null)
                if [ -n "$M_NULL" ]; then
                    REC_MODS+=("$M_NULL")
                    DESK_PA_VOL=$(awk -v v="$DESK_VOL" 'BEGIN { printf "%d", (v > 0 ? v : 1.0) * 65536 }')
                    MIC_PA_VOL=$(awk -v v="$MIC_VOL" 'BEGIN { printf "%d", (v > 0 ? v : 1.0) * 65536 }')
                    M_LOOP1=$(pactl load-module module-loopback source="$DESK_SOURCE" sink="$NULL_SINK" volume="$DESK_PA_VOL" 2>/dev/null)
                    [ -n "$M_LOOP1" ] && REC_MODS+=("$M_LOOP1")
                    M_LOOP2=$(pactl load-module module-loopback source="$MIC_SOURCE" sink="$NULL_SINK" volume="$MIC_PA_VOL" 2>/dev/null)
                    [ -n "$M_LOOP2" ] && REC_MODS+=("$M_LOOP2")
                    WF_ARGS+=(--audio="${NULL_SINK}.monitor")
                else
                    WF_ARGS+=(--audio)
                fi
            elif [ "$DESK_MUTE" != "true" ]; then
                DESK_SINK=$(pactl get-default-sink 2>/dev/null)
                if [ -n "$DESK_SINK" ]; then
                    WF_ARGS+=(--audio="${DESK_SINK}.monitor")
                else
                    WF_ARGS+=(--audio)
                fi
            elif [ "$MIC_MUTE" != "true" ]; then
                if [ -n "$MIC_DEVICE" ] && [ "$MIC_DEVICE" != "null" ]; then
                    MIC_DEV="$MIC_DEVICE"
                else
                    MIC_DEV=$(pactl get-default-source 2>/dev/null)
                fi
                if [ -n "$MIC_DEV" ]; then
                    WF_ARGS+=(--audio="$MIC_DEV")
                else
                    WF_ARGS+=(--audio)
                fi
            fi

            if [ ${#REC_MODS[@]} -gt 0 ]; then
                printf "%s\n" "${REC_MODS[@]}" > "$CACHE_DIR/rec_modules"
            fi

            wf-recorder "${WF_ARGS[@]}" > /dev/null 2>&1 &
            REC_PID=$!
        else
            GSR_ARGS=(-w "${TARGET_MON:-screen}" -c "mp4" -f "60" -ac "aac")
            DESK_DEV=""
            MIC_DEV=""

            if [ "$DESK_MUTE" != "true" ]; then
                DESK_SINK=$(pactl get-default-sink 2>/dev/null)
                if [ -n "$DESK_SINK" ]; then
                    DESK_DEV="${DESK_SINK}.monitor"
                else
                    DESK_DEV="default_output"
                fi
            fi

            if [ "$MIC_MUTE" != "true" ]; then
                if [ -n "$MIC_DEVICE" ] && [ "$MIC_DEVICE" != "null" ]; then
                    MIC_DEV="$MIC_DEVICE"
                else
                    MIC_DEV=$(pactl get-default-source 2>/dev/null)
                fi
                if [ -z "$MIC_DEV" ]; then
                    MIC_DEV="default_input"
                fi
            fi

            if [ -n "$DESK_DEV" ] && [ -n "$MIC_DEV" ]; then
                GSR_ARGS+=(-a "${DESK_DEV}|${MIC_DEV}")
            elif [ -n "$DESK_DEV" ]; then
                GSR_ARGS+=(-a "$DESK_DEV")
            elif [ -n "$MIC_DEV" ]; then
                GSR_ARGS+=(-a "$MIC_DEV")
            fi

            gpu-screen-recorder "${GSR_ARGS[@]}" -o "$VID_FILENAME" > /dev/null 2>&1 &
            REC_PID=$!
        fi
        date +%s > "$CACHE_DIR/rec_start_epoch"
        echo "$VID_FILENAME" > "$CACHE_DIR/final_file"
        echo "$REC_PID" > "$CACHE_DIR/rec_pid"
        notif_app="$(t "screenshot.notifications.recorder_app_name")"
        notif_title="$(t "screenshot.notifications.recording_started_title")"
        notif_body="$(t "screenshot.notifications.recording_started_body")"
        notify-send -a "$notif_app" "$notif_title" "$notif_body"
        exit 0
    fi

    TMP_SCREENSHOT="/tmp/instant_snap_$$.png"
    if [ -n "$GEOMETRY" ]; then
        capture_region "$TMP_SCREENSHOT"
    elif [ -n "$TARGET_MON" ]; then
        grim -o "$TARGET_MON" -l 0 "$TMP_SCREENSHOT" 2>/dev/null || grim -l 0 "$TMP_SCREENSHOT"
    else
        grim -l 0 "$TMP_SCREENSHOT"
    fi

    if [ "$EDIT_MODE" = true ]; then
        GSK_RENDERER=gl satty --filename "$TMP_SCREENSHOT" --output-filename "$FILENAME" --init-tool brush --copy-command "wl-copy --type image/png"
    else
        cp "$TMP_SCREENSHOT" "$FILENAME"
    fi
    rm -f "$TMP_SCREENSHOT"
    [ -n "$SOURCE_IMG" ] && rm -f "$SOURCE_IMG"

    if [ -s "$FILENAME" ]; then
        wl-copy --type image/png < "$FILENAME"
        (
            notif_app="$(t "screenshot.notifications.screenshot_app_name")"
            notif_action="$(t "screenshot.notifications.open_folder")"
            notif_title="$(t "screenshot.notifications.screenshot_saved_title")"
            notif_body="$(t "screenshot.notifications.screenshot_saved_body" "file=Screenshot_$time.png" "folder=$SAVE_DIR")"
            ACTION=$(notify-send -a "$notif_app" -i "$FILENAME" -h "string:image-path:$FILENAME" -A "default=$notif_action" "$notif_title" "$notif_body")
            if [ "$ACTION" = "default" ]; then
                if command -v ski &> /dev/null; then
                    ski "$SAVE_DIR"
                else
                    xdg-open "$SAVE_DIR"
                fi
            fi
        ) &
    fi
    exit 0
fi
