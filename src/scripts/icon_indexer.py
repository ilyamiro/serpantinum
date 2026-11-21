#!/usr/bin/env python3
"""
Icon Indexer for Serpantinum
Scans standard XDG icon directories and builds a fast lookup map:
icon_name -> /absolute/path/to/icon.(png|svg|xpm|ico)
Prioritizes high-resolution and scalable icons from hicolor and pixmaps.
"""

import os
import sys
import json
import tempfile

def get_priority(dirpath):
    p_lower = dirpath.lower()
    if "/scalable/" in p_lower:
        return 100
    if "/512x512/" in p_lower:
        return 90
    if "/256x256/" in p_lower:
        return 80
    if "/128x128/" in p_lower:
        return 70
    if "/96x96/" in p_lower:
        return 65
    if "/64x64/" in p_lower:
        return 60
    if "/48x48/" in p_lower:
        return 50
    if "/pixmaps" in p_lower:
        return 45
    if "/32x32/" in p_lower:
        return 40
    if "/24x24/" in p_lower:
        return 30
    if "/22x22/" in p_lower:
        return 25
    if "/16x16/" in p_lower:
        return 10
    return 35

def index_icons(dest=None):
    paths = []
    home = os.path.expanduser("~")
    paths.append(os.path.join(home, ".local/share/icons"))
    paths.append(os.path.join(home, ".icons"))

    xdg_data = os.environ.get("XDG_DATA_DIRS", "/usr/local/share:/usr/share")
    for p in xdg_data.split(":"):
        if p:
            paths.append(os.path.join(p, "icons"))
            paths.append(os.path.join(p, "pixmaps"))

    valid_exts = {".png", ".svg", ".xpm", ".ico"}
    icons = {}
    priorities = {}

    for root_dir in paths:
        if not os.path.isdir(root_dir):
            continue
        for dirpath, _, filenames in os.walk(root_dir, followlinks=True):
            prio = get_priority(dirpath)
            for f in filenames:
                ext = os.path.splitext(f)[1].lower()
                if ext in valid_exts:
                    name = os.path.splitext(f)[0].lower()
                    if prio > priorities.get(name, -1):
                        priorities[name] = prio
                        icons[name] = os.path.join(dirpath, f)
                    if "." in name:
                        suffix = name.split(".")[-1]
                        if suffix and (prio - 1) > priorities.get(suffix, -1):
                            priorities[suffix] = prio - 1
                            icons[suffix] = os.path.join(dirpath, f)

    if dest and dest != "-":
        dir_name = os.path.dirname(os.path.abspath(dest))
        os.makedirs(dir_name, exist_ok=True)
        fd, tmp_path = tempfile.mkstemp(prefix="icons_", suffix=".tmp", dir=dir_name)
        with os.fdopen(fd, "w") as out:
            json.dump(icons, out)
        os.replace(tmp_path, dest)
    else:
        json.dump(icons, sys.stdout)

if __name__ == "__main__":
    dest_path = sys.argv[1] if len(sys.argv) > 1 else None
    index_icons(dest_path)
