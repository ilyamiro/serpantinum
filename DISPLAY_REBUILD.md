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

DONE (step 3): arrangement map.
- `DisplayLayoutMath.js` (`.pragma library`): pure geometry in LOGICAL pixels. `resolveDrop`
  = edge magnet (threshold ~10 px on screen) -> push out of overlaps -> if it floats free
  or would cut another screen off, nearest spot that touches a neighbour AND keeps the
  whole layout connected. Tested with `node --test tests/display/` (15 tests).
- `DisplayArrangementMap.qml`: enabled monitors at logical size on a grid; number, refresh
  on top, `name  W×H` below, star on the focused one; a ghost rectangle shows where the drop
  will land (red when rejected). Drop -> `tab.txnChange(name, {x, y})` (same confirm banner).
  Disabled while a transaction is pending/busy or with a single monitor.
  `dropMonitor(name, lx, ly)` is the testable entry point. Refresh button = `reloadMonitors`.
- i18n en/es: `guide.display.map.*`, `txn.err_layout_overlap`, `txn.err_layout_disconnected`.

TODO (in order):
4. Profiles: Save profile / Load profile... next to the map's Refresh button (see mockup).
   Store each monitor WITH `description` in Config key `display.profiles`; load with
   `apply <json> --partial` (absent monitors dropped with a warning).
5. Translations for the other 21 languages (optional, English fallback works).
6. Physical test (below).

KNOWN GAP: the map's VISUAL rendering and real mouse dragging have not been seen. The
harness drove `dropMonitor` (snap to (950,1080), push-out to the free side, revert) and
the component loads with no QML errors, but screenshots failed: a nested Hyprland's window
is only rendered while it is visible on the host desktop, so `grim` and `grabToImage` hang
or return nothing. To see it yourself run `tests/display/try-ui.sh`: nested Hyprland + 2 virtual
monitors + the Display page, fully isolated (temp HOME/config/state, deleted on exit).
The user can drag the monitors with the mouse; nothing real is touched. Do not call `hyprctl dispatch` from
scripts without confirming which instance it targets.

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

## Layout draft + Apply (latest UI change)

- Monitor card is two columns (GridLayout, `uniformCellWidths`): Enable | Vertical alignment, Resolution | Refresh,
  Blue light | Automatic schedule, then Color temperature and UI scale full width.
- "Vertical alignment" is a toggle (portrait yes/no, transform 1/0); flipped orientations are no longer exposed.
- Drag root cause: the page `Flickable` stole vertical drags, and the map was locked while a transaction was pending.
  Fixed with `preventStealing: true` and by making drops local.
- Dropping only stores a snapped position in `layoutDraft` (peach border = moved). Nothing runs until "Apply changes"
  (`layoutApply()` -> one transaction -> keep/revert banner). Discard / Refresh drop the draft.
- Per-monitor controls are blocked (`err_layout_draft`) while the draft is dirty.
- Verified headless against a nested Hyprland: move -> draft only; second move replaces first; apply -> pending,
  draft cleared; apply while pending refused; confirm keeps; revert restores. Visual look/drag feel: user must check
  with `tests/display/try-ui.sh`.

## Profiles

- `DisplayProfilesBar.qml` (registered in `guide/display/qmldir`): Save profile (inline name field), profile dropdown,
  Load, Delete. Stored in Config `display.profiles[name] = {monitors:[...]}` with each monitor's panel `description`.
- Load = `apply <plan> --partial` through the normal keep/revert transaction (absent monitors are dropped with a warning).
- Save/Load are refused while a layout draft is dirty or a transaction is pending.
- Verified headless: save, empty name refused, save while dirty refused, load restores layout as pending, confirm,
  missing profile refused, delete.
- Insert-between drops work on both axes (`insertBeside` in DisplayLayoutMath.js).

## Physical test (2026-11-05, real laptop eDP-1 "AU Optronics B156HAN15.H" + HDMI-A-1 Dell Inspiron 3043)

Backend run from the repo against the real Hyprland, isolated state, SERPANTINUM_DISPLAY_NO_PERSIST=1, TTY3 open
with `~/rescate-pantalla.sh` (rescue, then `hyprctl reload`). All passed:
1. move HDMI y=200, no confirm -> independent reverter restored it at 15 s (systemd-run on the real session).
2. move + confirm -> stayed; restored manually.
3. HDMI 1280x720 no confirm -> back to 1920x1080 at 15 s.
4. HDMI disabled no confirm -> re-enabled at 15 s, windows/workspaces returned to it.
5. `desc:` FIRST REAL MATCH: `render_lua` output passes `--verify-config`; `hyprctl eval` of the
   `desc:Dell Inc. Inspiron 3043 0x00000001` rule moved the HDMI; restore by `desc:` too.
6. UI window (`_try_real.qml`, temporary) on the real monitors: map drag/apply, card controls, profiles,
   keep/revert all worked (user report). Colours come from ThemeBackend (isolated run shows the default palette).
Follow-up: action row (profiles + discard/apply + refresh) moved under the map, buttons spread evenly over its width.

## Upstream sync (2026-11-06, base 2.4.2 / 08ab420)

- Rebased onto upstream 2.4.2 (22 new commits). Only conflict: upstream renamed the `BlueLight` singleton to `Gamma`
  and the i18n keys `guide.display.bluelight.*` to `guide.display.gamma.*`; the two-column card now uses both new names.
- Page load re-verified with the isolated harness (no QML errors, backend available, monitors detected).
- Local install updated by copying only `guide/display/` and `assets/languages/` (backup in
  `~/.local/share/serpantinum-backup-display-<date>`); the user's own `Sounds.qml` is untouched.
- After every upstream release the official updater overwrites `DisplayMainState.qml`, `DisplayMonitorCard.qml` and the
  language files with upstream's copies until this branch is merged: re-copy them from this branch.

## Multi-distro (NixOS, Fedora, Void; 2026-11-06)

The module lives in `src/`, which the AUR package, the installer and `nix/package.nix` copy whole, so it ships everywhere
without packaging changes (python3 and util-linux are already runtime deps; `wrapProgram` puts them in PATH on Nix).
Hyprland 0.57 only reads Lua: a `.conf` is parsed as Lua and fails, so no hyprlang output is needed.

- `serpantinum display <rescue|status|revert|confirm>` (bin/serpantinum): the stable rescue entry point. The script path
  changes with every `/nix/store` hash, so the CLI is what to type from a TTY.
- TTY rescue picks a live, NON-nested Hyprland (`find_hyprland_instances`: lock PID alive, no `WAYLAND_DISPLAY` in its
  environment, newest wins). The old "most recent instance" could repair a test window instead of the real screens.
- `runtime_dir()`: no `XDG_RUNTIME_DIR` and no writable `/run/user/<uid>` (Void without elogind) -> private
  `$TMP/serpantinum-display-<uid>` (0700, owned by the user, symlinks and foreign owners refused).
- `persist_info()` also returns `managed` (config dir or hyprland.lua links into `/nix/store`) and `writable`; the page shows
  `persist_managed_message` (add the line from the Nix configuration). Arch behaviour is unchanged.
- `verify_lua()` looks for `Hyprland` next to `hyprctl` when it is not in PATH (systemd user service); if still missing it logs
  "verify skipped" and persists anyway.
- `tests/display/containers.sh [fedora|void|nixos]`: the suite in read-only podman containers (81 tests each) + Void smoke
  (private runtime dir, `setsid` reverter) + NixOS check (a real store symlink is detected as managed; a copy of `src/`
  shaped like installPhase keeps `display_txn.py` executable).
- NOT verifiable without those systems: a full `nix build`/Home Manager switch, a real Hyprland on Fedora/Void/NixOS (no
  physical monitors in containers), the `hyprctl keyword` fallback on a Hyprland without `eval`.

## Open
- Translations for the other 21 languages (they fall back to English).
