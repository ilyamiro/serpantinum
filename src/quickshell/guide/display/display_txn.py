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
    apply PLAN [--timeout S]   start a transaction (PLAN is a file or '-')
    confirm                    keep the pending transaction
    revert                     revert the pending transaction now
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
import shutil
import subprocess
import sys
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


def runtime_dir():
    base = os.environ.get("XDG_RUNTIME_DIR") or "/run/user/%d" % os.getuid()
    path = os.path.join(base, "serpantinum-display")
    os.makedirs(path, mode=0o700, exist_ok=True)
    return path


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


def mode_supported(mon_state, width, height, refresh):
    for mode in mon_state.get("modes", []):
        w, h, r = mode
        if w == width and h == height and abs(r - refresh) <= REFRESH_TOLERANCE:
            return True
    return False


def plan_from_state(state):
    return {"monitors": [{k: m[k] for k in (
        "name", "description", "enabled", "width", "height", "refresh",
        "x", "y", "scale", "transform")} for m in state["monitors"]]}


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
        if scale not in valid_scales(width, height):
            errors.append("scale_invalid:%s:%s" % (name, scale))
            continue
        if transform not in range(8):
            errors.append("transform_invalid:%s" % name)
            continue
        if abs(x) > 32768 or abs(y) > 32768:
            errors.append("position_out_of_range:%s" % name)
            continue
        mon = dict(p, width=width, height=height, scale=scale, transform=transform, x=x, y=y)
        lw, lh = logical_size(mon)
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


class HyprlandBackend:
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


def detect_backend():
    if os.environ.get("HYPRLAND_INSTANCE_SIGNATURE"):
        return HyprlandBackend()
    # From a TTY the variable is missing: adopt the most recent Hyprland instance.
    hypr_dir = os.path.join(os.environ.get("XDG_RUNTIME_DIR") or "/run/user/%d" % os.getuid(), "hypr")
    try:
        instances = sorted(
            (os.path.join(hypr_dir, d) for d in os.listdir(hypr_dir)
             if os.path.exists(os.path.join(hypr_dir, d, ".socket.sock"))),
            key=os.path.getmtime, reverse=True)
    except OSError:
        instances = []
    if instances:
        os.environ["HYPRLAND_INSTANCE_SIGNATURE"] = os.path.basename(instances[0])
        return HyprlandBackend()
    raise DisplayError("unsupported_compositor")


# ---------------------------------------------------------------- transaction


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
    plan = plan_from_state(snapshot)
    try:
        backend.apply(plan)
        ok, _ = wait_for(backend, plan)
        if ok:
            return "restored"
        log("restore did not verify, using safe layout")
    except DisplayError as e:
        log("restore failed: %s" % e)
    try:
        state = backend.state()
        safe = backend.safe_plan(state)
        backend.apply(safe)
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


def spawn_watcher(txn_id):
    """Start the reverter outside Quickshell's process tree."""
    script = os.path.abspath(__file__)
    env_keys = ("HYPRLAND_INSTANCE_SIGNATURE", "XDG_RUNTIME_DIR", "XDG_STATE_HOME",
                "WAYLAND_DISPLAY", "PATH")
    if shutil.which("systemd-run") and os.environ.get("SERPANTINUM_DISPLAY_NO_SYSTEMD") != "1":
        args = ["systemd-run", "--user", "--quiet", "--collect",
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


def cmd_apply(backend, plan, timeout):
    timeout = max(MIN_TIMEOUT, min(MAX_TIMEOUT, int(timeout)))
    with Lock():
        txn = read_json(txn_path())
        if txn and txn.get("phase") == "pending":
            return {"ok": False, "error": "transaction_pending"}
        state = backend.state()
        errors, warnings = validate(plan, state)
        if errors:
            return {"ok": False, "errors": errors, "warnings": warnings}
        if matches(plan, state):
            return {"ok": True, "unchanged": True, "warnings": warnings}

        txn = {"id": uuid.uuid4().hex, "phase": "pending", "created": time.time(),
               "deadline": time.time() + timeout, "timeout": timeout,
               "snapshot": state, "plan": plan, "watcher_pid": None}
        atomic_write_json(txn_path(), txn)
        # The reverter must be running BEFORE the screen can go dark.
        txn["watcher"] = spawn_watcher(txn["id"])
        atomic_write_json(txn_path(), txn)
        log("txn %s armed (%s, %ds)" % (txn["id"], txn["watcher"], timeout))

    try:
        backend.apply(plan)
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
        if action == "confirm":
            txn["phase"] = "confirmed"
            outcome = "confirmed"
            try:
                atomic_write_json(last_good_path(), backend.state())
            except DisplayError as e:
                log("could not record last-good: %s" % e)
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


def cmd_watch(backend, txn_id):
    txn = read_json(txn_path())
    if not txn or txn.get("id") != txn_id:
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


def cmd_request_revert():
    with Lock():
        txn = read_json(txn_path())
        if not txn or txn.get("phase") != "pending":
            return {"ok": True, "pending": False}
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
    if good:
        plan = plan_from_state(good)
        errors, _ = validate(plan, state)
        if not errors:
            backend.apply(plan)
            ok, _ = wait_for(backend, plan)
            if ok:
                return {"ok": True, "outcome": "last_good"}
    return {"ok": True, "outcome": restore(backend, {"monitors": backend.safe_plan(state)["monitors"]})}


def load_plan(arg):
    data = sys.stdin.read() if arg == "-" else open(arg).read()
    return json.loads(data)


def main(argv):
    if not argv:
        print(__doc__)
        return 2
    cmd, rest = argv[0], argv[1:]
    try:
        backend = detect_backend()
        if cmd == "state":
            st = backend.state()
            for m in st["monitors"]:
                m["validScales"] = valid_scales(m["width"], m["height"])
            result = {"ok": True, **st}
        elif cmd == "validate":
            errors, warnings = validate(load_plan(rest[0]), backend.state())
            result = {"ok": not errors, "errors": errors, "warnings": warnings}
        elif cmd == "apply":
            timeout = DEFAULT_TIMEOUT
            if "--timeout" in rest:
                timeout = int(rest[rest.index("--timeout") + 1])
            result = cmd_apply(backend, load_plan(rest[0]), timeout)
        elif cmd == "confirm":
            txn = read_json(txn_path()) or {}
            outcome = finish(backend, txn.get("id"), "confirm")
            result = {"ok": outcome == "confirmed", "outcome": outcome}
        elif cmd == "revert":
            result = cmd_request_revert()
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
