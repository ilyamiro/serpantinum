#!/usr/bin/env python3
"""
Serpantinum Keybindings Parser & Provider
Extracts native Serpantinum desktop shortcuts and active compositor (Hyprland) keybinds.
"""

import os
import sys
import json
import glob
import re
import subprocess
import argparse

NATIVE_SERPANTINUM_BINDS = [
    # Serpantinum Shell & Widgets
    {
        "keys": "SUPER + ?",
        "action": "serpantinum msg toggle keybinds",
        "description": "Keybindings Cheatsheet",
        "category": "Serpantinum",
        "source": "Serpantinum"
    },
    {
        "keys": "SUPER + D",
        "action": "serpantinum msg toggle launcher",
        "description": "Application Launcher",
        "category": "Serpantinum",
        "source": "Serpantinum"
    },
    {
        "keys": "SUPER + C",
        "action": "serpantinum msg toggle clipboard",
        "description": "Clipboard Manager",
        "category": "Serpantinum",
        "source": "Serpantinum"
    },
    {
        "keys": "SUPER + H",
        "action": "serpantinum msg toggle settings",
        "description": "Serpantinum Settings & Guide",
        "category": "Serpantinum",
        "source": "Serpantinum"
    },
    {
        "keys": "SUPER + W",
        "action": "serpantinum msg toggle wallpaper",
        "description": "Wallpaper Picker",
        "category": "Serpantinum",
        "source": "Serpantinum"
    },
    {
        "keys": "SUPER + S",
        "action": "serpantinum msg toggle calendar",
        "description": "Calendar & Clock",
        "category": "Serpantinum",
        "source": "Serpantinum"
    },
    {
        "keys": "SUPER + M",
        "action": "serpantinum msg toggle music",
        "description": "Media Player",
        "category": "Serpantinum",
        "source": "Serpantinum"
    },
    {
        "keys": "SUPER + N",
        "action": "serpantinum msg toggle network",
        "description": "Network Settings",
        "category": "Serpantinum",
        "source": "Serpantinum"
    },
    {
        "keys": "SUPER + V",
        "action": "serpantinum msg toggle volume",
        "description": "Volume & Audio Popup",
        "category": "Serpantinum",
        "source": "Serpantinum"
    },
    {
        "keys": "SUPER + B",
        "action": "serpantinum msg toggle system",
        "description": "System Panel & Power Menu",
        "category": "Serpantinum",
        "source": "Serpantinum"
    },
    {
        "keys": "SUPER + A",
        "action": "serpantinum msg bar autohide",
        "description": "Toggle Bar Autohide",
        "category": "Serpantinum",
        "source": "Serpantinum"
    },
    {
        "keys": "SUPER + R",
        "action": "serpantinum reload",
        "description": "Reload Shell",
        "category": "Serpantinum",
        "source": "Serpantinum"
    },

    # Applications
    {
        "keys": "SUPER + RETURN",
        "action": "kitty",
        "description": "Open Terminal",
        "category": "Apps",
        "source": "Serpantinum"
    },
    {
        "keys": "SUPER + E",
        "action": "ski",
        "description": "Open File Manager",
        "category": "Apps",
        "source": "Serpantinum"
    },
    {
        "keys": "SUPER + F",
        "action": "firefox",
        "description": "Open Web Browser",
        "category": "Apps",
        "source": "Serpantinum"
    },
    {
        "keys": "SUPER + L",
        "action": "serpantinum lock",
        "description": "Lock Screen",
        "category": "System",
        "source": "Serpantinum"
    },
    {
        "keys": "XF86PowerOff",
        "action": "serpantinum lock",
        "description": "Lock Screen (Power Button)",
        "category": "System",
        "source": "Serpantinum"
    },

    # Screenshots
    {
        "keys": "Print",
        "action": "serpantinum screenshot",
        "description": "Area Screenshot",
        "category": "Screenshots",
        "source": "Serpantinum"
    },
    {
        "keys": "SHIFT + Print",
        "action": "serpantinum screenshot --edit",
        "description": "Area Screenshot & Edit",
        "category": "Screenshots",
        "source": "Serpantinum"
    },
    {
        "keys": "SUPER + Print",
        "action": "serpantinum screenshot --full",
        "description": "Fullscreen Screenshot",
        "category": "Screenshots",
        "source": "Serpantinum"
    },
    {
        "keys": "SUPER + SHIFT + Print",
        "action": "serpantinum screenshot --full --edit",
        "description": "Fullscreen Screenshot & Edit",
        "category": "Screenshots",
        "source": "Serpantinum"
    },

    # Media & Sound
    {
        "keys": "SUPER + SPACE",
        "action": "playerctl play-pause",
        "description": "Play / Pause Media",
        "category": "Media",
        "source": "Serpantinum"
    },
    {
        "keys": "XF86AudioPlay",
        "action": "playerctl play-pause",
        "description": "Play / Pause Audio",
        "category": "Media",
        "source": "Serpantinum"
    },
    {
        "keys": "XF86AudioNext",
        "action": "playerctl next",
        "description": "Next Track",
        "category": "Media",
        "source": "Serpantinum"
    },
    {
        "keys": "XF86AudioPrev",
        "action": "playerctl previous",
        "description": "Previous Track",
        "category": "Media",
        "source": "Serpantinum"
    },
    {
        "keys": "XF86AudioRaiseVolume",
        "action": "serpantinum volume raise",
        "description": "Volume Up",
        "category": "Media",
        "source": "Serpantinum"
    },
    {
        "keys": "XF86AudioLowerVolume",
        "action": "serpantinum volume lower",
        "description": "Volume Down",
        "category": "Media",
        "source": "Serpantinum"
    },
    {
        "keys": "XF86AudioMute",
        "action": "serpantinum volume mute-toggle",
        "description": "Mute / Unmute Audio",
        "category": "Media",
        "source": "Serpantinum"
    },
    {
        "keys": "XF86AudioMicMute",
        "action": "serpantinum volume mic-toggle",
        "description": "Mute / Unmute Microphone",
        "category": "Media",
        "source": "Serpantinum"
    },
    {
        "keys": "XF86MonBrightnessUp",
        "action": "serpantinum brightness raise",
        "description": "Screen Brightness Up",
        "category": "Media",
        "source": "Serpantinum"
    },
    {
        "keys": "XF86MonBrightnessDown",
        "action": "serpantinum brightness lower",
        "description": "Screen Brightness Down",
        "category": "Media",
        "source": "Serpantinum"
    },

    # Window Management
    {
        "keys": "SUPER + Q",
        "action": "closewindow",
        "description": "Close Active Window",
        "category": "Windows",
        "source": "Serpantinum"
    },
    {
        "keys": "SUPER + SHIFT + F",
        "action": "togglefloating",
        "description": "Toggle Window Floating",
        "category": "Windows",
        "source": "Serpantinum"
    },
    {
        "keys": "SUPER + ALT + F",
        "action": "fullscreen",
        "description": "Toggle Fullscreen / Maximize",
        "category": "Windows",
        "source": "Serpantinum"
    },
    {
        "keys": "SUPER + Arrows",
        "action": "movefocus",
        "description": "Focus Window (Left / Right / Up / Down)",
        "category": "Windows",
        "source": "Serpantinum"
    },
    {
        "keys": "SUPER + CTRL + Arrows",
        "action": "movewindow",
        "description": "Move Window (Left / Right / Up / Down)",
        "category": "Windows",
        "source": "Serpantinum"
    },
    {
        "keys": "SUPER + SHIFT + Arrows",
        "action": "resizeactive",
        "description": "Resize Window (Relative +/- 50px)",
        "category": "Windows",
        "source": "Serpantinum"
    },
    {
        "keys": "SUPER + Mouse LMB",
        "action": "movewindow (drag)",
        "description": "Drag Window with Mouse",
        "category": "Windows",
        "source": "Serpantinum"
    },
    {
        "keys": "SUPER + Mouse RMB",
        "action": "resizewindow (drag)",
        "description": "Resize Window with Mouse",
        "category": "Windows",
        "source": "Serpantinum"
    },

    # Workspaces
    {
        "keys": "SUPER + 1..0",
        "action": "serpantinum msg workspace <n>",
        "description": "Switch to Workspace 1..10",
        "category": "Workspaces",
        "source": "Serpantinum"
    },
    {
        "keys": "SUPER + SHIFT + 1..0",
        "action": "serpantinum msg workspace <n> move",
        "description": "Move Active Window to Workspace 1..10",
        "category": "Workspaces",
        "source": "Serpantinum"
    }
]

def modmask_to_str(mask):
    parts = []
    if mask & 64: parts.append("SUPER")
    if mask & 4:  parts.append("CTRL")
    if mask & 8:  parts.append("ALT")
    if mask & 1:  parts.append("SHIFT")
    return " + ".join(parts)

def format_key_name(key):
    if not key:
        return ""
    key = str(key).strip()
    key_map = {
        "mouse:272": "Mouse LMB",
        "mouse:273": "Mouse RMB",
        "mouse:274": "Mouse MMB",
        "Return": "RETURN",
        "question": "?",
        "slash": "/",
        "space": "SPACE",
        "BackSpace": "BACKSPACE",
        "Escape": "ESC"
    }
    return key_map.get(key, key)

def get_action_description(dispatcher, arg, desc):
    if desc:
        return desc
    if not dispatcher or dispatcher.startswith("function:"):
        return arg or ""
    
    disp = dispatcher.lower()
    if disp == "exec":
        clean_arg = arg.strip()
        if "serpantinum msg toggle" in clean_arg:
            sub = clean_arg.split("toggle")[-1].strip()
            return f"Toggle Serpantinum {sub.capitalize()}"
        if "serpantinum msg workspace" in clean_arg:
            return f"Workspace command: {clean_arg}"
        if "serpantinum" in clean_arg:
            return clean_arg
        return f"Launch {clean_arg}"
    elif disp == "killactive":
        return "Close Active Window"
    elif disp == "togglefloating":
        return "Toggle Floating"
    elif disp == "fullscreen":
        return "Toggle Fullscreen"
    elif disp == "movefocus":
        return f"Focus Window {arg}"
    elif disp == "movewindow":
        return f"Move Window {arg}"
    elif disp == "resizeactive":
        return f"Resize Active Window {arg}"
    elif disp == "workspace":
        return f"Switch to Workspace {arg}"
    elif disp in ("movetoworkspace", "movetoworkspacesilent"):
        return f"Move Window to Workspace {arg}"
    
    return f"{dispatcher} {arg}".strip()

def categorize_action(action, description, dispatcher):
    combined = f"{action} {description} {dispatcher}".lower()
    if "serpantinum" in combined:
        return "Serpantinum"
    if any(k in combined for k in ["killactive", "close", "float", "fullscreen", "movefocus", "movewindow", "resize", "split"]):
        return "Windows"
    if "workspace" in combined:
        return "Workspaces"
    if any(k in combined for k in ["volume", "audio", "player", "play-pause", "bright", "mic"]):
        return "Media"
    if any(k in combined for k in ["screen", "grim", "slurp", "shot"]):
        return "Screenshots"
    if any(k in combined for k in ["terminal", "kitty", "foot", "alacritty", "firefox", "browser", "ski", "thunar", "nautilus", "code"]):
        return "Apps"
    if any(k in combined for k in ["lock", "power", "shutdown", "reboot", "suspend"]):
        return "System"
    return "Other"

def parse_hyprctl_binds():
    binds = []
    seen = set()
    try:
        out = subprocess.check_output(["hyprctl", "binds", "-j"], stderr=subprocess.DEVNULL, timeout=3)
        data = json.loads(out.decode("utf-8"))
        for item in data:
            modmask = item.get("modmask", 0)
            mods = modmask_to_str(modmask)
            raw_key = item.get("key", "")
            if not raw_key and item.get("keycode"):
                raw_key = f"code:{item.get('keycode')}"
            key_name = format_key_name(raw_key)
            if not key_name:
                continue

            full_keys = f"{mods} + {key_name}" if mods else key_name
            disp = item.get("dispatcher", "")
            arg = item.get("arg", "")
            desc = item.get("description", "")
            
            # Skip unmapped internal function pointer addresses without details
            if disp.startswith("function:") and not desc and not arg:
                continue

            act = f"{disp} {arg}".strip()
            action_desc = get_action_description(disp, arg, desc)
            cat = categorize_action(act, action_desc, disp)

            sig = (full_keys.upper(), act.lower())
            if sig in seen:
                continue
            seen.add(sig)

            binds.append({
                "keys": full_keys,
                "action": act,
                "description": action_desc,
                "category": cat,
                "source": "Hyprland"
            })
    except Exception:
        pass
    return binds

def clean_lua_key(raw_key):
    key = raw_key.replace("mainMod", "SUPER").replace("$mainMod", "SUPER")
    key = key.replace(".. key", "1..0").replace(".. ws", "1..0")
    key = key.replace("..", "+").replace('"', "").replace("'", "")
    parts = [format_key_name(p.strip()) for p in key.split("+") if p.strip()]
    return " + ".join(parts)

def clean_lua_action(act):
    m = re.search(r'exec_cmd\(\s*["\']([^"\']+)["\']\s*\)', act)
    if m:
        cmd = m.group(1).strip()
        return cmd, get_action_description("exec", cmd, "")
    if "exec_cmd(terminal)" in act:
        return "terminal", "Open Terminal"
    if "window.close" in act:
        return "closewindow", "Close Active Window"
    if "window.fullscreen" in act:
        return "fullscreen", "Toggle Fullscreen / Maximize"
    if "window.float" in act:
        return "togglefloating", "Toggle Floating Window"
    if "focus(" in act:
        m_dir = re.search(r'direction\s*=\s*["\']([^"\']+)["\']', act)
        d = m_dir.group(1) if m_dir else ""
        return f"movefocus {d}".strip(), f"Focus Window {d}".strip()
    if "window.move" in act:
        m_dir = re.search(r'direction\s*=\s*["\']([^"\']+)["\']', act)
        d = m_dir.group(1) if m_dir else ""
        return f"movewindow {d}".strip(), f"Move Window {d}".strip()
    if "window.resize(" in act:
        return "resizeactive", "Resize Active Window"
    if "window.drag" in act:
        return "drag window", "Drag Window with Mouse"
    if "window.resize" in act:
        return "resize window", "Resize Window with Mouse"
    return act, act

def parse_hyprland_files():
    binds = []
    seen = set()
    conf_patterns = [
        os.path.expanduser("~/.config/hypr/**/*.conf"),
        os.path.expanduser("~/.config/hypr/**/*.lua"),
        os.path.expanduser("~/.config/serpantinum/hyprland/**/*.conf"),
        os.path.join(os.path.dirname(__file__), "../../compositors/hyprland/config/keybinds.lua")
    ]
    files = []
    for pat in conf_patterns:
        files.extend(glob.glob(pat, recursive=True))

    bind_re = re.compile(r"^\s*bind[dmelrnt]*\s*=\s*([^,]+),\s*([^,]+),\s*(.*)", re.IGNORECASE)
    lua_bind_re = re.compile(r"hl\.bind\(\s*([^,]+)\s*,\s*(.+?)(?:\s*,\s*\{.*?\})?\s*\)\s*$", re.IGNORECASE)

    for fpath in files:
        try:
            with open(fpath, "r", encoding="utf-8", errors="ignore") as f:
                for line in f:
                    line = line.strip()
                    if not line or line.startswith("#") or line.startswith("--"):
                        continue
                    m = bind_re.match(line)
                    if m:
                        mods, key, rest = m.groups()
                        mods = mods.replace("$mainMod", "SUPER").replace("$mod", "SUPER").strip()
                        key = format_key_name(key.strip())
                        full_keys = f"{mods} + {key}" if mods else key
                        parts = [p.strip() for p in rest.split(",")]
                        desc = ""
                        disp = ""
                        arg = ""
                        if len(parts) >= 2:
                            disp = parts[0]
                            arg = parts[1]
                        elif len(parts) == 1:
                            disp = parts[0]
                        act = f"{disp} {arg}".strip()
                        action_desc = get_action_description(disp, arg, desc)
                        cat = categorize_action(act, action_desc, disp)
                        sig = (full_keys.upper(), act.lower())
                        if sig not in seen:
                            seen.add(sig)
                            binds.append({
                                "keys": full_keys,
                                "action": act,
                                "description": action_desc,
                                "category": cat,
                                "source": "Hyprland"
                            })
                        continue

                    m_lua = lua_bind_re.search(line)
                    if m_lua:
                        full_keys = clean_lua_key(m_lua.group(1))
                        act, action_desc = clean_lua_action(m_lua.group(2))
                        cat = categorize_action(act, action_desc, "")
                        sig = (full_keys.upper(), act.lower())
                        if sig not in seen:
                            seen.add(sig)
                            binds.append({
                                "keys": full_keys,
                                "action": act,
                                "description": action_desc,
                                "category": cat,
                                "source": "Hyprland"
                            })
        except Exception:
            pass
    return binds

def get_hyprland_binds():
    active = parse_hyprctl_binds()
    if active:
        return active
    return parse_hyprland_files()

def main():
    parser = argparse.ArgumentParser(description="Serpantinum Keybindings Extractor")
    parser.add_argument("--mode", choices=["native", "hyprland", "merged"], default="merged",
                        help="Keybinding source mode: native, hyprland, or merged (default: merged)")
    args = parser.parse_args()

    if args.mode == "native":
        result = NATIVE_SERPANTINUM_BINDS
    elif args.mode == "hyprland":
        hypr = get_hyprland_binds()
        result = hypr if hypr else NATIVE_SERPANTINUM_BINDS
    else:  # merged
        hypr = get_hyprland_binds()
        used_hypr_keys = set()
        result = []

        # Start with native Serpantinum list, letting active Hyprland bindings override matching keys
        for native in NATIVE_SERPANTINUM_BINDS:
            k = native["keys"].replace(" ", "").upper()
            matching_hypr = [b for b in hypr if b["keys"].replace(" ", "").upper() == k]
            if matching_hypr:
                for b in matching_hypr:
                    result.append(b)
                used_hypr_keys.add(k)
            else:
                result.append(native)

        # Append any user-defined Hyprland bindings that were not in the native list
        for b in hypr:
            k = b["keys"].replace(" ", "").upper()
            if k not in used_hypr_keys:
                result.append(b)
                used_hypr_keys.add(k)

    print(json.dumps(result, indent=2))

if __name__ == "__main__":
    main()
