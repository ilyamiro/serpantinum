#!/usr/bin/env python3
"""Safe display configuration transactions for Serpantinum.

Every change follows the same path:

    validate -> snapshot -> start independent reverter -> apply -> verify
             -> user confirms within the timeout  => keep (and remember as last-good)
             -> otherwise / UI crash / apply error => restore snapshot

The reverter runs in its own session (systemd --user transient unit when
available, otherwise a setsid'd process), so it survives a Quickshell crash.
If restoring the snapshot itself fails, it falls back to a "safe layout":
every connected output enabled at its preferred mode, auto position, scale 1.

Commands (all print one JSON object on stdout):
    state                      current normalized monitor state
    validate PLAN              check a plan without touching anything
    apply PLAN [--timeout S] [--partial] [--reflow NAME]
                               start a transaction (PLAN is a file, '-' or inline JSON).
                               --reflow NAME: monitor NAME changed size; shift its
                               neighbours so the layout stays attached.
                               Plans are matched to monitors by panel description
                               (connector names change between boots).
                               --partial: for profiles; drop absent monitors and
                               keep connected ones the plan does not mention.
    confirm                    keep the pending transaction
    revert                     revert the pending transaction now
    backends                   compositors this build can manage (no compositor needed)
    status                     pending transaction info (also heals stale ones)
    rescue                     restore last-good, or the safe layout (TTY use)

A PLAN is {"monitors": [{"name", "description", "enabled", "width", "height",
"refresh", "x", "y", "scale", "transform"}, ...]} and must list every
connected monitor.
"""

import fcntl
import json
import math
import os
import re
import shutil
import socket
import stat
import struct
import subprocess
import sys
import tempfile
import time
import uuid

DEFAULT_TIMEOUT = 15
MIN_TIMEOUT = 5
MAX_TIMEOUT = 60
POLL_INTERVAL = 0.2
VERIFY_ATTEMPTS = 10
VERIFY_DELAY = 0.3
REFRESH_TOLERANCE = 0.05  # Hz
MIN_SCALE = 0.25
MAX_SCALE = 4.0


class DisplayError(Exception):
    pass


# ---------------------------------------------------------------- paths


RUN_USER_BASE = "/run/user"  # tests point this somewhere else


def _private_dir(path):
    """Create `path` (0700) or reuse it if it really is ours: never follow a symlink or
    trust a directory somebody else owns (the shared temp dir is world-writable)."""
    os.makedirs(path, mode=0o700, exist_ok=True)
    st = os.lstat(path)
    if stat.S_ISLNK(st.st_mode) or not stat.S_ISDIR(st.st_mode) or st.st_uid != os.getuid():
        raise DisplayError("runtime_dir_unsafe:%s" % path)
    if st.st_mode & 0o077:
        os.chmod(path, 0o700)
    return path


def runtime_dir():
    # SERPANTINUM_DISPLAY_RUNTIME lets development runs keep their transaction
    # files away from the real session's runtime directory.
    path = os.environ.get("SERPANTINUM_DISPLAY_RUNTIME")
    if path:
        os.makedirs(path, mode=0o700, exist_ok=True)
        return path
    base = os.environ.get("XDG_RUNTIME_DIR") or "%s/%d" % (RUN_USER_BASE, os.getuid())
    if os.path.isdir(base) and os.access(base, os.W_OK):
        try:
            return _private_dir(os.path.join(base, "serpantinum-display"))
        except DisplayError:
            raise
        except OSError:
            pass
    # No usable runtime directory (e.g. Void without elogind/seatd-run-user): use a private
    # one in the temp dir. Every process of this user resolves to the same path, and the
    # reverter inherits it through SERPANTINUM_DISPLAY_RUNTIME.
    return _private_dir(os.path.join(tempfile.gettempdir(), "serpantinum-display-%d" % os.getuid()))


def state_dir():
    base = os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state")
    path = os.path.join(base, "serpantinum", "display")
    os.makedirs(path, mode=0o700, exist_ok=True)
    return path


def txn_path():
    return os.path.join(runtime_dir(), "txn.json")


def lock_path():
    return os.path.join(runtime_dir(), "txn.lock")


def last_good_path():
    return os.path.join(state_dir(), "last-good.json")


def log_path():
    return os.path.join(state_dir(), "display.log")


def hypr_config_dir():
    base = os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config")
    return os.path.join(base, "hypr")


def persist_path():
    # Our own module, like nwg-displays' monitors.lua. The user's files are never
    # written; they opt in with require("serpantinum/monitors").
    return os.path.join(hypr_config_dir(), "serpantinum", "monitors.lua")


def log(msg):
    try:
        with open(log_path(), "a") as f:
            f.write("%s [%d] %s\n" % (time.strftime("%Y-%m-%d %H:%M:%S"), os.getpid(), msg))
    except OSError:
        pass


def atomic_write_json(path, data):
    tmp = "%s.%d.tmp" % (path, os.getpid())
    with open(tmp, "w") as f:
        json.dump(data, f, indent=1)
        f.flush()
        os.fsync(f.fileno())
    os.replace(tmp, path)


def read_json(path):
    try:
        with open(path) as f:
            return json.load(f)
    except (OSError, ValueError):
        return None


class Lock:
    """Serializes every state-changing command (apply/confirm/revert/watch)."""

    def __enter__(self):
        self.fd = os.open(lock_path(), os.O_CREAT | os.O_RDWR, 0o600)
        fcntl.flock(self.fd, fcntl.LOCK_EX)
        return self

    def __exit__(self, *exc):
        fcntl.flock(self.fd, fcntl.LOCK_UN)
        os.close(self.fd)


# ---------------------------------------------------------------- model


def parse_mode(text):
    """'1920x1080@60.06Hz' -> (1920, 1080, 60.06)."""
    text = text.strip()
    if text.lower().endswith("hz"):
        text = text[:-2]
    res, _, rate = text.partition("@")
    w, _, h = res.partition("x")
    return int(w), int(h), float(rate) if rate else 0.0


def logical_size(mon):
    w = mon["width"] / mon["scale"]
    h = mon["height"] / mon["scale"]
    if mon.get("transform", 0) % 2 == 1:
        w, h = h, w
    return w, h


def valid_scales(width, height):
    """Scales Hyprland accepts without rounding: both logical sides integral."""
    out = []
    for step in range(int(MIN_SCALE * 20), int(MAX_SCALE * 20) + 1):
        s = step / 20.0
        if abs(width / s - round(width / s)) < 1e-6 and abs(height / s - round(height / s)) < 1e-6:
            out.append(s)
    return out


def scales_for(state):
    """The scale rule of the backend that produced `state` (default: the generic one)."""
    cls = BACKENDS.get(state.get("backend"))
    return cls.valid_scales if cls else valid_scales


def scale_accepted(state, scale, width, height):
    """Does the backend that produced `state` accept this scale for this mode?"""
    cls = BACKENDS.get(state.get("backend"))
    if cls is not None and "accepts_scale" in dir(cls):
        return cls.accepts_scale(scale, width, height)
    return scale in scales_for(state)(width, height)


def mode_supported(mon_state, width, height, refresh):
    for mode in mon_state.get("modes", []):
        w, h, r = mode
        if w == width and h == height and abs(r - refresh) <= REFRESH_TOLERANCE:
            return True
    return False


def lua_str(text):
    """Lua string literal. json.dumps would emit \\uXXXX, which Lua rejects."""
    out = ['"']
    for ch in text:
        if ch == '"':
            out.append('\\"')
        elif ch == "\\":
            out.append("\\\\")
        elif ord(ch) < 32 or ord(ch) == 127:
            out.append("\\%03d" % ord(ch))
        else:
            out.append(ch)
    out.append('"')
    return "".join(out)


def desc_unique(state):
    """Names of monitors whose description identifies them unambiguously.

    Hyprland matches `desc:` by prefix, so a description that equals or is a
    prefix of another monitor's description (two identical panels) must not be used.
    """
    pairs = [(m["name"], m.get("description") or "") for m in state["monitors"]]
    ok = set()
    for name, desc in pairs:
        if not desc:
            continue
        if all(o_name == name or not o_desc or not (o_desc.startswith(desc) or desc.startswith(o_desc))
               for o_name, o_desc in pairs):
            ok.add(name)
    return ok


def resolve_plan(plan, state, partial=False):
    """Map a stored plan (profile, last-good) onto the monitors connected now.

    Connector names change between boots (eDP-1 <-> eDP-2) so the panel
    description is the identity; the name is only a tie-breaker between
    identical panels and the fallback when no description was recorded.
    partial=True (profiles, rescue): absent monitors are dropped with a warning
    and connected monitors the plan does not mention keep their current setup.
    partial=False: every mismatch is an error.
    Returns (resolved_plan, errors, warnings).
    """
    errors, warnings = [], []
    if not isinstance(plan, dict) or not isinstance(plan.get("monitors"), list):
        return plan, ["plan_malformed"], warnings
    current = state["monitors"]
    by_name = {m["name"]: m for m in current}
    used, out = set(), []

    def absent(code, name):
        (warnings if partial else errors).append("%s:%s" % (code, name))

    for p in plan["monitors"]:
        if not isinstance(p, dict):
            errors.append("plan_malformed")
            continue
        name, desc = p.get("name"), p.get("description") or ""
        target = None
        if desc:
            cands = [m for m in current if m.get("description") == desc and m["name"] not in used]
            if cands:
                # Identical panels are interchangeable; prefer the same connector.
                target = next((m for m in cands if m["name"] == name), cands[0])
            elif name in by_name:
                # The connector exists but now drives a different panel.
                (warnings if partial else errors).append("monitor_identity_changed:%s" % name)
            else:
                absent("profile_monitor_absent" if partial else "unknown_monitor", name)
        else:
            target = by_name.get(name)
            if target is None or target["name"] in used:
                target = None
                absent("profile_monitor_absent" if partial else "unknown_monitor", name)
        if target is not None:
            used.add(target["name"])
            out.append(dict(p, name=target["name"], description=target.get("description", "")))

    if partial:
        keep = plan_from_state(state)["monitors"]
        out.extend(m for m in keep if m["name"] not in used)
    return {"monitors": out}, errors, warnings


def reflow_plan(old, new, name):
    """Keep neighbours attached when monitor `name` changes its logical size.

    Resolution, scale and rotation change the logical size. Everything that sat
    at or beyond the old right (bottom) edge, and was touching the monitor or a
    monitor already moved, shifts by the size difference so the layout neither
    overlaps nor opens a gap. Positions of monitors left/above stay untouched.
    """
    def rect(m):
        w, h = logical_size(m)
        return m["x"], m["y"], w, h

    old_by = {m["name"]: m for m in old["monitors"]}
    new_by = {m["name"]: m for m in new["monitors"]}
    a_old, a_new = old_by.get(name), new_by.get(name)
    if not a_old or not a_new or not a_old.get("enabled", True) or not a_new.get("enabled", True):
        return new
    ox, oy, ow, oh = rect(a_old)
    nx, ny, nw, nh = rect(a_new)
    dx, dy = round(nw - ow), round(nh - oh)
    if dx == 0 and dy == 0:
        return new

    eps = 1.0
    moved = {name: (ox, oy, ow, oh)}  # monitor -> its OLD rect, used for adjacency
    shift = {}
    changed = True
    while changed:
        changed = False
        for m in old["monitors"]:
            n = m["name"]
            if n in moved or not m.get("enabled", True):
                continue
            x, y, w, h = rect(m)
            for ax, ay, aw, ah in moved.values():
                v_overlap = y < ay + ah - eps and ay < y + h - eps
                h_overlap = x < ax + aw - eps and ax < x + w - eps
                right_of = dx and x >= ax + aw - eps and v_overlap
                below = dy and y >= ay + ah - eps and h_overlap
                if right_of or below:
                    shift[n] = (dx if right_of else 0, dy if below else 0)
                    moved[n] = (x, y, w, h)
                    changed = True
                    break
    out = []
    for m in new["monitors"]:
        sx, sy = shift.get(m["name"], (0, 0))
        out.append(dict(m, x=int(m["x"]) + sx, y=int(m["y"]) + sy) if (sx or sy) else m)
    return {"monitors": out}


def plan_from_state(state):
    return {"monitors": [{k: m[k] for k in (
        "name", "description", "enabled", "width", "height", "refresh",
        "x", "y", "scale", "transform")} for m in state["monitors"]]}


def normalize_plan(plan, state):
    """Backends that cannot place an output at x < 0 or y < 0 (mango) get the whole layout
    shifted right/down just enough that nothing is negative. Only the origin moves, the
    arrangement is the same (dragging a monitor to the left of the primary one is the usual
    way to get a negative x). Others keep the plan untouched."""
    cls = BACKENDS.get(state.get("backend"))
    if cls is None or cls.allow_negative_positions or not isinstance(plan, dict):
        return plan
    try:
        on = [p for p in plan["monitors"] if p.get("enabled", True)]
        dx = -min([int(p["x"]) for p in on] + [0])
        dy = -min([int(p["y"]) for p in on] + [0])
    except (KeyError, TypeError, ValueError, AttributeError):
        return plan      # malformed: validate() reports it
    if not dx and not dy:
        return plan
    shifted = [dict(p, x=int(p["x"]) + dx, y=int(p["y"]) + dy) if p.get("enabled", True) else p
               for p in plan["monitors"]]
    return dict(plan, monitors=shifted)


def validate(plan, state):
    """Returns (errors, warnings). Errors block the transaction."""
    errors, warnings = [], []
    if not isinstance(plan, dict) or not isinstance(plan.get("monitors"), list):
        return ["plan_malformed"], warnings

    current = {m["name"]: m for m in state["monitors"]}
    seen = set()
    enabled = []

    for p in plan["monitors"]:
        name = p.get("name")
        if not isinstance(name, str) or name not in current:
            errors.append("unknown_monitor:%s" % name)
            continue
        if name in seen:
            errors.append("duplicate_monitor:%s" % name)
            continue
        seen.add(name)
        cur = current[name]
        # A renamed connector (eDP-1 -> eDP-2) or swapped cable must not
        # receive a layout meant for a different panel.
        if p.get("description") and p["description"] != cur["description"]:
            errors.append("monitor_identity_changed:%s" % name)
            continue
        if not p.get("enabled", True):
            continue
        try:
            width, height = int(p["width"]), int(p["height"])
            refresh, scale = float(p["refresh"]), float(p["scale"])
            x, y, transform = int(p["x"]), int(p["y"]), int(p.get("transform", 0))
        except (KeyError, TypeError, ValueError):
            errors.append("monitor_fields_invalid:%s" % name)
            continue
        if not math.isfinite(refresh) or not math.isfinite(scale):
            errors.append("monitor_fields_invalid:%s" % name)
            continue
        if not mode_supported(cur, width, height, refresh):
            errors.append("mode_unsupported:%s:%dx%d@%.2f" % (name, width, height, refresh))
            continue
        if not scale_accepted(state, scale, width, height):
            errors.append("scale_invalid:%s:%s" % (name, scale))
            continue
        if transform not in range(8):
            errors.append("transform_invalid:%s" % name)
            continue
        if abs(x) > 32768 or abs(y) > 32768:
            errors.append("position_out_of_range:%s" % name)
            continue
        cls = BACKENDS.get(state.get("backend"))
        if (x < 0 or y < 0) and cls is not None and not cls.allow_negative_positions:
            errors.append("position_negative:%s" % name)
            continue
        mon = dict(p, width=width, height=height, scale=scale, transform=transform, x=x, y=y)
        lw, lh = logical_size(mon)
        # Sway reports logical sizes truncated (2560 / 1.5 -> 1706), so a neighbour at 1706 is
        # adjacent, not overlapping. Integral sizes (every Hyprland scale) are unaffected.
        lw, lh = math.floor(lw + 1e-6), math.floor(lh + 1e-6)
        enabled.append((name, x, y, x + lw, y + lh))

    for name in current:
        if name not in seen:
            errors.append("monitor_missing_from_plan:%s" % name)

    if not errors and not enabled:
        errors.append("no_enabled_monitor")

    for i in range(len(enabled)):
        for j in range(i + 1, len(enabled)):
            a, b = enabled[i], enabled[j]
            if a[1] < b[3] and b[1] < a[3] and a[2] < b[4] and b[2] < a[4]:
                errors.append("monitors_overlap:%s:%s" % (a[0], b[0]))

    if len(enabled) > 1 and not _connected(enabled):
        warnings.append("monitors_not_adjacent")

    return errors, warnings


def _connected(rects):
    def touch(a, b):
        eps = 1.0
        h_overlap = a[1] < b[3] + eps and b[1] < a[3] + eps
        v_overlap = a[2] < b[4] + eps and b[2] < a[4] + eps
        return h_overlap and v_overlap

    reached = {0}
    frontier = [0]
    while frontier:
        i = frontier.pop()
        for j in range(len(rects)):
            if j not in reached and touch(rects[i], rects[j]):
                reached.add(j)
                frontier.append(j)
    return len(reached) == len(rects)


def matches(plan, state, strict_position=True):
    current = {m["name"]: m for m in state["monitors"]}
    for p in plan["monitors"]:
        cur = current.get(p["name"])
        if cur is None:
            return False
        if bool(p.get("enabled", True)) != cur["enabled"]:
            return False
        if not cur["enabled"]:
            continue
        if (cur["width"], cur["height"]) != (int(p["width"]), int(p["height"])):
            return False
        if abs(cur["refresh"] - float(p["refresh"])) > REFRESH_TOLERANCE:
            return False
        if abs(cur["scale"] - float(p["scale"])) > 1e-3:
            return False
        if cur["transform"] != int(p.get("transform", 0)):
            return False
        if strict_position and (cur["x"], cur["y"]) != (int(p["x"]), int(p["y"])):
            return False
    return True


# ---------------------------------------------------------------- backend


class Backend:
    """What every compositor backend provides. The transaction engine (validate, snapshot,
    independent reverter, confirm/revert, rescue, profiles) only talks to this interface, so a
    new compositor means one new subclass and an entry in BACKENDS.

    state() returns the same JSON for every compositor:
        {"backend": name, "monitors": [{"name", "description" ("<make> <model> <serial>", the
         stable identity), "enabled", "width", "height", "refresh", "x", "y", "scale",
         "transform" (0-3 = 0/90/180/270), "focused", "modes": [[w, h, hz], ...]}]}
    apply() sends a whole plan live (enable first, disable last) and raises DisplayError.
    """

    name = ""
    allow_negative_positions = True   # False: the compositor cannot place an output at x/y < 0

    # --- finding the compositor
    @classmethod
    def detect(cls):
        """True when this process already runs inside (or points at) this compositor."""
        return False

    @classmethod
    def candidate(cls):
        """From a TTY: the best live instance of this user as (rank, newest-first key, activate),
        or None. Lower rank = more likely the real session (0 real, 1/2 unsure, 3 nested).
        activate() exports what the compositor's CLI needs. Ranks are comparable across
        compositors, so a nested test compositor never beats the real one of another kind."""
        return None

    @classmethod
    def discover(cls):
        """Activate this compositor's best live instance; True when there is one."""
        found = cls.candidate()
        if found is None:
            return False
        found[2]()
        return True

    # --- reading and writing the live layout
    def state(self):
        raise NotImplementedError

    def apply(self, plan):
        raise NotImplementedError

    def safe_plan(self, state):
        """Every connected output on at its best mode, laid out left to right."""
        x = 0
        monitors = []
        for m in state["monitors"]:
            if m["modes"]:
                w, h, r = max(m["modes"], key=lambda md: (md[0] * md[1], -abs(md[2] - 60)))
            else:
                w, h, r = m["width"] or 1920, m["height"] or 1080, m["refresh"] or 60.0
            monitors.append({"name": m["name"], "description": m["description"],
                             "enabled": True, "width": w, "height": h, "refresh": r,
                             "x": x, "y": 0, "scale": 1.0, "transform": 0})
            x += w
        return {"monitors": monitors}

    @staticmethod
    def valid_scales(width, height):
        """Scales the compositor accepts for this mode (default: both logical sides integral)."""
        out = []
        for step in range(int(MIN_SCALE * 20), int(MAX_SCALE * 20) + 1):
            sc = step / 20.0
            if abs(width / sc - round(width / sc)) < 1e-6 and abs(height / sc - round(height / sc)) < 1e-6:
                out.append(sc)
        return out

    @classmethod
    def accepts_scale(cls, scale, width, height):
        """Validation rule for a scale (default: it is one of valid_scales, which the UI offers)."""
        return scale in cls.valid_scales(width, height)

    # --- persistence in the compositor's own config language, in a file of ours
    def persist_path(self):
        raise NotImplementedError

    def persist_render(self, state):
        raise NotImplementedError

    def persist_verify(self, path):
        return True

    def persist_info(self):
        raise NotImplementedError

    def persist(self, state):
        return persist_file(self.persist_path(), self.persist_render(state), self.persist_verify)

    def after_persist(self, confirmed):
        """Called right after a confirmed layout was written to the boot file. A compositor that
        reloads its config on file changes may re-apply its own rules there; override to put the
        confirmed layout back. Must not raise for ordinary failures (the caller logs anything)."""


class HyprlandBackend(Backend):
    name = "hyprland"

    def __init__(self, runner=None):
        self.run = runner or self._run

    @staticmethod
    def _run(args, timeout=5):
        try:
            p = subprocess.run(args, capture_output=True, text=True, timeout=timeout)
        except (OSError, subprocess.TimeoutExpired) as e:
            return 127, "", str(e)
        return p.returncode, p.stdout, p.stderr

    def state(self):
        rc, out, err = self.run(["hyprctl", "-j", "monitors", "all"])
        if rc != 0:
            raise DisplayError("hyprctl_failed:%s" % (err.strip() or rc))
        try:
            raw = json.loads(out)
        except ValueError:
            raise DisplayError("hyprctl_bad_json")
        monitors = []
        for m in raw:
            modes = []
            for text in m.get("availableModes", []):
                try:
                    modes.append(parse_mode(text))
                except ValueError:
                    pass
            monitors.append({
                "name": m["name"],
                "description": m.get("description", ""),
                "enabled": not m.get("disabled", False),
                "width": int(m.get("width", 0)),
                "height": int(m.get("height", 0)),
                "refresh": round(float(m.get("refreshRate", 0.0)), 3),
                "x": int(m.get("x", 0)),
                "y": int(m.get("y", 0)),
                "scale": float(m.get("scale", 1.0)),
                "transform": int(m.get("transform", 0)),
                "focused": bool(m.get("focused", False)),
                "modes": modes,
            })
        monitors.sort(key=lambda m: m["name"])
        return {"backend": self.name, "monitors": monitors}

    @staticmethod
    def _lua(p):
        if not p.get("enabled", True):
            return 'hl.monitor({ output = %s, disabled = true })' % json.dumps(p["name"])
        return ('hl.monitor({ output = %s, mode = "%dx%d@%.3f", position = "%dx%d", '
                'scale = %s, transform = %d, disabled = false })') % (
            json.dumps(p["name"]), int(p["width"]), int(p["height"]), float(p["refresh"]),
            int(p["x"]), int(p["y"]), repr(float(p["scale"])), int(p.get("transform", 0)))

    @staticmethod
    def _keyword(p):
        if not p.get("enabled", True):
            return "keyword monitor %s,disable" % p["name"]
        return "keyword monitor %s,%dx%d@%.3f,%dx%d,%s,transform,%d" % (
            p["name"], int(p["width"]), int(p["height"]), float(p["refresh"]),
            int(p["x"]), int(p["y"]), repr(float(p["scale"])), int(p.get("transform", 0)))

    def apply(self, plan):
        # Enable/reconfigure first, disable last, so there is never a moment
        # in which every output is off.
        ordered = sorted(plan["monitors"], key=lambda p: 0 if p.get("enabled", True) else 1)
        script = "\n".join(self._lua(p) for p in ordered)
        rc, out, err = self.run(["hyprctl", "eval", script])
        if rc == 0 and not out.strip().startswith("error"):
            return
        log("eval failed rc=%s out=%r err=%r, trying keyword" % (rc, out.strip(), err.strip()))
        batch = " ; ".join(self._keyword(p) for p in ordered)
        rc, out, err = self.run(["hyprctl", "--batch", batch])
        if rc != 0 or "error" in out.lower():
            raise DisplayError("apply_failed:%s" % (out.strip() or err.strip() or rc))

    @classmethod
    def detect(cls):
        sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
        if not sig or inside_niri():
            return False
        # A compositor nested inside Hyprland (a test Sway window) inherits the outer
        # signature. hyprland.lock holds "pid\nwayland-socket": when we are a client of a
        # different Wayland socket, this signature is not ours.
        wl = os.environ.get("WAYLAND_DISPLAY")
        if wl:
            runtime = os.environ.get("XDG_RUNTIME_DIR") or "/run/user/%d" % os.getuid()
            try:
                with open(os.path.join(runtime, "hypr", sig, "hyprland.lock")) as f:
                    lines = f.read().split("\n")
                if len(lines) > 1 and lines[1].strip() and lines[1].strip() != os.path.basename(wl):
                    return False
                if lines[0].strip().isdigit() and serves_display(int(lines[0])) is False:
                    return False      # the socket we are a client of is served by someone else
            except OSError:
                pass
        return True

    @classmethod
    def candidate(cls):
        hypr_dir = os.path.join(os.environ.get("XDG_RUNTIME_DIR") or "/run/user/%d" % os.getuid(), "hypr")
        ranked = _ranked_hyprland_instances(hypr_dir)
        if not ranked:
            return None
        rank, age, path = ranked[0]

        def activate():
            os.environ["HYPRLAND_INSTANCE_SIGNATURE"] = os.path.basename(path)
        return rank, age, activate

    def persist_path(self):
        return persist_path()

    def persist_render(self, state):
        return render_lua(state)

    def persist_verify(self, path):
        return verify_lua(path)

    def persist_info(self):
        return persist_info()

    def persist(self, state):
        return persist(state)


def _instance_pid(path):
    try:
        with open(os.path.join(path, "hyprland.lock")) as f:
            return int(f.readline().strip())
    except (OSError, ValueError):
        return None


def _pid_alive(pid):
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        return True
    return True


def _pid_is_nested(pid):
    """A nested Hyprland (a test window inside another compositor) is a Wayland client, so
    its environment carries WAYLAND_DISPLAY; a session started from a TTY/greeter has none."""
    try:
        with open("/proc/%d/environ" % pid, "rb") as f:
            return any(v.startswith(b"WAYLAND_DISPLAY=") for v in f.read().split(b"\0"))
    except OSError:
        return False


VIRTUAL_OUTPUT = re.compile(r"^((WAYLAND|HEADLESS|X11)-\d+|winit)$")


def instance_outputs(signature):
    """Output names of one Hyprland instance, or None when it does not answer in time."""
    env = dict(os.environ, HYPRLAND_INSTANCE_SIGNATURE=signature)
    try:
        p = subprocess.run(["hyprctl", "-j", "monitors", "all"], capture_output=True,
                           text=True, timeout=2, env=env)
        if p.returncode != 0:
            return None
        return [m["name"] for m in json.loads(p.stdout)]
    except (OSError, subprocess.TimeoutExpired, ValueError, KeyError, TypeError):
        return None


def _ranked_hyprland_instances(hypr_dir):
    """[(rank, -mtime, path)] best first; see find_hyprland_instances for the ranking."""
    found = []
    try:
        names = os.listdir(hypr_dir)
    except OSError:
        return []
    for d in names:
        path = os.path.join(hypr_dir, d)
        if not os.path.exists(os.path.join(path, ".socket.sock")):
            continue
        pid = _instance_pid(path)
        if pid is not None and not _pid_alive(pid):
            continue  # stale directory left by a crashed compositor
        outputs = instance_outputs(d)
        if outputs is not None:
            rank = 0 if any(not VIRTUAL_OUTPUT.match(n) for n in outputs) else 3
        else:
            rank = 2 if (pid is not None and _pid_is_nested(pid)) else 1
        found.append((rank, -os.path.getmtime(path), path))
    return sorted(found)


def find_hyprland_instances(hypr_dir):
    """Live instances of this user, best first. Used when the signature variable is missing
    (TTY rescue), where picking a nested test instance would repair the wrong screens.

    1. real: it has an output that is not WAYLAND-n / HEADLESS-n / X11-n (a nested
       compositor only has those). This is the reliable signal.
    2. otherwise, when the instance does not answer: not a Wayland client, judged by the
       environment of its process.
    3. ties: the newest.
    A nested instance is still returned, last, so a lone one stays usable."""
    return [p for _, _, p in _ranked_hyprland_instances(hypr_dir)]


# ---------------------------------------------------------------- Sway

# wl_output transform numbering, the same as Hyprland's: 0-3 rotations, 4-7 the flipped ones.
SWAY_TRANSFORMS = ["normal", "90", "180", "270", "flipped", "flipped-90", "flipped-180", "flipped-270"]
# Virtual (HEADLESS-n) outputs list no modes at all and accept any custom one.
VIRTUAL_MODES = [(1280, 720), (1920, 1080), (2560, 1440), (3840, 2160)]
SWAY_SOCKET = re.compile(r"^sway-ipc\.(\d+)\.(\d+)\.sock$")


def sway_config_dir():
    base = os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config")
    return os.path.join(base, "sway")


def sway_str(text):
    """Sway config / command string literal."""
    return '"%s"' % text.replace("\\", "\\\\").replace('"', '\\"')


def find_sway_binary():
    found = shutil.which("sway")
    if found:
        return found
    ctl = shutil.which("swaymsg")
    if ctl:
        for base in (os.path.dirname(os.path.realpath(ctl)), os.path.dirname(ctl)):
            sibling = os.path.join(base, "sway")
            if os.access(sibling, os.X_OK):
                return sibling
    return None


def verify_sway(path):
    """Reject a file sway would fail to load (a broken included file breaks the whole config)."""
    binary = find_sway_binary()
    if not binary:
        log("verify skipped: sway executable not found (PATH, next to swaymsg)")
        return True
    try:
        p = subprocess.run([binary, "--validate", "-c", path], capture_output=True, text=True, timeout=15)
    except (OSError, subprocess.TimeoutExpired):
        return False
    return p.returncode == 0


def sway_instance_outputs(sock):
    """Output names of one sway instance, or None when it does not answer in time."""
    try:
        p = subprocess.run(["swaymsg", "-r", "-t", "get_outputs"], capture_output=True, text=True,
                           timeout=2, env=dict(os.environ, SWAYSOCK=sock))
        if p.returncode != 0:
            return None
        return [o["name"] for o in json.loads(p.stdout)]
    except (OSError, subprocess.TimeoutExpired, ValueError, KeyError, TypeError):
        return None


def _ranked_sway_instances(run_dir):
    """[(rank, -mtime, socket)] best first, with the same real-vs-nested logic as Hyprland:
    a real session has a non-virtual output; a nested/headless one only WAYLAND-n/HEADLESS-n."""
    found = []
    try:
        names = os.listdir(run_dir)
    except OSError:
        return []
    for n in names:
        m = SWAY_SOCKET.match(n)
        if not m or int(m.group(1)) != os.getuid():
            continue
        pid = int(m.group(2))
        if not _pid_alive(pid):
            continue  # stale socket of a crashed sway
        sock = os.path.join(run_dir, n)
        outputs = sway_instance_outputs(sock)
        if outputs is not None:
            rank = 0 if any(not VIRTUAL_OUTPUT.match(o) for o in outputs) else 3
        else:
            rank = 2 if _pid_is_nested(pid) else 1
        try:
            found.append((rank, -os.path.getmtime(sock), sock))
        except OSError:
            pass
    return sorted(found)


class SwayBackend(Backend):
    name = "sway"

    def __init__(self, runner=None):
        self.run = runner or HyprlandBackend._run
        self._custom = set()   # outputs that list no modes: their modes must be sent as --custom

    # --- finding the compositor
    @classmethod
    def detect(cls):
        sock = os.environ.get("SWAYSOCK")
        if not sock or not os.path.exists(sock) or inside_niri() or inside_mango():
            return False
        m = SWAY_SOCKET.match(os.path.basename(sock))
        return not (m and serves_display(int(m.group(2))) is False)

    @classmethod
    def candidate(cls):
        ranked = _ranked_sway_instances(os.environ.get("XDG_RUNTIME_DIR") or "/run/user/%d" % os.getuid())
        if not ranked:
            return None
        rank, age, sock = ranked[0]

        def activate():
            os.environ["SWAYSOCK"] = sock
        return rank, age, activate

    # --- live layout
    def state(self):
        rc, out, err = self.run(["swaymsg", "-r", "-t", "get_outputs"])
        if rc != 0:
            raise DisplayError("swaymsg_failed:%s" % (err.strip() or rc))
        try:
            raw = json.loads(out)
        except ValueError:
            raise DisplayError("swaymsg_bad_json")
        monitors, custom = [], set()
        for o in raw:
            if o.get("non_desktop"):
                continue          # VR headsets and the like are not part of the desktop layout
            name = o["name"]
            modes = []
            for md in o.get("modes", []):
                item = (int(md["width"]), int(md["height"]), round(md["refresh"] / 1000.0, 3))
                if item not in modes:
                    modes.append(item)
            cm = o.get("current_mode")
            cur = (int(cm["width"]), int(cm["height"]), round(cm["refresh"] / 1000.0, 3) or 60.0) if cm else None
            if not modes:
                custom.add(name)
                modes = [(w, h, 60.0) for w, h in VIRTUAL_MODES]
            if cur and cur not in modes:
                modes.insert(0, cur)
            if cur is None:   # disabled: report the best mode, so it can be switched back on
                cur = (1920, 1080, 60.0) if name in custom else max(modes, key=lambda md: (md[0] * md[1], md[2]))
            ident = [str(o.get(k) or "") for k in ("make", "model", "serial")]
            desc = "" if all(v in ("", "Unknown") for v in ident) else " ".join(ident)
            rect = o.get("rect") or {}
            enabled = bool(o.get("active"))
            try:
                transform = SWAY_TRANSFORMS.index(o.get("transform") or "normal")
            except ValueError:
                transform = 0
            monitors.append({
                "name": name,
                "description": desc,
                "enabled": enabled,
                "width": cur[0], "height": cur[1], "refresh": cur[2],
                "x": int(rect.get("x", 0)) if enabled else 0,
                "y": int(rect.get("y", 0)) if enabled else 0,
                "scale": float(o.get("scale") or 1.0),
                "transform": transform,
                "focused": bool(o.get("focused", False)),
                "modes": [list(md) for md in modes],
            })
        self._custom = custom
        monitors.sort(key=lambda m: m["name"])
        return {"backend": self.name, "monitors": monitors}

    @staticmethod
    def valid_scales(width, height):
        # Sway takes fractional scales; quarter steps are what the UI offers.
        return [step / 4.0 for step in range(2, 17)]

    @classmethod
    def accepts_scale(cls, scale, width, height):
        # An existing config may use e.g. 1.1; keep it valid rather than forcing a change.
        return math.isfinite(scale) and MIN_SCALE <= scale <= MAX_SCALE

    def _command(self, p):
        name = p["name"]
        if not isinstance(name, str) or not re.match(r"^[\w.:+-]+$", name):
            raise DisplayError("apply_failed:bad_output_name")
        if not p.get("enabled", True):
            return "output %s disable" % name
        t = int(p.get("transform", 0))
        return "output %s enable mode %s%dx%d@%.3fHz position %d %d scale %s transform %s" % (
            name, "--custom " if name in self._custom else "", int(p["width"]), int(p["height"]),
            float(p["refresh"]), int(p["x"]), int(p["y"]), repr(float(p["scale"])), SWAY_TRANSFORMS[t])

    def apply(self, plan):
        if not self._custom:
            self.state()    # learn which outputs need --custom modes
        # Enable/reconfigure first, disable last, so there is never a moment with every output off.
        ordered = sorted(plan["monitors"], key=lambda p: 0 if p.get("enabled", True) else 1)
        script = "; ".join(self._command(p) for p in ordered)
        rc, out, err = self.run(["swaymsg", "-r", "--", script])
        try:
            results = json.loads(out)
        except ValueError:
            results = None
        if rc != 0 or not isinstance(results, list):
            raise DisplayError("apply_failed:%s" % (err.strip() or out.strip() or rc))
        for r in results:
            if not r.get("success", False):
                raise DisplayError("apply_failed:%s" % r.get("error", "unknown"))

    # --- persistence (~/.config/sway/serpantinum/monitors, opt-in with an include line)
    def persist_path(self):
        return os.path.join(sway_config_dir(), "serpantinum", "monitors")

    def persist_render(self, state):
        blocks = [SWAY_PERSIST_HEADER]
        unique = desc_unique(state)
        for m in state["monitors"]:
            if not m["enabled"]:
                continue
            desc = m.get("description", "")
            usable = m["name"] in unique and not re.search(r'["\\\n\r{}#]', desc)
            ident = desc if usable else m["name"]
            blocks.append(
                "# %s (%s)\noutput %s {\n    mode %dx%d@%.3fHz\n    position %d %d\n    scale %s\n"
                "    transform %s\n}\n" % (
                    desc.replace("\n", " ").replace("\r", " "), m["name"], sway_str(ident),
                    m["width"], m["height"], m["refresh"], m["x"], m["y"],
                    repr(float(m["scale"])), SWAY_TRANSFORMS[m["transform"]]))
        return "\n".join(blocks)

    def persist_verify(self, path):
        return verify_sway(path)

    def persist_info(self):
        included = False
        root = sway_config_dir()
        for dirpath, _, files in os.walk(root):
            if os.path.relpath(dirpath, root).startswith("serpantinum"):
                continue
            for fname in files:
                try:
                    with open(os.path.join(dirpath, fname), encoding="utf-8", errors="replace") as f:
                        for line in f:
                            code = line.strip()
                            if code.startswith("include") and "serpantinum/monitors" in code:
                                included = True
                except OSError:
                    pass
        path = self.persist_path()
        return {"path": path, "exists": os.path.exists(path), "included": included,
                "managed": config_is_managed(root, "config"), "writable": _can_create(path)}


SWAY_PERSIST_HEADER = """# Generated by Serpantinum display settings. Do not edit manually:
# changes made from Settings > Display overwrite this file.
# Load it from your sway config AFTER your own output rules:
#     include ~/.config/sway/serpantinum/monitors
# Disabled outputs are intentionally not saved, so a missing screen at boot
# can never leave you without any enabled output.
"""


# ---------------------------------------------------------------- Niri

NIRI_TRANSFORMS = SWAY_TRANSFORMS   # niri's CLI/KDL names are the same words, same wl_output order
NIRI_SOCKET = re.compile(r"^niri\.(.+)\.(\d+)\.sock$")


def niri_config_dir():
    base = os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config")
    return os.path.join(base, "niri")


def kdl_str(text):
    """KDL string literal."""
    return '"%s"' % text.replace("\\", "\\\\").replace('"', '\\"')


def inside_niri():
    """True when this process is a client of the niri that NIRI_SOCKET names. Niri puts its
    Wayland display in the socket name (niri.wayland-2.<pid>.sock), so a compositor nested
    inside niri, which inherits NIRI_SOCKET, can tell it is not niri itself."""
    sock = os.environ.get("NIRI_SOCKET")
    if not sock or not os.path.exists(sock):
        return False
    m = NIRI_SOCKET.match(os.path.basename(sock))
    wl = os.environ.get("WAYLAND_DISPLAY")
    if m and wl:
        return m.group(1) == os.path.basename(wl) and serves_display(int(m.group(2))) is not False
    return True


def parse_niri_transform(value):
    """'Normal', '_90', '90', 'Flipped180', 'flipped-270' -> 0..7 (unknown -> 0, logged)."""
    key = re.sub(r"[_\-\s]", "", str(value or "normal")).lower()
    names = [t.replace("-", "") for t in NIRI_TRANSFORMS]
    if key in names:
        return names.index(key)
    log("niri: unknown transform %r, treated as normal" % (value,))
    return 0


def find_niri_binary():
    found = shutil.which("niri")
    if found:
        return found
    return None


def verify_niri(path):
    """Reject a file niri would fail to load (a broken included file breaks the whole config)."""
    binary = find_niri_binary()
    if not binary:
        log("verify skipped: niri executable not found")
        return True
    try:
        p = subprocess.run([binary, "validate", "-c", path], capture_output=True, text=True, timeout=15)
    except (OSError, subprocess.TimeoutExpired):
        return False
    return p.returncode == 0


def niri_instance_outputs(sock):
    """Output names of one niri instance, or None when it does not answer in time."""
    try:
        p = subprocess.run(["niri", "msg", "-j", "outputs"], capture_output=True, text=True,
                           timeout=2, env=dict(os.environ, NIRI_SOCKET=sock))
        if p.returncode != 0:
            return None
        return list(json.loads(p.stdout).keys())
    except (OSError, subprocess.TimeoutExpired, ValueError, AttributeError):
        return None


def _ranked_niri_instances(run_dir):
    """[(rank, -mtime, socket)] best first; same real-vs-nested logic as the other backends
    (a nested niri's only output is called "winit")."""
    found = []
    try:
        names = os.listdir(run_dir)
    except OSError:
        return []
    for n in names:
        m = NIRI_SOCKET.match(n)
        if not m:
            continue
        pid = int(m.group(2))
        if not _pid_alive(pid):
            continue
        sock = os.path.join(run_dir, n)
        try:
            if os.stat(sock).st_uid != os.getuid():
                continue
        except OSError:
            continue
        outputs = niri_instance_outputs(sock)
        if outputs is not None:
            rank = 0 if any(not VIRTUAL_OUTPUT.match(o) for o in outputs) else 3
        else:
            rank = 2 if _pid_is_nested(pid) else 1
        found.append((rank, -os.path.getmtime(sock), sock))
    return sorted(found)


class NiriBackend(Backend):
    name = "niri"

    def __init__(self, runner=None):
        self.run = runner or HyprlandBackend._run

    @classmethod
    def detect(cls):
        sock = os.environ.get("NIRI_SOCKET")
        if not sock or not os.path.exists(sock):
            return False
        return inside_niri()

    @classmethod
    def candidate(cls):
        ranked = _ranked_niri_instances(os.environ.get("XDG_RUNTIME_DIR") or "/run/user/%d" % os.getuid())
        if not ranked:
            return None
        rank, age, sock = ranked[0]

        def activate():
            os.environ["NIRI_SOCKET"] = sock
        return rank, age, activate

    def state(self):
        rc, out, err = self.run(["niri", "msg", "-j", "outputs"])
        if rc != 0:
            raise DisplayError("niri_failed:%s" % (err.strip() or rc))
        try:
            raw = json.loads(out)
        except ValueError:
            raise DisplayError("niri_bad_json")
        if not isinstance(raw, dict):
            raise DisplayError("niri_bad_json")
        monitors = []
        for name, o in raw.items():
            modes = []
            for md in o.get("modes") or []:
                item = [int(md["width"]), int(md["height"]), round(md["refresh_rate"] / 1000.0, 3)]
                if item not in modes:
                    modes.append(item)
            idx = o.get("current_mode")
            logical = o.get("logical")
            enabled = idx is not None and logical is not None and 0 <= idx < len(o.get("modes") or [])
            if enabled:
                cm = o["modes"][idx]
                cur = (int(cm["width"]), int(cm["height"]), round(cm["refresh_rate"] / 1000.0, 3))
            elif modes:   # off: report the best mode so the output can be switched back on
                cur = tuple(max(modes, key=lambda md: (md[0] * md[1], md[2])))
            else:
                cur = (0, 0, 0.0)
            ident = [str(o.get(k) or "") for k in ("make", "model", "serial")]
            ident[2] = ident[2] or "Unknown"
            desc = "" if all(v in ("", "Unknown") for v in ident) else " ".join(v or "Unknown" for v in ident)
            monitors.append({
                "name": o.get("name", name),
                "description": desc,
                "enabled": enabled,
                "width": cur[0], "height": cur[1], "refresh": cur[2],
                "x": int(logical["x"]) if enabled else 0,
                "y": int(logical["y"]) if enabled else 0,
                "scale": float(logical["scale"]) if enabled else 1.0,
                "transform": parse_niri_transform(logical.get("transform")) if enabled else 0,
                "focused": False,
                "modes": modes,
            })
        monitors.sort(key=lambda m: m["name"])
        return {"backend": self.name, "monitors": monitors}

    @staticmethod
    def valid_scales(width, height):
        return SwayBackend.valid_scales(width, height)   # fractional scales, quarter steps

    @classmethod
    def accepts_scale(cls, scale, width, height):
        return SwayBackend.accepts_scale(scale, width, height)

    def _commands(self, p):
        name = p["name"]
        if not isinstance(name, str) or not re.match(r"^[\w.:+-]+$", name):
            raise DisplayError("apply_failed:bad_output_name")
        if not p.get("enabled", True):
            return [["niri", "msg", "output", name, "off"]]
        t = int(p.get("transform", 0))
        base = ["niri", "msg", "output", name]
        return [base + ["on"],
                base + ["mode", "%dx%d@%.3f" % (int(p["width"]), int(p["height"]), float(p["refresh"]))],
                base + ["scale", repr(float(p["scale"]))],
                base + ["transform", NIRI_TRANSFORMS[t]],
                base + ["position", "set", str(int(p["x"])), str(int(p["y"]))]]

    def apply(self, plan):
        # niri msg has no batch: one process per change. Enable/reconfigure first, disable last.
        # niri answers rc=0 even for an unknown output ("will apply when it is connected"), so
        # the caller's verification against state() is the real check; the text is only a hint.
        ordered = sorted(plan["monitors"], key=lambda p: 0 if p.get("enabled", True) else 1)
        commands = [c for p in ordered for c in self._commands(p)]
        for args in commands:
            rc, out, err = self.run(args)
            text = (out + err).strip()
            if rc != 0 or "not connected" in text:
                raise DisplayError("apply_failed:%s" % (text or rc))

    # --- persistence (~/.config/niri/serpantinum/monitors.kdl, opt-in with an include line)
    def persist_path(self):
        return os.path.join(niri_config_dir(), "serpantinum", "monitors.kdl")

    def persist_render(self, state):
        blocks = [NIRI_PERSIST_HEADER]
        unique = desc_unique(state)
        for m in state["monitors"]:
            if not m["enabled"]:
                continue
            desc = m.get("description", "")
            usable = m["name"] in unique and not re.search(r'[\x00-\x1f\x7f"\\{}#;/]', desc)
            ident = desc if usable else m["name"]
            blocks.append(
                "// %s (%s)\noutput %s {\n    mode %s\n    scale %s\n    transform %s\n"
                "    position x=%d y=%d\n}\n" % (
                    desc.replace("\n", " ").replace("\r", " "), m["name"], kdl_str(ident),
                    kdl_str("%dx%d@%.3f" % (m["width"], m["height"], m["refresh"])),
                    repr(float(m["scale"])), kdl_str(NIRI_TRANSFORMS[m["transform"]]), m["x"], m["y"]))
        return "\n".join(blocks)

    def persist_verify(self, path):
        return verify_niri(path)

    def persist_info(self):
        included = False
        root = niri_config_dir()
        for dirpath, _, files in os.walk(root):
            if os.path.relpath(dirpath, root).startswith("serpantinum"):
                continue
            for fname in files:
                if not fname.endswith(".kdl"):
                    continue
                try:
                    with open(os.path.join(dirpath, fname), encoding="utf-8", errors="replace") as f:
                        for line in f:
                            if re.match(r'^\s*include\s+"[^"]*serpantinum/monitors\.kdl"', line):
                                included = True
                except OSError:
                    pass
        path = self.persist_path()
        return {"path": path, "exists": os.path.exists(path), "included": included,
                "managed": config_is_managed(root, "config.kdl"), "writable": _can_create(path)}


NIRI_PERSIST_HEADER = """// Generated by Serpantinum display settings. Do not edit manually:
// changes made from Settings > Display overwrite this file.
// Load it from your niri config AFTER your own output rules:
//     include "serpantinum/monitors.kdl"
// Disabled outputs are intentionally not saved, so a missing screen at boot
// can never leave you without any enabled output.
"""


# ---------------------------------------------------------------- Mango

# Mango (mangowm) has no JSON monitor query (`mmsg get all-monitors` lacks modes, make, model,
# serial and its "active" means "focused"), so the layout is read and written with wlr-randr,
# which talks the standard wlr-output-management protocol to the compositor's Wayland socket.
MANGO_TRANSFORMS = SWAY_TRANSFORMS      # wlr-randr's --transform words, same wl_output order
MANGO_SOCKET = re.compile(r"^mango-(\d+)\.sock$")
WAYLAND_SOCKET = re.compile(r"^wayland-\d+$")
MANGO_SOURCE_LINE = "source_optional=./serpantinum/monitors.conf"
# Characters Mango's one-line parser (or its "#" comments, "$var" expansion and ","/":"
# splitting) would misread inside a monitor_rule value.
MANGO_UNSAFE_VALUE = re.compile(r"[\x00-\x1f\x7f#,:$\\\"'=]")


def mango_config_dir():
    # Mango reads $HOME/.config/mango (it ignores XDG_CONFIG_HOME).
    return os.path.join(os.path.expanduser("~"), ".config", "mango")


def socket_owner_pid(path):
    """PID of the process that listens on a Unix socket (SO_PEERCRED), or None."""
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    try:
        s.settimeout(1.0)
        s.connect(path)
        pid, _uid, _gid = struct.unpack("3i", s.getsockopt(socket.SOL_SOCKET, socket.SO_PEERCRED,
                                                           struct.calcsize("3i")))
        return pid
    except OSError:
        return None
    finally:
        s.close()


def mango_signature_pid(sig):
    """PID in a MANGO_INSTANCE_SIGNATURE (the IPC socket path) when that mango is alive."""
    if not sig or not os.path.exists(sig):
        return None
    m = MANGO_SOCKET.match(os.path.basename(sig))
    if not m or not _pid_alive(int(m.group(1))):
        return None
    return int(m.group(1))


def _wayland_path(value, run_dir):
    return value if os.path.isabs(value) else os.path.join(run_dir, value)


def serves_display(pid):
    """Positive proof of which compositor a process belongs to: is the socket WAYLAND_DISPLAY
    names served by `pid`? True / False when the socket answers, None when it cannot be told
    (no WAYLAND_DISPLAY, e.g. a TTY, or the socket does not answer). A variable inherited from
    another session or a nested compositor never gets past a False."""
    wl = os.environ.get("WAYLAND_DISPLAY")
    if not wl or not pid:
        return None
    run = os.environ.get("XDG_RUNTIME_DIR") or "/run/user/%d" % os.getuid()
    owner = socket_owner_pid(_wayland_path(wl, run))
    return None if owner is None else owner == pid


def mango_display_of(pid, run_dir):
    """The Wayland display (wayland-N) whose server is mango process `pid`, or None."""
    try:
        names = sorted(os.listdir(run_dir))
    except OSError:
        return None
    for n in names:
        path = os.path.join(run_dir, n)
        try:
            if WAYLAND_SOCKET.match(n) and stat.S_ISSOCK(os.stat(path).st_mode) and socket_owner_pid(path) == pid:
                return n
        except OSError:
            continue
    return None


def inside_mango():
    """True when this process is a client of the mango its MANGO_INSTANCE_SIGNATURE names: the
    Wayland socket it connects to must really be served by that mango's PID. A compositor
    nested inside mango inherits the signature but has its own socket, so it is not mistaken
    for mango (the same trick as inside_niri)."""
    pid = mango_signature_pid(os.environ.get("MANGO_INSTANCE_SIGNATURE"))
    wl = os.environ.get("WAYLAND_DISPLAY")
    if not pid or not wl:
        return False
    run = os.environ.get("XDG_RUNTIME_DIR") or "/run/user/%d" % os.getuid()
    return socket_owner_pid(_wayland_path(wl, run)) == pid


def find_mango_binary():
    return shutil.which("mango")


def verify_mango(path):
    """Reject a file mango would fail to load (`mango -p` checks a config and exits)."""
    binary = find_mango_binary()
    if not binary:
        log("verify skipped: mango executable not found")
        return True
    try:
        with tempfile.TemporaryDirectory() as tmp:
            probe = os.path.join(tmp, "monitors.conf")   # the extension selects the .conf parser
            shutil.copyfile(path, probe)
            p = subprocess.run([binary, "-p", "-c", probe], capture_output=True, text=True, timeout=15)
    except (OSError, subprocess.TimeoutExpired):
        return False
    return p.returncode == 0


def mango_instance_outputs(display):
    """Output names of the mango served on `display`, or None when wlr-randr does not answer."""
    try:
        p = subprocess.run(["wlr-randr", "--json"], capture_output=True, text=True, timeout=2,
                           env=dict(os.environ, WAYLAND_DISPLAY=display))
        if p.returncode != 0:
            return None
        return [o["name"] for o in json.loads(p.stdout)]
    except (OSError, subprocess.TimeoutExpired, ValueError, KeyError, TypeError):
        return None


def _ranked_mango_instances(run_dir):
    """[(rank, -mtime, socket, display)] best first; the same real-vs-nested logic as the other
    backends. An instance whose Wayland display cannot be found is skipped: without it
    wlr-randr could not be pointed at that mango and not at some other compositor."""
    found = []
    try:
        names = os.listdir(run_dir)
    except OSError:
        return []
    for n in names:
        m = MANGO_SOCKET.match(n)
        if not m:
            continue
        pid = int(m.group(1))
        sock = os.path.join(run_dir, n)
        try:
            if not _pid_alive(pid) or os.stat(sock).st_uid != os.getuid():
                continue
            display = mango_display_of(pid, run_dir)
            if display is None:
                continue
            outputs = mango_instance_outputs(display)
            if outputs is not None:
                rank = 0 if any(not VIRTUAL_OUTPUT.match(o) for o in outputs) else 3
            else:
                rank = 2 if _pid_is_nested(pid) else 1
            found.append((rank, -os.path.getmtime(sock), sock, display))
        except OSError:
            continue
    return sorted(found)


class MangoBackend(Backend):
    name = "mango"
    allow_negative_positions = False   # mango's layout does not take them (rule x/y are >= 0)

    def __init__(self, runner=None):
        self._guarded = runner is None
        self.run = runner or HyprlandBackend._run
        self._raw = {}      # output -> {(w, h, shown refresh): raw refresh} for the --mode argument
        self._ident = {}    # output -> (make, model, serial) as wlr-randr reports them
        self._powered = {}  # output -> enabled when state() last ran
        sig = os.environ.get("MANGO_INSTANCE_SIGNATURE")
        self._pid = mango_signature_pid(sig) if self._guarded else None

    # --- finding the compositor
    @classmethod
    def detect(cls):
        return inside_mango()

    @classmethod
    def candidate(cls):
        ranked = _ranked_mango_instances(os.environ.get("XDG_RUNTIME_DIR") or "/run/user/%d" % os.getuid())
        if not ranked:
            return None
        rank, age, sock, display = ranked[0]

        def activate():
            os.environ["MANGO_INSTANCE_SIGNATURE"] = sock
            os.environ["WAYLAND_DISPLAY"] = display
        return rank, age, activate

    def _check_target(self):
        """wlr-randr talks to whatever WAYLAND_DISPLAY says: refuse unless that socket is served
        by the mango this backend was created for (a restarted or swapped compositor)."""
        if not self._guarded:
            return
        if shutil.which("wlr-randr") is None:
            raise DisplayError("wlr_randr_missing")
        wl = os.environ.get("WAYLAND_DISPLAY")
        run = os.environ.get("XDG_RUNTIME_DIR") or "/run/user/%d" % os.getuid()
        if not self._pid or not wl or socket_owner_pid(_wayland_path(wl, run)) != self._pid:
            raise DisplayError("mango_target_mismatch")

    # --- live layout
    def state(self):
        self._check_target()
        rc, out, err = self.run(["wlr-randr", "--json"])
        if rc != 0:
            raise DisplayError("wlr_randr_failed:%s" % (err.strip() or rc))
        try:
            raw = json.loads(out)
        except ValueError:
            raise DisplayError("wlr_randr_bad_json")
        if not isinstance(raw, list):
            raise DisplayError("wlr_randr_bad_json")
        monitors, rawmodes, idents, powered = [], {}, {}, {}
        for o in raw:
            name = o["name"]
            modes, table, cur = [], {}, None
            for md in o.get("modes") or []:
                shown = round(float(md["refresh"]), 3) or 60.0   # virtual outputs report 0 Hz
                item = (int(md["width"]), int(md["height"]), shown)
                table[item] = float(md["refresh"])
                if item not in modes:
                    modes.append(item)
                if md.get("current"):
                    cur = item
            enabled = bool(o.get("enabled"))
            if cur is None or not enabled:
                preferred = [(int(md["width"]), int(md["height"]), round(float(md["refresh"]), 3) or 60.0)
                             for md in o.get("modes") or [] if md.get("preferred")]
                if enabled and cur is None:
                    cur = modes[0] if modes else (0, 0, 0.0)
                elif preferred:
                    cur = preferred[0]
                elif modes:
                    cur = max(modes, key=lambda md: (md[0] * md[1], md[2]))
                else:
                    # A virtual output lists no modes while it is off: show a placeholder and let
                    # the compositor choose the mode when it is switched back on (no --mode).
                    cur = (1920, 1080, 60.0)
                    modes = [cur]
            ident = tuple(str(o.get(k) or "") for k in ("make", "model", "serial"))
            desc = "" if not any(ident) else " ".join(v or "Unknown" for v in ident)
            pos = o.get("position") or {}
            tf = str(o.get("transform") or "normal")
            monitors.append({
                "name": name,
                "description": desc,
                "enabled": enabled,
                "width": cur[0], "height": cur[1], "refresh": cur[2],
                "x": int(pos.get("x", 0)) if enabled else 0,
                "y": int(pos.get("y", 0)) if enabled else 0,
                "scale": float(o.get("scale") or 1.0),
                "transform": MANGO_TRANSFORMS.index(tf) if tf in MANGO_TRANSFORMS else 0,
                "focused": False,     # wlr-randr cannot tell (mmsg's "active" is focus, not power)
                "modes": [list(md) for md in modes],
            })
            rawmodes[name] = table
            idents[name] = ident
            powered[name] = enabled
        self._raw, self._ident, self._powered = rawmodes, idents, powered
        monitors.sort(key=lambda m: m["name"])
        return {"backend": self.name, "monitors": monitors}

    @staticmethod
    def valid_scales(width, height):
        return SwayBackend.valid_scales(width, height)   # fractional scales, quarter steps

    @classmethod
    def accepts_scale(cls, scale, width, height):
        return SwayBackend.accepts_scale(scale, width, height)

    def _mode_arg(self, p):
        """The --mode value, or None for an output that lists no modes (the compositor picks)."""
        if not self._raw.get(p["name"]):
            return None
        w, h, r = int(p["width"]), int(p["height"]), float(p["refresh"])
        for (mw, mh, shown), raw in self._raw.get(p["name"], {}).items():
            if (mw, mh) == (w, h) and abs(shown - r) <= REFRESH_TOLERANCE:
                return "%dx%d@%.3f" % (w, h, raw) if raw > 0 else "%dx%d" % (w, h)
        return "%dx%d@%.3f" % (w, h, r)

    def _arguments(self, plan):
        """(enable_args, position_args, disable_args): wlr-randr arguments for the phases."""
        on, off, positions, woke = [], [], [], False
        for p in plan["monitors"]:
            name = p["name"]
            if not isinstance(name, str) or not re.match(r"^[\w.:+-]+$", name):
                raise DisplayError("apply_failed:bad_output_name")
            if not p.get("enabled", True):
                off += ["--output", name, "--off"]
                continue
            mode = self._mode_arg(p)
            on += ["--output", name, "--on"] + (["--mode", mode] if mode else []) + [
                   "--pos", "%d,%d" % (int(p["x"]), int(p["y"])),
                   "--scale", repr(float(p["scale"])),
                   "--transform", MANGO_TRANSFORMS[int(p.get("transform", 0))]]
            woke = woke or not self._powered.get(name, True)
            positions += ["--output", name, "--pos", "%d,%d" % (int(p["x"]), int(p["y"]))]
        # Mango auto-places an output that was off (to the right of the others) whatever --pos
        # the same request carried, and may shift others to make room: a second request sets the
        # position of EVERY enabled output for real (idempotent for the ones that did not move).
        pos = positions if woke else []
        return on, pos, off

    def _wlr(self, args):
        rc, out, err = self.run(["wlr-randr"] + args)
        text = (out + err).strip()
        if rc != 0:
            raise DisplayError("apply_failed:%s" % (text or rc))

    def apply(self, plan):
        # Mango applies the outputs of one request one by one in its own order, carries on
        # after a failure and does not stop the last enabled output from being turned off. So:
        # check EVERYTHING with --dryrun first (a rejected plan changes nothing), then enable /
        # reconfigure in one call (then fix the position of outputs that were off), and only
        # then disable in a last one.
        self._check_target()
        if not any(p.get("enabled", True) for p in plan["monitors"]):
            raise DisplayError("apply_failed:no_enabled_output")
        self.state()      # always fresh: which outputs are off now, and each mode's exact refresh
        on, pos, off = self._arguments(plan)
        for args in (on, pos, off):
            if args:
                self._wlr(["--dryrun"] + args)
        for args in (on, pos, off):
            if args:
                self._wlr(args)

    # --- persistence (~/.config/mango/serpantinum/monitors.conf, opt-in with source lines)
    def persist_path(self):
        return os.path.join(mango_config_dir(), "serpantinum", "monitors.conf")

    def _identity(self, m, state):
        """The rule selector for one output: make+model+serial when they identify it uniquely
        and are safe to write on a rule line, else the connector name (an anchored regex)."""
        name = m["name"]
        ident = self._ident.get(name)
        if ident and all(ident) and not any(MANGO_UNSAFE_VALUE.search(v) or v != v.strip() for v in ident):
            others = [self._ident.get(o["name"]) for o in state["monitors"] if o["name"] != name]
            if ident not in others:
                return "make:%s,model:%s,serial:%s" % ident
        return "name:^%s$" % re.escape(name)

    def persist_render(self, state):
        blocks = [MANGO_PERSIST_HEADER]
        for m in state["monitors"]:
            if not m["enabled"]:
                continue
            name = m["name"]
            if MANGO_UNSAFE_VALUE.search(name):
                blocks.append("# %s: name not safe to write in a rule, skipped\n" % name.replace("\n", " "))
                continue
            line = "monitor_rule=%s,width:%d,height:%d,refresh:%.3f,x:%d,y:%d,scale:%s,rr:%d" % (
                self._identity(m, state), m["width"], m["height"], m["refresh"],
                max(0, m["x"]), max(0, m["y"]), repr(float(m["scale"])), m["transform"])
            if len(line) > 240:    # mango reads at most 255 bytes of a value
                line = line.replace(self._identity(m, state), "name:^%s$" % re.escape(name))
            blocks.append("# %s (%s)\n%s\n" % (m.get("description", "").replace("\n", " ").replace("\r", " "),
                                               name, line))
        return "\n".join(blocks)

    def persist_verify(self, path):
        return verify_mango(path)

    RELOAD_CHECKS = (0.3, 0.6, 1.0, 1.5)   # seconds after the write; mango reloads ~150 ms later

    def after_persist(self, confirmed):
        """Writing monitors.conf makes mango reload its config and re-apply every monitor_rule:
        a rule of the user's that wins over ours, or an output we turned off (disabled outputs
        are not written), would silently undo what was just confirmed. Look several times (a
        busy machine reloads late) and, at the first difference, put the confirmed layout back,
        the same one the user accepted, without a new transaction."""
        plan = plan_from_state(confirmed)
        waited = 0.0
        for at in self.RELOAD_CHECKS:
            time.sleep(max(0.0, at - waited))
            waited = at
            try:
                if matches(plan, self.state()):
                    continue
            except DisplayError as e:
                log("after persist: cannot read mango (%s)" % e)
                continue
            log("after persist: mango's reload changed the confirmed layout, applying it again")
            try:
                guarded_apply(self, plan)
            except DisplayError as e:
                log("after persist: re-applying the confirmed layout failed: %s" % e)
                return
            ok, _ = wait_for(self, plan)
            log("after persist: confirmed layout %s" % ("restored" if ok else "NOT restored"))
            return

    def persist_info(self):
        first = last = False
        root = mango_config_dir()
        conf = os.path.join(root, "config.conf")
        try:
            with open(conf, encoding="utf-8", errors="replace") as f:
                lines = [ln.split("#", 1)[0].strip() for ln in f]
        except OSError:
            lines = []
        rule_idx = [i for i, ln in enumerate(lines) if ln.startswith("monitor_rule")]
        src_idx = [i for i, ln in enumerate(lines)
                   if re.match(r"^source(_optional)?\s*=\s*.*serpantinum/monitors\.conf\s*$", ln)]
        if src_idx:
            first = not rule_idx or min(src_idx) < min(rule_idx)
            last = not rule_idx or max(src_idx) > max(rule_idx)
        path = self.persist_path()
        return {"path": path, "exists": os.path.exists(path), "included": bool(src_idx),
                "complete": first and last, "toml": os.path.exists(os.path.join(root, "config.toml"))
                and not os.path.exists(conf),
                "managed": config_is_managed(root, "config.conf"), "writable": _can_create(path)}


MANGO_PERSIST_HEADER = """# Generated by Serpantinum display settings. Do not edit manually:
# changes made from Settings > Display overwrite this file.
# Load it from ~/.config/mango/config.conf with TWO identical lines: mango applies the first
# matching monitor_rule at startup but the last one when the config is reloaded, so the file
# must come before your own monitor rules (first line of config.conf) and after them (last line):
#     source_optional=./serpantinum/monitors.conf
# Disabled outputs are intentionally not saved, so a missing screen at boot
# can never leave you without any enabled output.
"""


BACKENDS = {HyprlandBackend.name: HyprlandBackend, SwayBackend.name: SwayBackend, NiriBackend.name: NiriBackend,
            MangoBackend.name: MangoBackend}


def detect_backend():
    forced = os.environ.get("SERPANTINUM_DISPLAY_BACKEND")
    classes = [BACKENDS[forced]] if forced in BACKENDS else list(BACKENDS.values())
    for cls in classes:
        if cls.detect():
            return cls()
    # TTY: nothing exported. Compare the best live instance of every compositor; ranks are
    # comparable, so a nested test Hyprland never beats a real Sway session (or the reverse).
    best = None
    for cls in classes:
        found = cls.candidate()
        if found is not None and (best is None or found[:2] < best[1][:2]):
            best = (cls, found)
    if best is None:
        raise DisplayError("unsupported_compositor")
    best[1][2]()
    return best[0]()


# ---------------------------------------------------------------- persistence

PERSIST_HEADER = """-- Generated by Serpantinum display settings. Do not edit manually:
-- changes made from Settings > Display overwrite this file.
-- Load it from hyprland.lua AFTER your own monitor rules:
--     require("serpantinum/monitors")
-- Disabled monitors are intentionally not saved, so a missing screen at boot
-- can never leave you without any enabled output.
"""


def render_lua(state):
    blocks = [PERSIST_HEADER]
    unique = desc_unique(state)
    for m in state["monitors"]:
        if not m["enabled"]:
            continue
        # Identify by panel description: connector names can change between boots.
        # Fall back to the name for identical panels or when no description exists.
        output = "desc:" + m["description"] if m["name"] in unique else m["name"]
        blocks.append(
            "-- %s (%s)\nhl.monitor({\n    output = %s,\n    mode = \"%dx%d@%.3f\",\n"
            "    position = \"%dx%d\",\n    scale = %s,\n    transform = %d,\n})\n" % (
                m.get("description", "").replace("\n", " ").replace("\r", " "), m["name"],
                lua_str(output), m["width"], m["height"], m["refresh"], m["x"], m["y"],
                repr(float(m["scale"])), m["transform"]))
    return "\n".join(blocks)


def find_hyprland_binary():
    """The Hyprland executable, for `--verify-config`. A systemd user service (NixOS) may
    not have it in PATH even though hyprctl is reachable, so also look next to hyprctl."""
    found = shutil.which("Hyprland")
    if found:
        return found
    ctl = shutil.which("hyprctl")
    if ctl:
        sibling = os.path.join(os.path.dirname(os.path.realpath(ctl)), "Hyprland")
        if os.access(sibling, os.X_OK):
            return sibling
        sibling = os.path.join(os.path.dirname(ctl), "Hyprland")
        if os.access(sibling, os.X_OK):
            return sibling
    return None


def verify_lua(path):
    """Reject a file Hyprland would fail to parse (a broken module breaks the whole config)."""
    binary = find_hyprland_binary()
    if not binary:
        log("verify skipped: Hyprland executable not found (PATH, next to hyprctl)")
        return True
    try:
        p = subprocess.run([binary, "--verify-config", "-c", path],
                           capture_output=True, text=True, timeout=15)
    except (OSError, subprocess.TimeoutExpired):
        return False
    return p.returncode == 0 and "config ok" in p.stdout


def persist_file(path, text, verify):
    """Write `text` to `path` atomically after `verify(tmp)` accepts it; keep the old one as .bak."""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = "%s.%d.tmp" % (path, os.getpid())
    with open(tmp, "w", encoding="utf-8") as f:
        f.write(text)
        f.flush()
        os.fsync(f.fileno())
    if not verify(tmp):
        os.unlink(tmp)
        raise DisplayError("persist_verify_failed")
    if os.path.exists(path):
        shutil.copy2(path, path + ".bak")
    os.replace(tmp, path)
    return path


def persist(state):
    return persist_file(persist_path(), render_lua(state), verify_lua)


NIX_STORE = "/nix/store"  # tests point this somewhere else


def config_is_managed(root, main_file="hyprland.lua"):
    """True when the Hyprland config is generated by Nix / Home Manager: the config
    directory or hyprland.lua is a link into the read-only store, so the user cannot paste
    a line into it and has to add it to their Nix configuration instead."""
    store = NIX_STORE.rstrip("/") + "/"
    for candidate in (root, os.path.join(root, main_file)):
        try:
            if os.path.islink(candidate) and (os.path.realpath(candidate) + "/").startswith(store):
                return True
            if os.path.exists(candidate) and (os.path.realpath(candidate) + "/").startswith(store):
                return True
        except OSError:
            pass
    return False


def _can_create(path):
    """Could `path` be written (its nearest existing parent is a writable directory)?"""
    d = os.path.dirname(path)
    while d and not os.path.exists(d):
        parent = os.path.dirname(d)
        if parent == d:
            break
        d = parent
    return os.path.isdir(d) and os.access(d, os.W_OK)


def persist_info():
    """Whether our module exists and is required from the user's Hyprland config."""
    included = False
    root = hypr_config_dir()
    for dirpath, _, files in os.walk(root):
        if os.path.relpath(dirpath, root).startswith("serpantinum"):
            continue
        for name in files:
            if not name.endswith(".lua"):
                continue
            try:
                with open(os.path.join(dirpath, name)) as f:
                    for line in f:
                        code = line.split("--", 1)[0]
                        if "require" in code and "serpantinum/monitors" in code:
                            included = True
            except OSError:
                pass
    return {"path": persist_path(), "exists": os.path.exists(persist_path()),
            "included": included, "managed": config_is_managed(root),
            "writable": _can_create(persist_path())}


# ---------------------------------------------------------------- transaction


def guarded_apply(backend, plan):
    """The ONE place the engine changes a compositor (restore, safe layout, apply, rescue and
    profiles all end here), so a safety check cannot be forgotten by a caller.

    SERPANTINUM_DISPLAY_VIRTUAL_ONLY=1 (set by tests/display/sandbox.sh and passed on to the
    reverter): refuse to touch a compositor that has any output that is not virtual
    (WAYLAND-n, HEADLESS-n, X11-n, winit). It is the guarantee that a test harness can never
    change real screens, whatever the environment or detection says."""
    if os.environ.get("SERPANTINUM_DISPLAY_VIRTUAL_ONLY") == "1":
        try:
            names = [m["name"] for m in backend.state()["monitors"]]
        except DisplayError as e:
            log("virtual-only: cannot read the compositor, refusing to apply (%s)" % e)
            raise DisplayError("virtual_only_refused:unreadable")
        names += [p.get("name") for p in plan.get("monitors", []) if isinstance(p.get("name"), str)]
        real = sorted({n for n in names if not VIRTUAL_OUTPUT.match(n)})
        if real:
            log("virtual-only: refused to apply, real outputs present: %s" % ", ".join(real))
            raise DisplayError("virtual_only_refused:%s" % ",".join(real))
    backend.apply(plan)


def wait_for(backend, plan, strict_position=True):
    state = None
    for _ in range(VERIFY_ATTEMPTS):
        time.sleep(VERIFY_DELAY)
        try:
            state = backend.state()
        except DisplayError:
            continue
        if matches(plan, state, strict_position):
            return True, state
    return False, state


def restore(backend, snapshot):
    """Restore a snapshot; fall back to the safe layout. Returns outcome."""
    # Never touch a compositor that is not the one the snapshot came from: a reverter that
    # lost its instance variable and discovered another session would "repair" the wrong
    # screens (the safe layout would rearrange them).
    now = None
    for _ in range(VERIFY_ATTEMPTS):   # a busy compositor must not cost the user their revert
        try:
            now = {m["name"] for m in backend.state()["monitors"]}
            break
        except DisplayError as e:
            log("restore: cannot read the compositor yet (%s)" % e)
            time.sleep(VERIFY_DELAY)
    if now is None:
        log("restore refused: the compositor never answered")
        return "failed"
    if snapshot.get("backend") not in (None, backend.name) or not (now & {m["name"] for m in snapshot["monitors"]}):
        log("restore refused: the compositor reached (%s, outputs %s) is not the one of the snapshot (%s)" % (
            backend.name, sorted(now), snapshot.get("backend")))
        return "failed"
    plan = plan_from_state(snapshot)
    try:
        guarded_apply(backend, plan)
        ok, got = wait_for(backend, plan)
        if ok:
            return "restored"
        log("restore did not verify, using safe layout (wanted %s, got %s)" % (
            json.dumps(plan["monitors"], sort_keys=True), json.dumps((got or {}).get("monitors"), sort_keys=True)))
    except DisplayError as e:
        log("restore failed: %s" % e)
    try:
        state = backend.state()
        safe = backend.safe_plan(state)
        guarded_apply(backend, safe)
        ok, _ = wait_for(backend, safe, strict_position=False)
        return "safe_layout" if ok else "safe_layout_unverified"
    except DisplayError as e:
        log("safe layout failed: %s" % e)
        return "failed"


def pid_alive(pid):
    try:
        os.kill(pid, 0)
        return True
    except ProcessLookupError:
        return False
    except PermissionError:
        return True


def spawn_watcher(txn_id, backend_name=None):
    """Start the reverter outside Quickshell's process tree."""
    script = os.path.abspath(__file__)
    # The reverter must read and write exactly the files its parent uses, so pass
    # every variable the script consults, and the resolved runtime dir explicitly.
    env_keys = ("HYPRLAND_INSTANCE_SIGNATURE", "SWAYSOCK", "NIRI_SOCKET", "MANGO_INSTANCE_SIGNATURE", "XDG_RUNTIME_DIR", "XDG_STATE_HOME",
                "XDG_CONFIG_HOME", "HOME", "WAYLAND_DISPLAY", "PATH",
                "SERPANTINUM_DISPLAY_NO_PERSIST", "SERPANTINUM_DISPLAY_RUNTIME",
                "SERPANTINUM_DISPLAY_BACKEND", "SERPANTINUM_DISPLAY_VIRTUAL_ONLY")
    os.environ["SERPANTINUM_DISPLAY_RUNTIME"] = runtime_dir()
    # The systemd user manager has its own environment (it may hold the variables of ANOTHER
    # session or compositor); name the backend explicitly so the reverter cannot pick that one.
    if backend_name:
        os.environ["SERPANTINUM_DISPLAY_BACKEND"] = backend_name
    if shutil.which("systemd-run") and os.environ.get("SERPANTINUM_DISPLAY_NO_SYSTEMD") != "1":
        # Restart=on-failure: if the reverter itself is killed, systemd brings it
        # back and it resumes the same transaction (deadline is in txn.json).
        args = ["systemd-run", "--user", "--quiet", "--collect",
                "--property=Restart=on-failure", "--property=RestartSec=1",
                "--unit", "serpantinum-display-revert-%s" % txn_id[:8]]
        for k in env_keys:
            if os.environ.get(k):
                args += ["--setenv", "%s=%s" % (k, os.environ[k])]
        args += [sys.executable, script, "_watch", txn_id]
        rc = subprocess.run(args, capture_output=True, timeout=10).returncode
        if rc == 0:
            return "systemd"
        log("systemd-run failed rc=%d, falling back to setsid" % rc)
    subprocess.Popen([sys.executable, script, "_watch", txn_id],
                     stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                     stderr=subprocess.DEVNULL, start_new_session=True, close_fds=True)
    return "setsid"


def cmd_apply(backend, plan, timeout, partial=False, reflow=None):
    timeout = max(MIN_TIMEOUT, min(MAX_TIMEOUT, int(timeout)))
    with Lock():
        txn = read_json(txn_path())
        if txn and txn.get("phase") == "pending":
            return {"ok": False, "error": "transaction_pending"}
        state = backend.state()
        plan, r_errors, r_warnings = resolve_plan(plan, state, partial)
        if r_errors:
            return {"ok": False, "errors": r_errors, "warnings": r_warnings}
        if reflow:
            plan = reflow_plan(plan_from_state(state), plan, reflow)
        plan = normalize_plan(plan, state)
        errors, warnings = validate(plan, state)
        warnings = r_warnings + warnings
        if errors:
            return {"ok": False, "errors": errors, "warnings": warnings}
        if matches(plan, state):
            return {"ok": True, "unchanged": True, "warnings": warnings}

        txn = {"id": uuid.uuid4().hex, "backend": backend.name, "phase": "pending", "created": time.time(),
               "deadline": time.time() + timeout, "timeout": timeout,
               "snapshot": state, "plan": plan, "watcher_pid": None}
        atomic_write_json(txn_path(), txn)
        # The reverter must be running BEFORE the screen can go dark.
        txn["watcher"] = spawn_watcher(txn["id"], backend.name)
        atomic_write_json(txn_path(), txn)
        log("txn %s armed (%s, %ds)" % (txn["id"], txn["watcher"], timeout))

    try:
        guarded_apply(backend, plan)
        ok, _ = wait_for(backend, plan)
    except DisplayError as e:
        ok = False
        log("txn %s apply error: %s" % (txn["id"], e))
    if not ok:
        outcome = finish(backend, txn["id"], "revert", reason="verify_failed")
        return {"ok": False, "error": "apply_not_verified", "outcome": outcome}
    return {"ok": True, "id": txn["id"], "timeout": timeout, "warnings": warnings}


def finish(backend, txn_id, action, reason=""):
    """Single exit point for a pending transaction. Idempotent."""
    with Lock():
        txn = read_json(txn_path())
        if not txn or txn.get("id") != txn_id or txn.get("phase") != "pending":
            return "not_pending"
        if foreign(txn, backend):
            log("%s refused: the pending transaction belongs to %s, not %s" % (action, txn.get("backend"), backend.name))
            return "foreign_transaction"
        if action == "confirm":
            txn["phase"] = "confirmed"
            outcome = "confirmed"
            try:
                confirmed = backend.state()
                atomic_write_json(last_good_path(), confirmed)
                if os.environ.get("SERPANTINUM_DISPLAY_NO_PERSIST") != "1":
                    backend.persist(confirmed)
                    txn["persisted"] = True
                    try:
                        backend.after_persist(confirmed)
                    except Exception as e:   # never let a hook undo the confirmation
                        log("after_persist failed: %s" % e)
            except (DisplayError, OSError) as e:
                # The live change stays confirmed; only the boot file is untouched.
                txn["persisted"] = False
                log("could not persist confirmed layout: %s" % e)
        else:
            txn["phase"] = "reverting"
            atomic_write_json(txn_path(), txn)
            outcome = restore(backend, txn["snapshot"])
            txn["phase"] = "reverted"
        txn["outcome"] = outcome
        txn["reason"] = reason
        txn["finished"] = time.time()
        atomic_write_json(txn_path(), txn)
        log("txn %s %s (%s) %s" % (txn_id, txn["phase"], outcome, reason))
        return outcome


def foreign(txn, backend):
    """A transaction another compositor's backend started (the state dir is shared per user).
    Settling it from here would restore or confirm layouts on the wrong screens."""
    return bool(txn) and txn.get("backend") not in (None, backend.name)


def cmd_watch(backend, txn_id):
    txn = read_json(txn_path())
    if not txn or txn.get("id") != txn_id or foreign(txn, backend):
        return
    with Lock():
        txn = read_json(txn_path())
        if txn and txn.get("id") == txn_id:
            txn["watcher_pid"] = os.getpid()
            atomic_write_json(txn_path(), txn)
    while True:
        txn = read_json(txn_path())
        if not txn or txn.get("id") != txn_id or txn.get("phase") != "pending":
            return
        if txn.get("revert_requested") or time.time() >= txn["deadline"]:
            finish(backend, txn_id, "revert",
                   reason="requested" if txn.get("revert_requested") else "timeout")
            return
        time.sleep(POLL_INTERVAL)


def cmd_status(backend):
    txn = read_json(txn_path())
    if not txn:
        return {"ok": True, "pending": False}
    if foreign(txn, backend):
        return {"ok": True, "pending": False, "foreign": txn.get("backend")}
    if txn.get("phase") == "pending":
        pid = txn.get("watcher_pid")
        started_long_ago = time.time() - txn["created"] > 5
        if (pid and not pid_alive(pid)) or (not pid and started_long_ago):
            # Reverter vanished: never leave an unconfirmed layout without a guard.
            outcome = finish(backend, txn["id"], "revert", reason="watcher_lost")
            return {"ok": True, "pending": False, "healed": outcome}
        return {"ok": True, "pending": True, "id": txn["id"],
                "remaining": max(0.0, round(txn["deadline"] - time.time(), 1))}
    return {"ok": True, "pending": False, "last": {k: txn.get(k) for k in ("id", "phase", "outcome", "reason")}}


def cmd_request_revert(backend=None):
    with Lock():
        txn = read_json(txn_path())
        if not txn or txn.get("phase") != "pending":
            return {"ok": True, "pending": False}
        if backend is not None and foreign(txn, backend):
            log("revert ignored: the pending transaction belongs to %s, not %s" % (txn.get("backend"), backend.name))
            return {"ok": True, "pending": False, "foreign": txn.get("backend")}
        txn["revert_requested"] = True
        atomic_write_json(txn_path(), txn)
        return {"ok": True, "id": txn["id"]}


def cmd_rescue(backend):
    with Lock():
        txn = read_json(txn_path())
        if txn and txn.get("phase") == "pending":
            txn["phase"] = "rescued"
            atomic_write_json(txn_path(), txn)
    state = backend.state()
    good = read_json(last_good_path())
    if good and good.get("backend", backend.name) != backend.name:
        log("rescue: last-good belongs to %s, not %s; using the safe layout" % (good.get("backend"), backend.name))
        good = None
    if good:
        plan, r_errors, _ = resolve_plan(plan_from_state(good), state, partial=True)
        errors = r_errors or validate(plan, state)[0]
        if not errors:
            guarded_apply(backend, plan)
            ok, _ = wait_for(backend, plan)
            if ok:
                return {"ok": True, "outcome": "last_good"}
    outcome = restore(backend, {"backend": backend.name, "monitors": backend.safe_plan(state)["monitors"]})
    return {"ok": outcome != "failed", "outcome": outcome}


def load_plan(arg):
    """A plan is a file path, '-' for stdin, or the JSON itself (starts with '{')."""
    if arg.lstrip().startswith("{"):
        return json.loads(arg)
    data = sys.stdin.read() if arg == "-" else open(arg).read()
    return json.loads(data)


def main(argv):
    if not argv:
        print(__doc__)
        return 2
    cmd, rest = argv[0], argv[1:]
    if cmd == "backends":   # which compositors this build can manage; needs no compositor
        print(json.dumps({"ok": True, "backends": sorted(BACKENDS)}))
        return 0
    try:
        backend = detect_backend()
        if cmd == "state":
            st = backend.state()
            for m in st["monitors"]:
                m["validScales"] = backend.valid_scales(m["width"], m["height"])
            result = {"ok": True, "supported": True, **st, "persistence": backend.persist_info()}
        elif cmd == "validate":
            state = backend.state()
            plan, r_errors, r_warnings = resolve_plan(load_plan(rest[0]), state, "--partial" in rest)
            if not r_errors:
                plan = normalize_plan(plan, state)
            errors, warnings = (r_errors, r_warnings) if r_errors else validate(plan, state)
            result = {"ok": not errors, "errors": errors, "warnings": r_warnings + warnings if not r_errors else warnings,
                      "resolved": plan if not errors else None}
        elif cmd == "apply":
            timeout = DEFAULT_TIMEOUT
            if "--timeout" in rest:
                timeout = int(rest[rest.index("--timeout") + 1])
            reflow = rest[rest.index("--reflow") + 1] if "--reflow" in rest else None
            result = cmd_apply(backend, load_plan(rest[0]), timeout, "--partial" in rest, reflow)
        elif cmd == "confirm":
            txn = read_json(txn_path()) or {}
            outcome = finish(backend, txn.get("id"), "confirm")
            after = read_json(txn_path()) or {}
            result = {"ok": outcome == "confirmed", "outcome": outcome,
                      "persisted": after.get("persisted", False)}
        elif cmd == "revert":
            result = cmd_request_revert(backend)
        elif cmd == "status":
            result = cmd_status(backend)
        elif cmd == "rescue":
            result = cmd_rescue(backend)
        elif cmd == "_watch":
            cmd_watch(backend, rest[0])
            return 0
        else:
            print(__doc__)
            return 2
    except (DisplayError, OSError, ValueError, IndexError) as e:
        result = {"ok": False, "error": str(e)}
    print(json.dumps(result))
    return 0 if result.get("ok") else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
