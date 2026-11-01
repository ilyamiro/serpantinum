#!/usr/bin/env bash

OCR_DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/serpantinum/tessdata"
OCR_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/serpantinum/ocr"
OCR_MODELS_URL="https://raw.githubusercontent.com/tesseract-ocr/tessdata_fast/main"
OCR_API_URL="https://api.github.com/repos/tesseract-ocr/tessdata_fast/contents/"
OCR_AVAILABLE_MAX_AGE_MIN=1440

ocr_use_user_data() {
    compgen -G "$OCR_DATA_DIR/*.traineddata" > /dev/null || return 1
    export TESSDATA_PREFIX="$OCR_DATA_DIR"
}

ocr_valid_code() {
    [[ "$1" =~ ^[a-z][a-z_]*$ ]]
}

ocr_refresh_available() {
    local raw="$OCR_CACHE_DIR/available.raw" out="$OCR_CACHE_DIR/available.json"
    mkdir -p "$OCR_CACHE_DIR"
    curl -fsS -m 20 "$OCR_API_URL" -o "$raw" 2>/dev/null || return 1
    python3 - "$raw" > "$out.new" <<'PY' || { rm -f "$out.new"; return 1; }
import json, sys
with open(sys.argv[1], encoding="utf-8") as f:
    entries = json.load(f)
langs = []
for e in entries:
    name = e.get("name", "")
    if not name.endswith(".traineddata"):
        continue
    code = name[:-len(".traineddata")]
    if code in ("osd", "equ") or code.endswith("_vert"):
        continue
    langs.append({"code": code, "size": e.get("size", 0)})
if not langs:
    sys.exit(1)
print(json.dumps(langs))
PY
    mv "$out.new" "$out"
}

ocr_list() {
    local cache="$OCR_CACHE_DIR/available.json"
    if [ ! -s "$cache" ] || [ -n "$(find "$cache" -mmin +"$OCR_AVAILABLE_MAX_AGE_MIN" 2>/dev/null)" ]; then
        ocr_refresh_available || true
    fi
    python3 - "$cache" "$OCR_DATA_DIR" <<'PY'
import json, os, sys
cache, data_dir = sys.argv[1], sys.argv[2]
try:
    with open(cache, encoding="utf-8") as f:
        langs = json.load(f)
except (OSError, ValueError):
    langs = []
installed = set()
if os.path.isdir(data_dir):
    installed = {n[:-len(".traineddata")] for n in os.listdir(data_dir) if n.endswith(".traineddata")}
known = {l["code"] for l in langs}
for code in sorted(installed - known):
    if code in ("osd", "equ") or code.endswith("_vert"):
        continue
    langs.append({"code": code, "size": os.path.getsize(os.path.join(data_dir, code + ".traineddata"))})
for l in langs:
    l["installed"] = l["code"] in installed
print(json.dumps({"online": bool(known), "languages": langs}))
PY
}

ocr_download() {
    local code="$1" dst="$OCR_DATA_DIR/$1.traineddata"
    [ -s "$dst" ] && return 0
    mkdir -p "$OCR_DATA_DIR"
    curl -fSL -m 600 "$OCR_MODELS_URL/$code.traineddata" -o "$dst.part" 2>/dev/null || { rm -f "$dst.part"; return 1; }
    [ "$(stat -c %s "$dst.part")" -gt 1024 ] || { rm -f "$dst.part"; return 1; }
    mv "$dst.part" "$dst"
}

ocr_install() {
    ocr_valid_code "$1" || return 2
    ocr_download eng || return 1
    ocr_download "$1"
}

ocr_remove() {
    ocr_valid_code "$1" || return 2
    [ "$1" = "eng" ] && return 0
    rm -f "$OCR_DATA_DIR/$1.traineddata"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    case "$1" in
        list) ocr_list ;;
        install) ocr_install "$2" ;;
        remove) ocr_remove "$2" ;;
        dir) printf '%s\n' "$OCR_DATA_DIR" ;;
        *) echo "Usage: ocr_langs.sh {list|install <code>|remove <code>|dir}" >&2; exit 2 ;;
    esac
fi
