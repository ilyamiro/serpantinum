#!/usr/bin/env bash
# The ONLY supported way to run display_txn.py, the Display page or any e2e script against a
# TEST compositor (nested or headless). Two reasons it exists: a script started from inside
# your real session is a client of the real compositor, so a missing variable made the engine
# pick the real one (twice, a test moved real monitors). The engine now refuses real outputs
# when SERPANTINUM_DISPLAY_VIRTUAL_ONLY=1; this script sets that and checks the rest.
#
# usage: sandbox.sh <backend> <compositor-id> <wayland-display> [-- command args...]
#   backend          hyprland | sway | niri | mango
#   compositor-id    hyprland: instance signature   sway: SWAYSOCK path
#                    niri: NIRI_SOCKET path         mango: MANGO_INSTANCE_SIGNATURE (socket path)
#   wayland-display  the Wayland display of the TEST compositor (e.g. wayland-2)
#   command          default: display_txn.py state. Runs with a minimal, isolated environment.
#   SANDBOX_EXTRA="K=V K=V"   extra variables for the command (QT_QPA_PLATFORM is already set).
#
# Exit: the command's status; 3 if the real session's monitors differ afterwards (they are
# restored on Hyprland and the difference is printed); 2 refusals before running anything.
set -u

die() { echo "sandbox: $*" >&2; exit 2; }

[ $# -ge 3 ] || { sed -n '2,20p' "$0" >&2; exit 2; }
BACKEND=$1; CID=$2; WDISP=$3; shift 3
[ "${1:-}" = "--" ] && shift
case "$BACKEND" in hyprland|sway|niri|mango) ;; *) die "unknown backend '$BACKEND'";; esac

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TXN="$ROOT/src/quickshell/guide/display/display_txn.py"
RUNTIME="${XDG_RUNTIME_DIR:?XDG_RUNTIME_DIR is not set}"

# --- the test compositor must not be the session this shell belongs to
REAL_WL="${WAYLAND_DISPLAY:-}"
[ -z "$REAL_WL" ] || [ "$WDISP" != "$REAL_WL" ] || die "wayland display '$WDISP' is the one of the real session"
[ -S "$RUNTIME/$WDISP" ] || die "no Wayland socket $RUNTIME/$WDISP"
case "$BACKEND" in
    hyprland)
        [ "$CID" != "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] || die "that is the real Hyprland signature"
        [ -d "$RUNTIME/hypr/$CID" ] || die "no Hyprland instance $CID" ;;
    sway|niri|mango) [ -S "$CID" ] || die "no socket $CID" ;;
esac

# --- snapshot of the REAL session (read only), to prove nothing changed
real_hypr_pid() {
    local sig=${HYPRLAND_INSTANCE_SIGNATURE:-} pid
    [ -n "$sig" ] || return 1
    pid=$(head -n1 "$RUNTIME/hypr/$sig/hyprland.lock" 2>/dev/null) || return 1
    [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null && echo "$pid"
}
snapshot_real() {
    if real_hypr_pid >/dev/null; then
        hyprctl -j monitors all 2>/dev/null | python3 -c '
import json, sys
try: data = json.load(sys.stdin)
except Exception: sys.exit(0)
keys = ("name", "width", "height", "refreshRate", "x", "y", "scale", "transform", "disabled")
print(json.dumps(sorted(({k: m.get(k) for k in keys} for m in data), key=lambda m: m["name"]), sort_keys=True))'
    fi
}
restore_real_hypr() {
    local pid; pid=$(real_hypr_pid) || { echo "sandbox: cannot verify the real Hyprland, NOT restoring" >&2; return 1; }
    python3 - "$1" <<'PY' | hyprctl eval "$(cat)" >/dev/null 2>&1 || return 1
import json, sys
for m in json.loads(sys.argv[1]):
    if m["disabled"]:
        print('hl.monitor({ output = "%s", disabled = true })' % m["name"])
    else:
        print('hl.monitor({ output = "%s", mode = "%dx%d@%.3f", position = "%dx%d", scale = %s, transform = %d, disabled = false })'
              % (m["name"], m["width"], m["height"], m["refreshRate"], m["x"], m["y"], repr(float(m["scale"])), m["transform"]))
PY
}
BEFORE=$(snapshot_real)

# --- isolated environment
TMP=$(mktemp -d "${TMPDIR:-/tmp}/serp-sandbox.XXXXXX") || die "mktemp"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP"/{home,config,state,cache} "$TMP/rt"; chmod 700 "$TMP/rt"
ENV=(PATH="$PATH" XDG_RUNTIME_DIR="$RUNTIME" HOME="$TMP/home" XDG_CONFIG_HOME="$TMP/config"
     XDG_STATE_HOME="$TMP/state" XDG_CACHE_HOME="$TMP/cache" WAYLAND_DISPLAY="$WDISP"
     QT_QPA_PLATFORM=wayland XDG_CURRENT_DESKTOP="$BACKEND" LANG="${LANG:-C}"
     SERPANTINUM_DISPLAY_BACKEND="$BACKEND" SERPANTINUM_DISPLAY_VIRTUAL_ONLY=1
     SERPANTINUM_DISPLAY_RUNTIME="$TMP/rt" SERPANTINUM_DIR="$ROOT/src" SANDBOX=1)
case "$BACKEND" in
    hyprland) ENV+=(HYPRLAND_INSTANCE_SIGNATURE="$CID") ;;
    sway)     ENV+=(SWAYSOCK="$CID") ;;
    niri)     ENV+=(NIRI_SOCKET="$CID") ;;
    mango)    ENV+=(MANGO_INSTANCE_SIGNATURE="$CID") ;;
esac
# shellcheck disable=SC2206
ENV+=(${SANDBOX_EXTRA:-})

# --- refuse before running anything unless the engine sees exactly the expected, virtual backend
GUARD=$(env -i "${ENV[@]}" python3 "$TXN" state 2>/dev/null | python3 -c '
import json, re, sys
try: d = json.load(sys.stdin)
except Exception: print("unreadable"); sys.exit()
virt = re.compile(r"^((WAYLAND|HEADLESS|X11)-\d+|winit)$")
bad = [m["name"] for m in d.get("monitors", []) if not virt.match(m["name"])]
print(d.get("backend", "?") + ("|real:" + ",".join(bad) if bad else ""))')
[ "$GUARD" = "$BACKEND" ] || die "refused: engine reports '$GUARD' (expected '$BACKEND' with only virtual outputs)"

# --- run
if [ $# -eq 0 ]; then set -- python3 "$TXN" state; fi
env -i "${ENV[@]}" "$@"
RC=$?

# --- the real session must be exactly as before
AFTER=$(snapshot_real)
if [ "$BEFORE" != "$AFTER" ]; then
    echo "sandbox: THE REAL SESSION CHANGED" >&2
    echo "  before: $BEFORE" >&2
    echo "  after:  $AFTER" >&2
    if [ -n "$BEFORE" ] && restore_real_hypr "$BEFORE"; then
        sleep 1.5
        if [ "$(snapshot_real)" = "$BEFORE" ]; then echo "sandbox: real Hyprland restored to 'before'" >&2
        else echo "sandbox: restore did not verify, check the monitors by hand" >&2; fi
    fi
    exit 3
fi
exit $RC
