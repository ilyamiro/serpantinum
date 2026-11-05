# Display manager rebuild — continuity notes

Branch `feature/display-manager-v2`, worktree `~/Proyectos/serpantinum-display-v2`,
based on upstream `ilyamiro/serpantinum` 2.4.0. Replaces the abandoned v0600 branch
(278 Python scripts, never applied a physical change). Do NOT port code from it;
only the QML look of `serpantinum-v0600-physical-execution-lab/src/quickshell/guide/display/`
may be used as visual reference.

Scope: Arch + Hyprland (Lua config, 0.57) first; Niri/Sway/Mango later.
Never touch the user's live install (2.2.0) or `~/.config/hypr/*` while developing.

## Safety design (done)
`src/quickshell/guide/display/display_txn.py` — single stdlib-only script, JSON out.
validate -> snapshot -> arm reverter (systemd-run --user, Restart=on-failure; setsid fallback)
-> `hyprctl eval` (enables before disables) -> verify against `hyprctl -j monitors all`
-> confirm within timeout, else restore snapshot -> if restore fails, safe layout
(all outputs on, best mode, left-to-right, scale 1).
Validation: every monitor listed, identity by description (catches eDP-1->eDP-2),
mode in availableModes, scale gives integral logical size, transform 0-7, no overlap,
>=1 enabled; gaps are only a warning. One transaction at a time (flock).
State: `$XDG_RUNTIME_DIR/serpantinum-display/txn.json`,
`~/.local/state/serpantinum/display/{last-good.json,display.log}`.
Emergency (TTY): `python3 <qsDir>/guide/display/display_txn.py rescue`
(auto-detects the Hyprland instance; restores last-good, else safe layout).

## Verified
- `python3 -m unittest discover -s tests/display` — 55 offline tests (fake hyprctl).
- Nested Hyprland with a HEADLESS output (never the real session): timeout revert,
  confirm, revert-on-request, disable+revert, watcher SIGKILL (setsid: healed by
  `status`; systemd: unit restarts and reverts), all-off rejected.
  Recipe: `Hyprland -c nested.lua &`, then `HYPRLAND_INSTANCE_SIGNATURE=<new sig>`
  `hyprctl output create headless`. ABORT if the signature equals the real session.

## UI status (Hyprland only; niri/sway/mango code is untouched upstream code)
DONE (steps 1-2 and 5 for en/es):
- `DisplayMainState.qml`: Hyprland reads monitors through `display_txn.py state`
  (modes, validScales, description, x/y, transform, focused). If the backend fails it
  falls back to the old read-only `hyprctl` detector and `txnAvailable=false`.
  `txnChange(name, patch)` -> `apply <inline JSON> --timeout 15 --reflow <name>`;
  `txnConfirm/txnRevert/txnCheckStatus`; 1 s status poll while pending; `status` is
  also called on load (heals a dead reverter, resumes the countdown). Error codes
  `code:a:b` map to `guide.display.txn.err_<code>` with `{a}`/`{b}`.
  `applyMonitorPower/Scale` for Hyprland go through `txnChange`.
- `DisplayNotice.qml` (new, in qmldir): banner. `DisplayMainTab.qml` shows (1) the
  "Keep these display settings?" banner with countdown + Revert / Keep, (2) result
  notices, (3) the persistence hint with `require("serpantinum/monitors")` when
  `persistence.included` is false.
- `DisplayMonitorCard.qml`: Resolution, Refresh rate and Orientation dropdowns (from
  `modes`), power toggle driven by the compositor and disabled for the last enabled
  monitor, scale slider uses the backend `validScales`. Controls are disabled while a
  transaction is pending. Blue light filter group is upstream code.
- Backend `reflow_plan`: a size/scale/rotation change shifts neighbours so the layout
  stays attached (otherwise the validator would reject overlaps / warn about gaps).
- i18n: `guide.display.txn.*`, `resolution.*`, `refresh.*`, `orientation.*` in en/es
  only; the other 21 languages fall back to English via `I18n.t`.

TODO (in order):
3. Arrangement map (new `DisplayArrangementMap.qml`, shown above the cards): numbered
   draggable rectangles at logical size, snap to edges (no overlap), refresh rate on
   top, `name  WxH` below, star on the focused monitor, Refresh button (`reloadMonitors`).
   Dropping = `txnChange`-style apply with the new x/y for that monitor (no reflow).
   Needs a backend call that accepts a full plan (use `apply <json>` without --reflow).
4. Profiles: Save / Load. Store each monitor WITH `description` in Config key
   `display.profiles`; load with `apply <json> --partial`.
5. Translations for the other 21 languages (optional, English fallback works).
6. Physical test (below).

## How the UI was verified (repeat this after UI changes)
Throwaway `qs -p` harness (never commit it) with a `Loader` that does
`setSource("guide/display/DisplayMainTab.qml", {rootObj, tabIndex:0})` and a Timer
driving `tab.txnChange/txnConfirm/txnRevert`, run against a NESTED Hyprland with
`hyprctl output create headless` x2. Isolation env: HOME, XDG_CONFIG_HOME,
XDG_STATE_HOME, XDG_CACHE_HOME, QS_SETTINGS, QS_CACHE_DIR, QS_STATE_DIR, QS_RUN_DIR,
IPC_SOCKET and SERPANTINUM_DISPLAY_RUNTIME all point to a temp dir; set
HYPRLAND_INSTANCE_SIGNATURE and WAYLAND_DISPLAY to the nested ones (find the new
`wayland-N` socket by diffing `$XDG_RUNTIME_DIR`). Do NOT use `serpantinumd` for this:
it can stop the running shell. Screenshot with `WAYLAND_DISPLAY=<nested> grim -o WAYLAND-1`.
Seen working: apply, countdown banner, block while pending, confirm keeps + persists,
revert on request (~2 s), timeout revert (15 s), unsupported-mode error in Spanish,
reflow (HEADLESS-2 x 2870 -> 2230 when HEADLESS-1 went 1.0 -> 1.5).
Bug found by it and fixed: the systemd reverter did not inherit
`SERPANTINUM_DISPLAY_RUNTIME`, read another txn.json and exited; now `spawn_watcher`
forwards every variable the script reads and the resolved runtime dir.

## Persistence (decided by user: own module, like nwg-displays)
On confirm, `display_txn.py` writes `~/.config/hypr/serpantinum/monitors.lua`
(atomic, previous kept as `.bak`, gated by `Hyprland --verify-config`). The user's
files are never written; they opt in with `require("serpantinum/monitors")` placed
AFTER their own monitor rules. Disabled monitors are never persisted (a missing
screen at boot must not leave zero enabled outputs). `state` returns
`persistence: {path, exists, included}` — the UI must show a hint with that exact
require line when `included` is false. Tests set XDG_CONFIG_HOME to a temp dir;
keep it that way.

## Monitor identity: panel description, not connector name
Connector names change between boots (the user's laptop flips eDP-1/eDP-2). Rules:
- Persistence (`render_lua`): `output = "desc:<description>"` when the description is
  unambiguous (`desc_unique`: non-empty and not equal/prefix of another monitor's
  description, because Hyprland matches `desc:` by PREFIX); otherwise the connector
  name. Strings go through `lua_str` (json.dumps emits `\uXXXX`, invalid in Lua).
- last-good, profiles and any stored plan go through `resolve_plan(plan, state, partial)`
  (called by `apply`, `validate` and `rescue`): panel description is the identity;
  the name only breaks ties between identical panels and is the fallback for plans
  with no description. Strict (default): any absent/changed monitor is an error.
  `--partial` (profiles, rescue): absent monitors are dropped with a
  `profile_monitor_absent:<name>` warning and connected monitors the plan does not
  mention keep their current setup.
- UI contract: profiles must store each monitor WITH its `description` (the `state`
  output already has it) and load with `apply - --partial`.
- Verified: `hl.monitor{output="desc:..."}` passes `Hyprland --verify-config` and is
  processed by the compositor (nested: a non-matching `desc:` changes nothing, an
  empty `desc:` prefix matches every output). NOT verified: a match against a real
  panel description, because nested/headless outputs have empty descriptions. That
  needs one check on real hardware (part of the physical test, TTY open).
- Tests: renamed connector, exchanged names between panels, identical panels,
  prefix descriptions, empty description, tricky characters (quotes, backslash, ñ,
  CJK, control char) validated with the real `Hyprland --verify-config`, rescue after
  a rename, partial profile with an absent monitor.

## Open
- Physical test on real hardware with TTY3 open as backup (use Opus), including the
  first real `desc:` match check described above.
