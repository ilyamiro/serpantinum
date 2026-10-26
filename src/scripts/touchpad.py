#!/usr/bin/env python3
import os
import sys
import json
import re
import subprocess
import argparse

def get_hypr_config_paths():
    paths = []
    xdg_config = os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config"))
    user_settings = os.path.join(xdg_config, "hypr", "config", "settings.lua")
    paths.append(user_settings)
    
    # Also check serpantinum repository path if running within repo
    repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
    repo_settings = os.path.join(repo_root, "compositors", "hyprland", "config", "settings.lua")
    if os.path.exists(repo_settings) and repo_settings not in paths:
        paths.append(repo_settings)
    return paths

def read_hyprctl_option(opt):
    try:
        res = subprocess.run(["hyprctl", "getoption", opt, "-j"], capture_output=True, text=True, check=False)
        if res.returncode == 0 and res.stdout.strip():
            return json.loads(res.stdout)
    except Exception:
        pass
    return None

def get_current_settings():
    sensitivity = 0.5
    natural_scroll = True
    disable_while_typing = False
    accel_profile = "flat"

    # Try reading from hyprctl first
    opt_sens = read_hyprctl_option("input:sensitivity")
    if opt_sens and "float" in opt_sens:
        sensitivity = float(opt_sens["float"])

    opt_scroll = read_hyprctl_option("input:touchpad:natural_scroll")
    if opt_scroll and "bool" in opt_scroll:
        natural_scroll = bool(opt_scroll["bool"])

    opt_dwt = read_hyprctl_option("input:touchpad:disable_while_typing")
    if opt_dwt and "bool" in opt_dwt:
        disable_while_typing = bool(opt_dwt["bool"])

    opt_accel = read_hyprctl_option("input:accel_profile")
    if opt_accel and "str" in opt_accel:
        accel_profile = str(opt_accel["str"])

    # If hyprctl option was not set, try parsing settings.lua
    paths = get_hypr_config_paths()
    for p in paths:
        if os.path.isfile(p):
            try:
                with open(p, "r", encoding="utf-8") as f:
                    content = f.read()
                m_sens = re.search(r"\bsensitivity\s*=\s*([-0-9.]+)", content)
                if m_sens and (opt_sens is None or not opt_sens.get("set", False)):
                    sensitivity = float(m_sens.group(1))
                m_scroll = re.search(r"\bnatural_scroll\s*=\s*(true|false)", content)
                if m_scroll and (opt_scroll is None or not opt_scroll.get("set", False)):
                    natural_scroll = (m_scroll.group(1) == "true")
                m_dwt = re.search(r"\bdisable_while_typing\s*=\s*(true|false)", content)
                if m_dwt and (opt_dwt is None or not opt_dwt.get("set", False)):
                    disable_while_typing = (m_dwt.group(1) == "true")
                m_accel = re.search(r'\baccel_profile\s*=\s*"([^"]+)"', content)
                if m_accel and (opt_accel is None or not opt_accel.get("set", False)):
                    accel_profile = m_accel.group(1)
                break
            except Exception:
                pass

    return {
        "sensitivity": sensitivity,
        "natural_scroll": natural_scroll,
        "disable_while_typing": disable_while_typing,
        "accel_profile": accel_profile
    }

def update_lua_file(file_path, sensitivity=None, natural_scroll=None, disable_while_typing=None, accel_profile=None):
    if not os.path.isfile(file_path):
        return False
    try:
        with open(file_path, "r", encoding="utf-8") as f:
            content = f.read()
    except Exception as e:
        print(f"Failed to read {file_path}: {e}", file=sys.stderr)
        return False

    # 1. Update sensitivity inside input = { ... }
    if sensitivity is not None:
        m = re.search(r"(\binput\s*=\s*\{)(.*?)(\n\s*\},?\n)", content, re.DOTALL)
        if m:
            start, body, end = m.group(1), m.group(2), m.group(3)
            key_pattern = r"(\n\s*sensitivity\s*=\s*)([^,\n]+)(,?)"
            val_str = f"{sensitivity:.2f}".rstrip("0").rstrip(".") if isinstance(sensitivity, float) else str(sensitivity)
            if re.search(key_pattern, body):
                body = re.sub(key_pattern, rf"\g<1>{val_str}\g<3>", body, count=1)
            else:
                if "accel_profile" in body:
                    body = re.sub(r"(\n\s*accel_profile\s*=\s*[^,\n]+,?)", rf"\g<1>\n    sensitivity = {val_str},", body, count=1)
                else:
                    body = f"\n    sensitivity = {val_str}," + body
            content = content[:m.start()] + start + body + end + content[m.end():]

    # 2. Update accel_profile inside input = { ... }
    if accel_profile is not None:
        m = re.search(r"(\binput\s*=\s*\{)(.*?)(\n\s*\},?\n)", content, re.DOTALL)
        if m:
            start, body, end = m.group(1), m.group(2), m.group(3)
            key_pattern = r'(\n\s*accel_profile\s*=\s*)"[^"]*"(,?)'
            if re.search(key_pattern, body):
                body = re.sub(key_pattern, rf'\g<1>"{accel_profile}"\g<2>', body, count=1)
            else:
                body = f'\n    accel_profile = "{accel_profile}",' + body
            content = content[:m.start()] + start + body + end + content[m.end():]

    # 3. Update touchpad block inside input
    if natural_scroll is not None or disable_while_typing is not None:
        m = re.search(r"(\btouchpad\s*=\s*\{)(.*?)(\n\s*\},?\n)", content, re.DOTALL)
        if m:
            start, body, end = m.group(1), m.group(2), m.group(3)
            if natural_scroll is not None:
                val_str = "true" if natural_scroll else "false"
                key_pattern = r"(\n\s*natural_scroll\s*=\s*)([^,\n]+)(,?)"
                if re.search(key_pattern, body):
                    body = re.sub(key_pattern, rf"\g<1>{val_str}\g<3>", body, count=1)
                else:
                    body = f"\n      natural_scroll = {val_str}," + body
            if disable_while_typing is not None:
                val_str = "true" if disable_while_typing else "false"
                key_pattern = r"(\n\s*disable_while_typing\s*=\s*)([^,\n]+)(,?)"
                if re.search(key_pattern, body):
                    body = re.sub(key_pattern, rf"\g<1>{val_str}\g<3>", body, count=1)
                else:
                    body = f"\n      disable_while_typing = {val_str}," + body
            content = content[:m.start()] + start + body + end + content[m.end():]

    try:
        tmp_path = file_path + ".tmp"
        with open(tmp_path, "w", encoding="utf-8") as f:
            f.write(content)
        os.replace(tmp_path, file_path)
        return True
    except Exception as e:
        print(f"Failed to write {file_path}: {e}", file=sys.stderr)
        return False

def live_eval_hyprland(sensitivity=None, natural_scroll=None, disable_while_typing=None, accel_profile=None):
    lua_parts = []
    touchpad_parts = []
    
    if sensitivity is not None:
        val_str = f"{sensitivity:.4f}".rstrip("0").rstrip(".") if isinstance(sensitivity, float) else str(sensitivity)
        lua_parts.append(f"sensitivity = {val_str}")
    if accel_profile is not None:
        lua_parts.append(f'accel_profile = "{accel_profile}"')

    if natural_scroll is not None:
        touchpad_parts.append(f"natural_scroll = {'true' if natural_scroll else 'false'}")
    if disable_while_typing is not None:
        touchpad_parts.append(f"disable_while_typing = {'true' if disable_while_typing else 'false'}")

    if touchpad_parts:
        lua_parts.append(f"touchpad = {{ {', '.join(touchpad_parts)} }}")

    if not lua_parts:
        return

    cmd = f"hl.config({{ input = {{ {', '.join(lua_parts)} }} }})"
    try:
        subprocess.run(["hyprctl", "eval", cmd], capture_output=True, text=True, check=False)
    except Exception:
        pass

def reload_hyprland():
    try:
        subprocess.run(["hyprctl", "reload"], capture_output=True, text=True, check=False)
    except Exception:
        pass

def main():
    parser = argparse.ArgumentParser(description="Touchpad and cursor speed configuration helper")
    parser.add_argument("--get", action="store_true", help="Get current settings as JSON")
    parser.add_argument("--sensitivity", type=float, default=None, help="Set pointer sensitivity (-1.0 to 1.0)")
    parser.add_argument("--natural-scroll", type=str, default=None, choices=["true", "false", "1", "0"], help="Set natural scrolling")
    parser.add_argument("--disable-while-typing", type=str, default=None, choices=["true", "false", "1", "0"], help="Set disable while typing")
    parser.add_argument("--accel-profile", type=str, default=None, choices=["flat", "adaptive"], help="Set accel profile")
    parser.add_argument("--live-only", action="store_true", help="Only eval live in Hyprland without writing to file")
    parser.add_argument("--no-reload", action="store_true", help="Do not trigger hyprctl reload")
    args = parser.parse_args()

    if args.get:
        print(json.dumps(get_current_settings()))
        return

    nat_scroll = None
    if args.natural_scroll is not None:
        nat_scroll = args.natural_scroll in ["true", "1"]

    dwt = None
    if args.disable_while_typing is not None:
        dwt = args.disable_while_typing in ["true", "1"]

    # Live eval for instant feedback
    live_eval_hyprland(
        sensitivity=args.sensitivity,
        natural_scroll=nat_scroll,
        disable_while_typing=dwt,
        accel_profile=args.accel_profile
    )

    if not args.live_only:
        paths = get_hypr_config_paths()
        modified = False
        for p in paths:
            if update_lua_file(
                p,
                sensitivity=args.sensitivity,
                natural_scroll=nat_scroll,
                disable_while_typing=dwt,
                accel_profile=args.accel_profile
            ):
                modified = True

        if not args.no_reload:
            reload_hyprland()

    print(json.dumps(get_current_settings()))

if __name__ == "__main__":
    main()
