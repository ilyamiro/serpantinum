#!/usr/bin/env bash

source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/caching.sh" 2>/dev/null || true

if [ -n "$HYPRLAND_INSTANCE_SIGNATURE" ]; then
    exec python3 -u -c '
import os, sys, socket, time, json, subprocess

xdg = os.environ.get("XDG_RUNTIME_DIR", "/run/user/1000")
sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", "")
sock_path = os.path.join(xdg, "hypr", sig, ".socket2.sock")

layout_map = {
    "english": "EN",
    "russian": "RU",
    "ukrainian": "UA",
    "german": "DE",
    "french": "FR",
    "spanish": "ES",
    "polish": "PL",
    "italian": "IT",
    "japanese": "JA",
    "chinese": "ZH",
    "korean": "KO",
    "portuguese": "PT",
    "turkish": "TR",
    "czech": "CZ",
    "swedish": "SE",
    "norwegian": "NO",
    "danish": "DK",
    "dutch": "NL",
    "finnish": "FI",
    "greek": "GR",
    "hebrew": "HE",
    "arabic": "AR",
}

def get_short_code(full_name):
    norm = full_name.lower()
    for k, v in layout_map.items():
        if k in norm:
            return v
    clean = "".join([c for c in full_name if c.isalpha()])
    return clean[:2].upper() if clean else "EN"

def get_initial_layout():
    try:
        res = subprocess.run(["hyprctl", "devices", "-j"], capture_output=True, text=True, timeout=1)
        data = json.loads(res.stdout)
        kbs = data.get("keyboards", [])
        main_kb = next((k for k in kbs if k.get("main")), kbs[0] if kbs else None)
        if main_kb:
            return main_kb.get("active_keymap", "")
    except Exception:
        pass
    return ""

last_layout = get_initial_layout()

while True:
    try:
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.connect(sock_path)
        buf = ""
        while True:
            chunk = s.recv(4096).decode("utf-8", errors="ignore")
            if not chunk:
                break
            buf += chunk
            while "\n" in buf:
                line, buf = buf.split("\n", 1)
                if line.startswith("activelayout>>"):
                    data = line[len("activelayout>>"):]
                    if "," in data:
                        kb, layout_name = data.split(",", 1)
                        layout_name = layout_name.strip()
                        if layout_name and layout_name != last_layout:
                            last_layout = layout_name
                            short_code = get_short_code(layout_name)
                            sys.stdout.write(f"kblayout {short_code} {layout_name}\n")
                            sys.stdout.flush()
        s.close()
    except Exception:
        pass
    time.sleep(1)
'
elif command -v niri >/dev/null 2>&1; then
    exec niri msg -j event-stream 2>/dev/null | jq --unbuffered -r '
        select(has("KeyboardLayoutSwitched")) |
        .KeyboardLayoutSwitched |
        "kblayout \((.name // "US")[0:2] | ascii_upcase) \(.name // "US")"
    '
elif command -v swaymsg >/dev/null 2>&1; then
    exec swaymsg -t subscribe -m '["input"]' 2>/dev/null | jq --unbuffered -r '
        select(.change == "xkb_layout" or .change == "xkb_keymap") |
        .input.xkb_active_layout_name as $n |
        "kblayout \(($n // "US")[0:2] | ascii_upcase) \($n // "US")"
    '
fi
