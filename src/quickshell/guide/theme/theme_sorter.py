#!/usr/bin/env python3

import os
import re
import json
import math
import hashlib
import sys

ACCENT_KEYS = [
    "blue", "red", "green", "peach", "mauve",
    "teal", "sapphire", "pink", "yellow", "maroon",
]

BACKGROUND_KEYS = ["base", "mantle", "crust"]

MIN_SATURATION_FOR_HUE = 0.12
LIGHT_THRESHOLD = 0.5

HUE_BUCKETS = [
    (0, "red",    (345, 360)),
    (0, "red",    (0, 15)),
    (1, "orange", (15, 45)),
    (2, "yellow", (45, 70)),
    (3, "green",  (70, 160)),
    (4, "cyan",   (160, 200)),
    (5, "blue",   (200, 255)),
    (6, "purple", (255, 290)),
    (7, "pink",   (290, 345)),
]
NEUTRAL_BUCKET = -1

def hex_to_rgb(hex_str):
    h = hex_str.lstrip("#")
    if len(h) != 6 or not re.fullmatch(r"[0-9a-fA-F]{6}", h):
        return None
    r = int(h[0:2], 16) / 255.0
    g = int(h[2:4], 16) / 255.0
    b = int(h[4:6], 16) / 255.0
    return (r, g, b)

def rgb_to_hsl(r, g, b):
    mx, mn = max(r, g, b), min(r, g, b)
    l = (mx + mn) / 2.0
    if mx == mn:
        return (0.0, 0.0, l)
    d = mx - mn
    s = d / (2.0 - mx - mn) if l > 0.5 else d / (mx + mn)
    if mx == r:
        h = (g - b) / d + (6 if g < b else 0)
    elif mx == g:
        h = (b - r) / d + 2
    else:
        h = (r - g) / d + 4
    h *= 60
    return (h % 360, s, l)

def hue_to_bucket(angle):
    if angle is None:
        return NEUTRAL_BUCKET
    for bucket_index, _name, (lo, hi) in HUE_BUCKETS:
        if lo <= angle < hi:
            return bucket_index
    return NEUTRAL_BUCKET

def compute_lightness(colors):
    for key in BACKGROUND_KEYS:
        hexv = colors.get(key)
        rgb = hex_to_rgb(hexv) if hexv else None
        if rgb:
            _h, _s, l = rgb_to_hsl(*rgb)
            return l
    return 0.5

def compute_dominant_hue(colors, is_color_focused):
    bg_l, bg_s = [], []
    for k in BACKGROUND_KEYS:
        if k in colors and (rgb := hex_to_rgb(colors[k])):
            h, s, l = rgb_to_hsl(*rgb)
            bg_s.append(s)
            bg_l.append(l)
            
    avg_bg_sat = sum(bg_s) / len(bg_s) if bg_s else 0.0
    avg_bg_light = sum(bg_l) / len(bg_l) if bg_l else 0.5
    
    if not is_color_focused:
        if avg_bg_sat < 0.22:
            return None
        if avg_bg_light < 0.12 or avg_bg_light > 0.88:
            return None

    keys = BACKGROUND_KEYS + ACCENT_KEYS
    sum_x, sum_y = 0.0, 0.0
    any_sample = False
    
    for key in keys:
        if key not in colors:
            continue
        rgb = hex_to_rgb(colors[key])
        if not rgb:
            continue
            
        h, s, l = rgb_to_hsl(*rgb)
        if s < MIN_SATURATION_FOR_HUE:
            continue
            
        weight = s
        if key in BACKGROUND_KEYS:
            weight *= 3.0
        elif is_color_focused:
            weight *= 1.5
            
        angle = math.radians(h)
        sum_x += math.cos(angle) * weight
        sum_y += math.sin(angle) * weight
        any_sample = True
        
    if not any_sample or (abs(sum_x) < 1e-6 and abs(sum_y) < 1e-6):
        return None
        
    return math.degrees(math.atan2(sum_y, sum_x)) % 360

def classify_theme(colors, is_color_focused):
    lightness = compute_lightness(colors)
    hue_angle = compute_dominant_hue(colors, is_color_focused)
    return {
        "lightness": lightness,
        "lightness_group": "dark" if lightness < LIGHT_THRESHOLD else "light",
        "hue_bucket": hue_to_bucket(hue_angle),
        "hue_angle": hue_angle if hue_angle is not None else -1.0,
    }

def fingerprint(raw_bytes):
    return hashlib.sha1(raw_bytes).hexdigest()

def load_cache(cache_path):
    if not os.path.exists(cache_path):
        return {}
    try:
        with open(cache_path, "r", encoding="utf-8") as f:
            return json.load(f)
    except (json.JSONDecodeError, OSError):
        return {}

def save_cache(cache_path, cache):
    os.makedirs(os.path.dirname(cache_path), exist_ok=True)
    tmp_path = cache_path + ".tmp"
    with open(tmp_path, "w", encoding="utf-8") as f:
        json.dump(cache, f, indent=2, sort_keys=True)
    os.replace(tmp_path, cache_path)

def classify_with_cache(theme_key, raw_bytes, colors, is_color_focused, cache):
    fp = fingerprint(raw_bytes)
    cached = cache.get(theme_key)
    if cached and cached.get("fingerprint") == fp:
        return cached
    info = classify_theme(colors, is_color_focused)
    info["fingerprint"] = fp
    cache[theme_key] = info
    return info

def sort_themes(sys_dir, user_dir, cache_path):
    cache = load_cache(cache_path)
    cache_before = json.dumps(cache, sort_keys=True)
    classified = []

    def process_dir(directory, cat, custom):
        if not os.path.isdir(directory):
            return
        for filename in os.listdir(directory):
            if not filename.endswith(".json"):
                continue
            path = os.path.join(directory, filename)
            with open(path, "rb") as f:
                raw_bytes = f.read()
            try:
                data = json.loads(raw_bytes)
            except json.JSONDecodeError:
                continue

            data["category"] = cat
            if custom:
                data["isCustom"] = True

            colors = data.get("colors", {})
            is_focused = bool(data.get("isColorFocused"))
            theme_key = f"{cat}_{filename}"
            info = classify_with_cache(theme_key, raw_bytes, colors, is_focused, cache)
            
            name = data.get("name", "").lower()
            is_custom = data.get("isCustom", False)
            
            if name == "matugen":
                sort_key = (1, 0, 0, 0, name)
                group_id = "matugen"
            elif is_custom:
                sort_key = (0, 0, 0, 0, name)
                group_id = "user"
            else:
                lightness = info["lightness"]
                macro = 0 if info["lightness_group"] == "dark" else 1
                bucket = info["hue_bucket"]
                
                if bucket == NEUTRAL_BUCKET:
                    group_id = f"neutral_{info['lightness_group']}"
                    macro_sort = 2 if macro == 0 else 3
                    sort_key = (macro_sort, 0, lightness, 0, name)
                else:
                    group_id = f"colorful_{info['lightness_group']}_{bucket}"
                    macro_sort = 4 if macro == 0 else 5
                    sort_key = (macro_sort, bucket, lightness, info["hue_angle"], name)
                    
            classified.append((sort_key, group_id, data))

    process_dir(sys_dir, "system", False)
    process_dir(user_dir, "user", True)
    if json.dumps(cache, sort_keys=True) != cache_before:
        save_cache(cache_path, cache)

    classified.sort(key=lambda x: x[0])

    result = []
    prev_group = None

    if classified and classified[0][1] != "user":
        result.append({"isDivider": True})

    for sort_key, group_id, data in classified:
        if prev_group is not None and group_id != prev_group:
            result.append({"isDivider": True})
        result.append(data)
        prev_group = group_id

    return result

if __name__ == "__main__":
    sys_dir = sys.argv[1] if len(sys.argv) > 1 else ""
    user_dir = sys.argv[2] if len(sys.argv) > 2 else ""
    c_path = sys.argv[3] if len(sys.argv) > 3 else "theme_sort_cache.json"
    
    out = sort_themes(sys_dir, user_dir, c_path)
    print(json.dumps(out))
